import SwiftUI

struct CompletionToast: Identifiable, Equatable {
    let id = UUID()
    let taskID: UUID
    let completionID: UUID
    let title: String
}

/// Home screen: today's care for the selected pet.
/// The routine sits in a two-column grid sorted by time.
struct ActivityView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showEmergency = false
    @State private var showNotifications = false
    /// The task being dragged to a new spot, so its card can dim in place.
    @State private var draggingTask: UUID?
    @State private var showPostUpdate = false
    @State private var showAddPet = false
    @State private var detailTask: CareTask?
    @State private var newTask: CareTask?
    @State private var toast: CompletionToast?
    @State private var detailsFor: CompletionToast?
    /// Task cards currently on screen, so the Next task pill knows when the next one is out of view.
    @State private var visibleTasks: Set<UUID> = []

    var body: some View {
        let pet = store.pet

        NavigationStack {
          ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    WeekStrip()
                        .padding(.horizontal, -16)
                    // The day's content slides sideways when you change dates; the strip itself snaps.
                    ZStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 16) {
                            DaySummaryCard()

                            if pet.tasks.isEmpty {
                                emptyState
                            } else {
                                taskGrid(pet.tasks)
                            }

                            if store.isOwner {
                                addTaskButton
                            }
                        }
                        .id(store.selectedDate)
                        .transition(reduceMotion ? .opacity : .push(from: store.dateSlideEdge))
                    }
                    .animation(.snappy(duration: 0.32), value: store.selectedDate)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemBackground))
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottom) {
                VStack(spacing: 10) {
                    backToTodayButton
                    nextTaskButton(proxy: proxy)
                    toastOverlay
                }
                .padding(.bottom, 10)
                .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0),
                           value: Calendar.current.isDateInToday(store.selectedDate))
                .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0),
                           value: showsNextTaskPill)
            }
          }
            // The toast carries an action, so it stays until dismissed or the day changes.
            .onChange(of: store.selectedDate) { toast = nil }
            .sensoryFeedback(.success, trigger: toast)
            .sheet(isPresented: $showEmergency) { EmergencySheet().solidSheet() }
            .sheet(isPresented: $showNotifications) { NotificationsSheet().solidSheet() }
            .sheet(isPresented: $showPostUpdate) { PostUpdateSheet().solidSheet() }
            .sheet(isPresented: $showAddPet) {
                NavigationStack { CreatePetFlow(isSheet: true) }
                .solidSheet()
            }
            .sheet(item: $detailTask) { task in TaskDetailSheet(taskID: task.id).solidSheet() }
            .sheet(item: $newTask) { task in TaskEditorSheet(task: task, isNew: true).solidSheet() }
            .sheet(item: $detailsFor) { info in
                CompletionDetailsSheet(taskID: info.taskID, completionID: info.completionID)
                .solidSheet()
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Menu {
                Section("Switch pet") {
                    ForEach(store.pets) { p in
                        Button {
                            withAnimation { store.selectedPetID = p.id }
                        } label: {
                            Label(p.name, systemImage: p.id == store.selectedPetID ? "checkmark" : p.species.symbol)
                        }
                    }
                }
                if store.isOwner {
                    Button("Add a pet", systemImage: "plus") { showAddPet = true }
                }
            } label: {
                HStack(spacing: 12) {
                    PetAvatar(pet: store.pet, size: TimelineMetrics.railWidth)
                    Text(store.pet.name)
                        .font(.allo(28, .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            HStack(spacing: 0) {
                if !store.isOwner {
                    headerButton("camera", label: "Post update") { showPostUpdate = true }
                }
                headerButton("exclamationmark.triangle", label: "Emergency info") { showEmergency = true }
                headerButton("bell", label: "Notifications") { showNotifications = true }
                    .overlay(alignment: .topTrailing) {
                        if store.hasUnreadNotifications {
                            Circle()
                                .fill(Color.boubaOrange)
                                .frame(width: 9, height: 9)
                                .offset(x: -12, y: 12)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .padding(.horizontal, 4)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .padding(.top, 8)
    }

    private func headerButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 46, height: 46)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Tasks

    /// Tasks two to a row, in the owner's order. Owners long-press a card and drag it to reorder.
    private func taskGrid(_ tasks: [CareTask]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(tasks) { task in
                trackedCard(task, in: tasks)
            }
        }
        // A drop that lands between cards still ends the drag.
        .onDrop(of: [.text], isTargeted: nil) { _ in
            draggingTask = nil
            return true
        }
    }

    /// Tracks which cards are on screen for the Next task pill.
    private func trackedCard(_ task: CareTask, in tasks: [CareTask]) -> some View {
        Group {
            if store.isOwner {
                reorderableCard(task, in: tasks)
            } else {
                taskCard(task)
            }
        }
        .id(task.id)
        .onScrollVisibilityChange(threshold: 0.5) { visible in
            if visible { visibleTasks.insert(task.id) } else { visibleTasks.remove(task.id) }
        }
    }

    private func reorderableCard(_ task: CareTask, in tasks: [CareTask]) -> some View {
        let index = tasks.firstIndex { $0.id == task.id } ?? 0
        return taskCard(task)
            .opacity(draggingTask == task.id ? 0.4 : 1)
            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 24, style: .continuous))
            .onDrag {
                draggingTask = task.id
                return NSItemProvider(object: task.id.uuidString as NSString)
            }
            .onDrop(of: [.text], delegate: TaskDropDelegate(target: task.id, dragging: $draggingTask) { from, to in
                withAnimation(.snappy) { store.moveTasks(from: IndexSet(integer: from), to: to > from ? to + 1 : to) }
            } indexOf: { id in store.pet.tasks.firstIndex { $0.id == id } })
            // VoiceOver can't drag, so the same moves are offered as actions.
            .accessibilityAction(named: "Move earlier") {
                guard index > 0 else { return }
                withAnimation(.snappy) { store.moveTasks(from: IndexSet(integer: index), to: index - 1) }
            }
            .accessibilityAction(named: "Move later") {
                guard index < tasks.count - 1 else { return }
                withAnimation(.snappy) { store.moveTasks(from: IndexSet(integer: index), to: index + 2) }
            }
    }

    private func taskCard(_ task: CareTask) -> some View {
        TaskCard(
            task: task,
            date: store.selectedDate,
            onComplete: { complete(task) },
            onUndo: { withAnimation(.snappy) { store.undoCompletion(taskID: task.id, on: store.selectedDate) } },
            onOpen: { detailTask = task }
        )
    }

    private func complete(_ task: CareTask) {
        withAnimation(.snappy) {
            if let completionID = store.complete(task.id) {
                toast = CompletionToast(taskID: task.id, completionID: completionID, title: task.title)
            }
        }
    }

    private var addTaskButton: some View {
        Button { newTask = blankTask() } label: {
            Label("Add a task", systemImage: "plus")
                .font(.allo(16, .semibold))
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color(.systemGray4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                )
        }
        .buttonStyle(PressableStyle())
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No tasks yet", systemImage: "checklist")
        } description: {
            Text("Add feeding, walks, meds and anything else \(store.pet.name) needs.")
                .font(.alloSubtext(18))
        }
        .padding(.vertical, 30)
    }

    private func blankTask() -> CareTask {
        CareTask(kind: .food, title: TaskKind.food.defaultTitle, hour: 9, minute: 0)
    }

    // MARK: Next task

    /// Today's earliest task that isn't done yet.
    private var nextTask: CareTask? {
        guard Calendar.current.isDateInToday(store.selectedDate) else { return nil }
        return store.pet.tasks
            .filter { $0.completion(on: store.selectedDate) == nil }
            .min { $0.minutesOfDay < $1.minutesOfDay }
    }

    private var showsNextTaskPill: Bool {
        guard let next = nextTask else { return false }
        return !visibleTasks.contains(next.id)
    }

    /// Appears when today's next task is off screen and scrolls to it.
    @ViewBuilder private func nextTaskButton(proxy: ScrollViewProxy) -> some View {
        if showsNextTaskPill, let next = nextTask {
            let tasks = store.pet.tasks
            let index = tasks.firstIndex { $0.id == next.id } ?? 0
            let lastVisible = tasks.indices.filter { visibleTasks.contains(tasks[$0].id) }.max() ?? -1
            Button {
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.45)) {
                    proxy.scrollTo(next.id, anchor: .center)
                }
            } label: {
                Label("Next task", systemImage: index > lastVisible ? "arrow.down" : "arrow.up")
                    .font(.allo(15, .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
            .accessibilityLabel("Next task: \(next.title)")
            .transition(reduceMotion ? .opacity : .scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
        }
    }

    // MARK: Back to today

    /// Appears once you leave today and takes you straight back.
    @ViewBuilder private var backToTodayButton: some View {
        if !Calendar.current.isDateInToday(store.selectedDate) {
            Button {
                store.selectDate(Date().startOfDay)
            } label: {
                Label("Back to today", systemImage: "arrow.uturn.backward")
                    .font(.allo(15, .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
            .transition(reduceMotion ? .opacity : .scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
        }
    }

    // MARK: Toast

    @ViewBuilder private var toastOverlay: some View {
        if let toast {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.boubaGreen)
                Text("Done!")
                    .font(.allo(16, .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button {
                    detailsFor = toast
                    withAnimation(.snappy) { self.toast = nil }
                } label: {
                    Label("Add photo or note", systemImage: "camera.fill")
                        .font(.allo(14, .semibold))
                }
                .buttonStyle(.glassProminent)
                Button {
                    withAnimation(.snappy) { self.toast = nil }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Dismiss")
            }
            .padding(.leading, 16)
            .padding(.trailing, 2)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
            .padding(.horizontal, 16)
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Task card

/// One task: icon, title, a single status line, and a full-width action.
struct TaskCard: View {
    let task: CareTask
    let date: Date
    var onComplete: () -> Void
    var onUndo: () -> Void
    var onOpen: () -> Void

    @State private var confirmUndo = false

    private var completion: Completion? { task.completion(on: date) }
    private var isFuture: Bool { date.startOfDay > Date().startOfDay }
    private var isLate: Bool { !isFuture && task.isLate(on: date) }

    var body: some View {
        // Spacing 0 with a flexible spacer on each side of the title, so the gap above the
        // text always equals the gap below it, however tall the card stretches.
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                IconTile(kind: task.kind, size: 40)
                Spacer(minLength: 4)
                Button(action: onOpen) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(.systemGray4))
                        .frame(width: 44, height: 44, alignment: .topTrailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(task.title) details")
            }

            Spacer(minLength: 12)

            VStack(alignment: .leading, spacing: 0) {
                Text(task.title)
                    .font(.allo(16, .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(statusText)
                    .font(.alloSubtext(15))
                    .foregroundStyle(isLate && completion == nil ? Color.dangerText : Color.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if hasAction { Spacer(minLength: 12) }
            actionButton
        }
        .outlinedCard(padding: 12, radius: 24)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture(perform: onOpen)
        .confirmationDialog("Mark \(task.title) as not done?", isPresented: $confirmUndo, titleVisibility: .visible) {
            Button("Mark as not done", role: .destructive, action: onUndo)
        }
    }

    private var hasAction: Bool { completion != nil || !isFuture }

    private var statusText: String {
        if let c = completion { return "Done at \(c.date.timeString)" }
        if isLate { return "Late · \(task.timeString)" }
        return task.timeString
    }

    @ViewBuilder private var actionButton: some View {
        if completion != nil {
            Button { confirmUndo = true } label: {
                Label("Completed", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(CardButtonStyle(isDone: true))
            .accessibilityLabel("Completed. Tap to undo")
        } else if !isFuture {
            Button("Complete", action: onComplete)
                .buttonStyle(CardButtonStyle())
                .accessibilityLabel("Complete \(task.title)")
        }
    }
}

// MARK: - Card styles

extension View {
    func outlinedCard(padding: CGFloat = 16, radius: CGFloat = 28) -> some View {
        // Same white, bordered card as everywhere else, with a rounder corner for the Activity grid.
        card(padding: padding, radius: radius)
    }
}

/// Full-width capsule button inside a card: gray to act, pale green once done.
struct CardButtonStyle: ButtonStyle {
    var isDone = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.allo(16, .semibold))
            .labelStyle(CardButtonLabelStyle(isDone: isDone))
            .foregroundStyle(isDone ? Color.boubaGreenText : Color.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 8)
            .background(isDone ? Color.boubaGreen.opacity(0.12) : Color.fieldFill, in: Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct CardButtonLabelStyle: LabelStyle {
    var isDone: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon.foregroundStyle(isDone ? Color.boubaGreen : Color.primary)
            configuration.title
        }
    }
}

/// One width shared by the header avatar and the selected day, so the left edge reads as a single column.
enum TimelineMetrics {
    static let railWidth: CGFloat = 56
}

// MARK: - Week strip

struct WeekStrip: View {
    @Environment(AppStore.self) private var store
    @State private var scrolledDay: Date?

    private let days: [Date] = (-7...13).map { Date().startOfDay.adding(days: $0) }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(days, id: \.self) { day in
                    DayCell(day: day,
                            isSelected: Calendar.current.isDate(day, inSameDayAs: store.selectedDate))
                        .onTapGesture {
                            store.selectDate(day)
                        }
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .scrollPosition(id: $scrolledDay, anchor: .leading)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .onAppear {
            if scrolledDay == nil { scrolledDay = Date().startOfDay }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: store.selectedDate)
        // "Back to today" brings today back into view too.
        .onChange(of: store.selectedDate) { _, day in
            if Calendar.current.isDateInToday(day) {
                withAnimation(.snappy) { scrolledDay = day }
            }
        }
    }

}

private struct DayCell: View {
    let day: Date
    let isSelected: Bool

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    var body: some View {
        // Allo's line height leaves a big gap between lines, so pull the date up.
        VStack(spacing: -2) {
            Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                .font(.allo(15, .semibold))
                .foregroundStyle(isToday ? Color.dangerText : (isSelected ? Color.primary : Color.secondary))
            Text(day.formatted(.dateTime.day()))
                .font(.allo(30, .semibold))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
        }
        .frame(width: TimelineMetrics.railWidth, height: 76)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemBackground))
                    .layeredShadow(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Day summary

/// Top of the Activity screen: two small cards side by side (who's caring, what's next),
/// then a wide progress card for the day.
struct DaySummaryCard: View {
    @Environment(AppStore.self) private var store

    private let radius: CGFloat = 28

    var body: some View {
        let pet = store.pet
        let date = store.selectedDate
        let total = pet.tasks.count
        let done = pet.tasks.filter { $0.completion(on: date) != nil }.count
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        // Who's caring sits in a gray banner, with the day's progress docked beneath it.
        VStack(spacing: 0) {
            caringBanner(pet: pet, date: date)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date.relativeDay.uppercased())
                        .font(.allo(15, .semibold))
                        .tracking(0.6)
                        .foregroundStyle(Color.textSecondary)
                    Text(total == 0 ? "Nothing scheduled" : "\(done) of \(total) done")
                        .font(.allo(26, .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 0)
                PieProgress(progress: total == 0 ? 0 : Double(done) / Double(total),
                            color: done == total && total > 0 ? Color.boubaGreen : Color.boubaOrange)
                    .frame(width: 48, height: 48)
            }
            .card(padding: 18, radius: radius)
        }
        .background(Color.fieldFill, in: shape)
        .sensoryFeedback(.impact, trigger: store.isCheckedIn)
    }

    // MARK: Caring banner

    private func banner<Leading: View, Trailing: View>(
        _ text: Text,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) -> some View {
        HStack(spacing: 10) {
            leading()
            text
                .font(.allo(15, .semibold))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 44)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func caringBanner(pet: Pet, date: Date) -> some View {
        if !store.isOwner {
            // Caretakers check in and out from here.
            banner(Text(store.checkedInAt.map { "With \(pet.name) since \($0.timeString)" }
                        ?? "Visiting \(pet.name)? Let \(store.ownerName) know")) {
                InitialsAvatar(name: store.ownerName, color: .boubaOrange, size: 24)
            } trailing: {
                Button(store.isCheckedIn ? "Check out" : "Check in") {
                    withAnimation { store.toggleCheckIn() }
                }
                .font(.allo(15, .semibold))
                .foregroundStyle(Color.boubaOrangeText)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
        } else if let sitter = pet.caretakers.first(where: { $0.role == .temporary && $0.isActive(on: date) }) {
            let detail = store.checkedInAt.map { "checked in at \($0.timeString)" }
                ?? "through \(sitter.end.formatted(.dateTime.month(.abbreviated).day()))"
            banner(Text("\(sitter.name) is caring \(detail)")) {
                InitialsAvatar(name: sitter.name, color: sitter.color, size: 24)
                    .overlay(alignment: .bottomTrailing) {
                        if store.isCheckedIn {
                            Circle().fill(Color.boubaGreen)
                                .frame(width: 9, height: 9)
                                .overlay(Circle().strokeBorder(Color.fieldFill, lineWidth: 1.5))
                                .offset(x: 2, y: 2)
                        }
                    }
            }
        } else {
            let team = pet.caretakers.filter { $0.role == .coOwner }.map(\.name)
            banner(Text(team.isEmpty ? "Just you on care" : "You & \(team.joined(separator: ", ")) on care")) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 24, height: 24)
            }
        }
    }
}

/// A pie that fills clockwise from 12 o'clock inside a faint ring.
struct PieProgress: View {
    var progress: Double
    var color: Color

    var body: some View {
        ZStack {
            Circle().strokeBorder(color.opacity(0.2), lineWidth: 4)
            // A same-color stroke with round joins softens the wedge's corners.
            PieSlice(progress: progress)
                .fill(color)
                .overlay(PieSlice(progress: progress).stroke(color, style: StrokeStyle(lineWidth: 4, lineJoin: .round)))
                .padding(11)
        }
        .animation(.snappy, value: progress)
    }
}

private struct PieSlice: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let p = min(max(progress, 0), 1)
        guard p > 0 else { return Path() }
        if p >= 1 { return Path(ellipseIn: rect) }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: min(rect.width, rect.height) / 2,
                    startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * p), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// Moves the dragged task into the spot of whichever card it passes over.
private struct TaskDropDelegate: DropDelegate {
    let target: UUID
    @Binding var dragging: UUID?
    let move: (_ from: Int, _ to: Int) -> Void
    let indexOf: (UUID) -> Int?

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target,
              let from = indexOf(dragging), let to = indexOf(target) else { return }
        move(from, to)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}
