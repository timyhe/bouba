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
    @State private var showPostUpdate = false
    @State private var showAddPet = false
    @State private var detailTask: CareTask?
    @State private var newTask: CareTask?
    @State private var toast: CompletionToast?
    /// True while the new-pet toast is on screen.
    @State private var showWelcome = false
    @State private var detailsFor: CompletionToast?
    /// Task cards currently on screen, so the Next task pill knows when the next one is out of view.
    @State private var visibleTasks: Set<UUID> = []
    /// How far the day has been dragged sideways; the content follows the finger.
    @State private var dayDrag: CGFloat = 0
    /// True once a drag passes the point where letting go changes the date.
    @State private var swipeArmed = false
    /// True while a day swipe is under the finger, so the card it started on doesn't also take a tap.
    @State private var swiping = false
    @State private var todayTaps = 0

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
                            if pet.tasks.isEmpty {
                                emptyState
                            } else {
                                taskGrid(pet.tasks)
                            }

                            if store.isOwner && pet.tasks.isEmpty {
                                addTaskButton
                            }
                        }
                        .id(store.selectedDate)
                        .transition(reduceMotion ? .opacity : .push(from: store.dateSlideEdge))
                    }
                    .offset(x: dayDrag)
                    .animation(.snappy(duration: 0.32), value: store.selectedDate)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .environment(\.isSwipingDays, swiping)
            // Swipe left or right anywhere on the page, cards and blank space alike, to move to the next or previous date.
            // The day follows the finger; past the threshold it ticks once, and letting go
            // there (or flicking) changes the date, otherwise it springs back.
            // A UIKit pan that only starts on a horizontal swipe, so vertical swipes still
            // scroll the page (a SwiftUI DragGesture here swallowed them).
            .gesture(HorizontalSwipe(
                onChanged: { dx in
                    if !swiping { swiping = true }
                    if neighborDay(for: dx) == nil {
                        // No day that way: resist, and never arm.
                        dayDrag = dx * 0.25
                        swipeArmed = false
                    } else {
                        dayDrag = dx
                        swipeArmed = abs(dx) > Self.swipeThreshold
                    }
                },
                onEnded: { dx, speed in
                    let flick = abs(dx) > 20 && abs(speed) > 600 && (dx < 0) == (speed < 0)
                    let next = neighborDay(for: dx).flatMap { abs(dx) > Self.swipeThreshold || flick ? $0 : nil }
                    withAnimation(.spring(duration: 0.35, bounce: 0)) { dayDrag = 0 }
                    swipeArmed = false
                    // Change the date just after the gesture callback, not inside it. A change made
                    // mid-callback could reach the day's content but not the week strip until the
                    // next change, so one swipe looked lost and the next jumped two days.
                    // Taps that land as the finger lifts still see `swiping` and are ignored.
                    DispatchQueue.main.async {
                        if let next { store.selectDate(next) }
                        swiping = false
                    }
                }))
            .boubaFeedback(trigger: swipeArmed) { _, armed in armed ? .boubaSelect : nil }
            .background(Color(.systemBackground))
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottom) {
                VStack(spacing: 10) {
                    backToTodayButton
                    nextTaskButton(proxy: proxy)
                    toastOverlay
                    welcomeToast
                }
                .padding(.bottom, 10)
                .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0),
                           value: Calendar.current.isDateInToday(store.selectedDate))
                .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0),
                           value: showsNextTaskPill)
                .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0),
                           value: welcomePet?.id)
            }
          }
            // The toast carries an action, so it stays until dismissed or the day changes.
            .onChange(of: store.selectedDate) { toast = nil }
            // Completing a task is the app's main action. Only on completion, not when the toast goes away.
            .boubaFeedback(trigger: toast) { _, new in new == nil ? nil : .boubaPrimary }
            // A new pet is a big moment: celebrate it once, then let it go on its own.
            .boubaFeedback(trigger: welcomePet?.id) { _, new in new == nil ? nil : .boubaPrimary }
            // The store holds the new pet until the toast has had its moment, so a remount
            // during the onboarding transition just restarts the timer instead of losing it.
            .task(id: store.newlyAddedPetID) {
                guard store.newlyAddedPetID != nil else { showWelcome = false; return }
                // Let the sheet or the onboarding modal finish sliding away first.
                try? await Task.sleep(for: .seconds(0.6))
                guard !Task.isCancelled else { return }
                showWelcome = true
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                store.newlyAddedPetID = nil
            }
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
                    PetAvatar(pet: store.pet, size: 46)  // matches the 46pt header buttons
                    Text(store.pet.name)
                        .boubaFont(.title)
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
                headerButton("bell", label: "Notifications", badge: store.hasUnreadNotifications) { showNotifications = true }
            }
            .padding(.horizontal, 4)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .padding(.top, 8)
    }

    private func headerButton(_ symbol: String, label: String, badge: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 46, height: 46)
                // The unread dot sits in a gap cut out of the icon, so whatever is behind it
                // (the glass) shows through, instead of a painted ring that never quite matches.
                .mask {
                    Rectangle()
                        .overlay(alignment: .topTrailing) {
                            if badge {
                                Circle()
                                    .frame(width: 13, height: 13)
                                    .offset(x: -10, y: 10)
                                    .blendMode(.destinationOut)
                            }
                        }
                        .compositingGroup()
                }
                .overlay(alignment: .topTrailing) {
                    if badge {
                        Circle()
                            .fill(Color.boubaOrange)
                            .frame(width: 9, height: 9)
                            .offset(x: -12, y: 12)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Tasks

    /// Tasks two to a row, in the owner's order.
    private func taskGrid(_ tasks: [CareTask]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(tasks) { task in
                trackedCard(task)
            }
            if store.isOwner {
                addTaskButton
            }
        }
    }

    /// Tracks which cards are on screen for the Next task pill.
    private func trackedCard(_ task: CareTask) -> some View {
        taskCard(task)
            .id(task.id)
            .onScrollVisibilityChange(threshold: 0.5) { visible in
                if visible { visibleTasks.insert(task.id) } else { visibleTasks.remove(task.id) }
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

    /// Sits in the grid as one more card: same corner, and sized by an invisible copy of a
    /// task card's layout so it always matches its neighbours, with or without an action button.
    private var addTaskButton: some View {
        Button { newTask = blankTask() } label: {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: 44)
                Spacer(minLength: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(" ").font(.bouba(.callout, .semibold))
                    Text(" ").font(.boubaSecondary(.subhead))
                }
                if store.selectedDate.startOfDay <= Date().startOfDay {
                    Spacer(minLength: 12)
                    Color.clear.frame(height: 44)
                }
            }
            .hidden()
            .frame(maxWidth: .infinity)
            .padding(12)
            .overlay {
                Label("Add a task", systemImage: "plus")
                    .font(.bouba(.callout, .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color(.systemGray4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No tasks yet", systemImage: "checklist")
        } description: {
            Text("Add feeding, walks, meds and anything else \(store.pet.name) needs.")
                .font(.boubaSecondary(.body))
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
                    .font(.bouba(.subhead, .semibold))
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

    static let swipeThreshold: CGFloat = 80

    /// The day a horizontal drag of `dx` leads to, or nil past the ends of the week strip.
    private func neighborDay(for dx: CGFloat) -> Date? {
        guard dx != 0 else { return nil }
        let next = store.selectedDate.startOfDay.adding(days: dx < 0 ? 1 : -1)
        guard let first = WeekStrip.days.first, let last = WeekStrip.days.last,
              next >= first, next <= last else { return nil }
        return next
    }

    // MARK: Back to today

    /// Appears once you leave today and takes you straight back.
    @ViewBuilder private var backToTodayButton: some View {
        if !Calendar.current.isDateInToday(store.selectedDate) {
            Button {
                todayTaps += 1
                store.selectDate(Date().startOfDay)
            } label: {
                Label("Back to today", systemImage: "arrow.uturn.backward")
                    .font(.bouba(.subhead, .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
            .boubaFeedback(.boubaSelect, trigger: todayTaps)
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
                    .font(.bouba(.callout, .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button {
                    detailsFor = toast
                    withAnimation(.snappy) { self.toast = nil }
                } label: {
                    Label("Add photo or note", systemImage: "camera.fill")
                        .font(.bouba(.footnote, .semibold))
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

extension ActivityView {
    // MARK: Welcome toast

    /// The pet just created, once its toast is due.
    private var welcomePet: Pet? {
        guard showWelcome, let id = store.newlyAddedPetID else { return nil }
        return store.pets.first { $0.id == id }
    }

    @ViewBuilder var welcomeToast: some View {
        if let pet = welcomePet {
            HStack(spacing: 12) {
                PetAvatar(pet: pet, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome, \(pet.name)! 🎉")
                        .font(.bouba(.callout, .semibold))
                        .lineLimit(1)
                    Text(welcomeDetail(for: pet))
                        .font(.boubaSecondary(.footnote))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Button {
                    store.newlyAddedPetID = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Dismiss")
            }
            .padding(.leading, 8)
            .padding(.trailing, 2)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
            .background { if !reduceMotion { ConfettiBurst() } }
            .padding(.horizontal, 16)
            .accessibilityElement(children: .combine)
            .transition(reduceMotion ? .opacity : .scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
        }
    }

    private func welcomeDetail(for pet: Pet) -> String {
        switch pet.tasks.count {
        case 0: "Add a task to start the routine"
        case 1: "1 task is ready for today"
        default: "\(pet.tasks.count) tasks are ready for today"
        }
    }
}

/// A one-shot burst of confetti from behind the welcome toast.
private struct ConfettiBurst: View {
    private struct Piece {
        let angle: Double, distance: CGFloat, size: CGFloat, spin: Double, color: Color, isCircle: Bool
    }

    private static let colors: [Color] = [.boubaOrange, .boubaGreen, .yellow, .pink, .blue, .purple]
    private let pieces: [Piece] = (0..<28).map { i in
        Piece(angle: Double.random(in: -170 ... -10),
              distance: .random(in: 70...170),
              size: .random(in: 5...9),
              spin: .random(in: -360...360),
              color: colors[i % colors.count],
              isCircle: i.isMultiple(of: 3))
    }
    @State private var burst = false

    var body: some View {
        ZStack {
            ForEach(pieces.indices, id: \.self) { i in
                let p = pieces[i]
                let r = p.angle * .pi / 180
                Group {
                    if p.isCircle { Circle().fill(p.color) }
                    else { RoundedRectangle(cornerRadius: 1.5).fill(p.color).frame(width: p.size * 0.6) }
                }
                .frame(width: p.size, height: p.size)
                .rotationEffect(.degrees(burst ? p.spin : 0))
                .offset(x: burst ? cos(r) * p.distance * 1.4 : 0,
                        y: burst ? sin(r) * p.distance + 40 : 0)
                .opacity(burst ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 1.4)) { burst = true }
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
    @Environment(\.isSwipingDays) private var isSwiping

    private var completion: Completion? { task.completion(on: date) }

    /// Runs a tap unless it's the end of a day swipe that started on this card.
    private func tap(_ action: @escaping () -> Void) -> () -> Void {
        { if !isSwiping { action() } }
    }
    private var isFuture: Bool { date.startOfDay > Date().startOfDay }
    private var isLate: Bool { !isFuture && task.isLate(on: date) }

    var body: some View {
        // The whole card opens the task; the info and action buttons inside take their own taps.
        Button(action: tap(onOpen)) { content }
            .buttonStyle(CardPressStyle())
            .confirmationDialog("Mark \(task.title) as not done?", isPresented: $confirmUndo, titleVisibility: .visible) {
                Button("Mark as not done", role: .destructive, action: onUndo)
            }
    }

    private var content: some View {
        // Spacing 0 with a flexible spacer on each side of the title, so the gap above the
        // text always equals the gap below it, however tall the card stretches.
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                IconTile(kind: task.kind, size: 40)
                Spacer(minLength: 4)
                Button(action: tap(onOpen)) {
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
                    .font(.bouba(.callout, .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(statusText)
                    .font(.boubaSecondary(.subhead))
                    .foregroundStyle(isLate && completion == nil ? Color.dangerText : Color.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if hasAction { Spacer(minLength: 12) }
            actionButton
        }
        .outlinedCard(padding: 12, radius: 24)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var hasAction: Bool { completion != nil || !isFuture }

    private var statusText: String {
        if let c = completion { return "Done at \(c.date.timeString)" }
        if isLate { return "Late · \(task.timeString)" }
        return task.timeString
    }

    @ViewBuilder private var actionButton: some View {
        if completion != nil {
            Button(action: tap { confirmUndo = true }) {
                Label("Completed", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(CardButtonStyle(isDone: true))
            .accessibilityLabel("Completed. Tap to undo")
        } else if !isFuture {
            Button("Complete", action: tap(onComplete))
                .buttonStyle(CardButtonStyle())
                .accessibilityLabel("Complete \(task.title)")
        }
    }
}

// MARK: - Card styles

extension View {
    func outlinedCard(padding: CGFloat = 16, radius: CGFloat = 28) -> some View {
        // Task cards keep the lifted look: white with a soft shadow, unlike the flat outlined
        // cards elsewhere.
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: shape)
            .layeredShadow(shape)
    }
}

/// Full-width capsule button inside a card: gray to act, pale green once done.
struct CardButtonStyle: ButtonStyle {
    var isDone = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bouba(.callout, .semibold))
            .labelStyle(CardButtonLabelStyle(isDone: isDone))
            .foregroundStyle(isDone ? Color.onGreenTint : Color.primary)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrolledDay: Date?
    /// Days currently on screen, so a swipe to an off-screen day scrolls it into view.
    @State private var visibleDays: Set<Date> = []
    @State private var taps = 0

    static let days: [Date] = (-7...13).map { Date().startOfDay.adding(days: $0) }
    private var days: [Date] { Self.days }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { day in
                    DayCell(day: day,
                            isSelected: Calendar.current.isDate(day, inSameDayAs: store.selectedDate),
                            carers: carers(on: day))
                        .onTapGesture {
                            if !Calendar.current.isDate(day, inSameDayAs: store.selectedDate) { taps += 1 }
                            store.selectDate(day)
                        }
                        .onScrollVisibilityChange(threshold: 0.9) { visible in
                            if visible { visibleDays.insert(day) } else { visibleDays.remove(day) }
                        }
                }
            }
            // One tile that slides behind the row to the selected date. Only the tile animates: it is
            // always on screen and only its position changes, so a second swipe mid-slide just
            // retargets it. The days' own styling switches instantly (animating it could strand a
            // half-updated day on device when changes overlapped).
            .background(alignment: .topLeading) {
                selectionTile
                    .animation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0), value: store.selectedDate)
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
        // Taps tick here; Back to today and the day swipe play their own.
        .boubaFeedback(.boubaSelect, trigger: taps)
        // "Back to today" brings today back into view too.
        .onChange(of: store.selectedDate) { _, day in
            if Calendar.current.isDateInToday(day) {
                withAnimation(.snappy) { scrolledDay = day }
            } else if !visibleDays.contains(day.startOfDay) {
                // A swipe moved past the edge of the strip; bring the day into view.
                withAnimation(.snappy) { scrolledDay = Calendar.current.date(byAdding: .day, value: -3, to: day.startOfDay) }
            }
        }
    }


    private var selectionTile: some View {
        let index = days.firstIndex { Calendar.current.isDate($0, inSameDayAs: store.selectedDate) }
        let count = carers(on: store.selectedDate).count
        let shape = DayTileShape(bumpWidth: count > 0 ? DayCell.pileWidth(count: count) + 4 : 0,
                                 bumpHeight: DayCell.pileHeight + 4)
        return shape
            .fill(Color(.systemBackground))
            .layeredShadow(shape)
            .frame(width: DayCell.width, height: DayCell.tileHeight)
            .offset(x: CGFloat(index ?? 0) * (DayCell.width + 8), y: DayCell.pileHeight / 2)
            .opacity(index == nil ? 0 : 1)
    }
}

/// Someone shown under a date in the week strip.
struct DayCarer: Hashable {
    let name: String
    let color: Color
    let photo: String?
}

extension WeekStrip {
    /// The sitter on duty that day; otherwise the owner and co-owners.
    func carers(on day: Date) -> [DayCarer] {
        let caretakers = store.pet.caretakers
        if let sitter = caretakers.first(where: { $0.role == .temporary && $0.isActive(on: day) }) {
            return [DayCarer(name: sitter.name, color: sitter.color, photo: sitter.photo)]
        }
        let owner = DayCarer(name: store.ownerName, color: .boubaOrange, photo: store.ownerPhoto)
        let coOwners = caretakers
            .filter { $0.role == .coOwner && $0.isActive(on: day) }
            .map { DayCarer(name: $0.name, color: $0.color, photo: $0.photo) }
        return Array(([owner] + coOwners).prefix(3))
    }
}

private struct DayCell: View {
    let day: Date
    let isSelected: Bool
    /// Who's caring that day, shown as small avatars under the date.
    var carers: [DayCarer]

    private let avatarSize: CGFloat = 16
    static let width: CGFloat = TimelineMetrics.railWidth + 6
    static let tileHeight: CGFloat = 76

    /// Only the selected day shows who's caring.
    private var showsPile: Bool { !carers.isEmpty && isSelected }
    /// Width of the overlapping facepile, ring included.
    static func pileWidth(count: Int) -> CGFloat {
        let n = CGFloat(count)
        return n * pileHeight - max(n - 1, 0) * pileOverlap
    }

    /// The facepile's height including its ring; half of it sits above the tile's top edge.
    static let pileHeight: CGFloat = 16 + 3
    private static let pileOverlap: CGFloat = 4
    private var pileHeight: CGFloat { Self.pileHeight }
    private var pileOverlap: CGFloat { Self.pileOverlap }

    var body: some View {
        // Allo's line height leaves a big gap between lines, so pull the date up.
        VStack(spacing: -2) {
            Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                .font(.bouba(.subhead, .semibold))
                .foregroundStyle(isSelected ? Color.dangerText : Color.secondary)
            Text(day.formatted(.dateTime.day()))
                .font(.allo(30, .semibold)) // Date numeral: a one-off display size between title and largeTitle.
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
        }
        // Nudge the text down a touch so it clears the avatars sitting on the top edge.
        .offset(y: 2)
        .frame(width: Self.width, height: Self.tileHeight)
        // The facepile sits centered on the tile's top edge (the tile itself is drawn by the strip,
        // with a bump around the avatars so they read as part of it).
        .overlay(alignment: .top) {
            if showsPile {
                facepile.offset(y: -pileHeight / 2)
            }
        }
        .padding(.top, pileHeight / 2)
        .contentShape(Rectangle())
        // Selection styling never animates; the strip's sliding tile carries the motion.
        .transaction(value: isSelected) { $0.animation = nil }
    }

    // Overlapping facepile; each face gets a ring in the tile's color so they read as separate.
    private var facepile: some View {
        HStack(spacing: -pileOverlap) {
            ForEach(carers, id: \.self) { carer in
                InitialsAvatar(name: carer.name, color: carer.color, size: avatarSize, photo: carer.photo)
                    .padding(1.5)
                    .background(Circle().fill(Color(.systemBackground)))
            }
        }
        .frame(height: pileHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(carers.map(\.name).formatted(.list(type: .and)) + " caring")
    }
}

/// A rounded tile with an optional capsule bump centered on its top edge (for the day's avatars).
private struct DayTileShape: InsettableShape {
    var bumpWidth: CGFloat
    var bumpHeight: CGFloat
    var cornerRadius: CGFloat = 18
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let tile = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let path = Path(roundedRect: tile, cornerRadius: max(cornerRadius - insetAmount, 0), style: .continuous)
        guard bumpWidth > 0 else { return path }
        let bump = CGRect(x: rect.midX - bumpWidth / 2, y: rect.minY - bumpHeight / 2,
                          width: bumpWidth, height: bumpHeight)
            .insetBy(dx: insetAmount, dy: insetAmount)
        return path.union(Path(roundedRect: bump, cornerRadius: bump.height / 2))
    }

    func inset(by amount: CGFloat) -> DayTileShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}


extension EnvironmentValues {
    /// True while the Activity page's day swipe is under the finger; cards ignore taps meanwhile.
    @Entry var isSwipingDays = false
}

/// A horizontal swipe that never competes with vertical scrolling: it declines to start unless the
/// finger is moving mostly sideways, and runs alongside the scroll view's own pan.
struct HorizontalSwipe: UIGestureRecognizerRepresentable {
    /// The horizontal distance so far; negative is toward the left.
    var onChanged: (CGFloat) -> Void
    /// The final distance and horizontal speed when the finger lifts (or the pan is cancelled).
    var onEnded: (CGFloat, CGFloat) -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let distance = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .began, .changed:
            onChanged(distance)
        case .ended:
            onEnded(distance, recognizer.velocity(in: recognizer.view).x)
        case .cancelled, .failed:
            onEnded(0, 0)
        default:
            break
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer, let view = pan.view else { return false }
            let velocity = pan.velocity(in: view)
            guard abs(velocity.x) > abs(velocity.y) * 1.5 else { return false }
            // Leave sideways scrollers (the week strip) to scroll themselves.
            var hit = view.hitTest(pan.location(in: view), with: nil)
            while let current = hit, current !== view {
                if let scroll = current as? UIScrollView, scroll.contentSize.width > scroll.bounds.width + 1 {
                    return false
                }
                hit = current.superview
            }
            return true
        }

        // The page's vertical scroll runs alongside the swipe. So do the cards and buttons on the
        // page: they show their press right away (otherwise they'd claim the touch and the swipe
        // would never start), and ignore their tap while a swipe is under way (isSwipingDays).
        func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            if other.view is UIScrollView { return other is UIPanGestureRecognizer }
            return other.view?.isDescendant(of: recognizer.view ?? UIView()) == true
        }
    }
}
