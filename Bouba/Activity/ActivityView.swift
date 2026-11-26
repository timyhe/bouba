import SwiftUI

struct CompletionToast: Identifiable, Equatable {
    let id = UUID()
    let taskID: UUID
    let completionID: UUID
    let title: String
}

/// Home screen: today's care for the selected pet.
/// The routine runs down a timeline sorted by time; tasks that share a time keep the owner's order.
struct ActivityView: View {
    @Environment(AppStore.self) private var store

    @State private var showEmergency = false
    @State private var showNotifications = false
    @State private var showReorder = false
    @State private var showPostUpdate = false
    @State private var showAddPet = false
    @State private var detailTask: CareTask?
    @State private var newTask: CareTask?
    @State private var toast: CompletionToast?
    @State private var detailsFor: CompletionToast?

    var body: some View {
        let pet = store.pet

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    WeekStrip()
                        .padding(.horizontal, -20)
                    // The day's content slides sideways when you change dates; the strip itself snaps.
                    ZStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 16) {
                            DaySummaryCard(onComplete: complete)

                            if pet.tasks.isEmpty {
                                emptyState
                            } else {
                                SectionHeader("Schedule") { editMenu }
                                timeline(pet.tasks)
                            }

                            if store.isOwner {
                                addTaskButton
                            }
                        }
                        .id(store.selectedDate)
                        .transition(.push(from: store.dateSlideEdge))
                    }
                    .animation(.snappy(duration: 0.32), value: store.selectedDate)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemBackground))
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottom) { toastOverlay }
            .task(id: toast) {
                guard toast != nil else { return }
                try? await Task.sleep(for: .seconds(7))
                withAnimation(.snappy) { toast = nil }
            }
            .sensoryFeedback(.success, trigger: toast)
            .sheet(isPresented: $showEmergency) { EmergencySheet().solidSheet() }
            .sheet(isPresented: $showNotifications) { NotificationsSheet().solidSheet() }
            .sheet(isPresented: $showReorder) { ReorderSheet().solidSheet() }
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
                        .font(.allo(36, .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.secondary)
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

    /// Tasks grouped by time: a time marker on the left rail, its tasks stacked to the right,
    /// and a dashed line running down to the next time.
    private func timeline(_ tasks: [CareTask]) -> some View {
        let groups = Dictionary(grouping: tasks, by: \.minutesOfDay)
            .sorted { $0.key < $1.key }
            .map(\.value)

        return VStack(spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                let isLast = index == groups.count - 1
                HStack(alignment: .top, spacing: 12) {
                    TimeMarker(task: group[0])
                    VStack(spacing: 10) {
                        ForEach(group) { task in taskCard(task) }
                    }
                }
                .padding(.bottom, isLast ? 0 : 18)
                .background(alignment: .topLeading) {
                    if !isLast {
                        DashedRail()
                            .frame(width: TimelineMetrics.railWidth)
                            .padding(.top, 40)
                    }
                }
            }
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

    @ViewBuilder private var editMenu: some View {
        if store.isOwner {
            Menu {
                Button("Add task", systemImage: "plus") { newTask = blankTask() }
                Button("Rank tasks", systemImage: "arrow.up.arrow.down") { showReorder = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
            }
            .glassEffect(.regular.interactive(), in: .circle)
        }
    }

    private var addTaskButton: some View {
        Button { newTask = blankTask() } label: {
            Label("Add a task", systemImage: "plus")
                .font(.allo(16, .semibold))
                .foregroundStyle(.secondary)
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
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Task card

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
        HStack(alignment: .center, spacing: 12) {
            IconTile(kind: task.kind, size: 44)
                .opacity(completion == nil ? 1 : 0.55)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.allo(17, .semibold))
                    .lineLimit(2)
                tagLine
                statusLine
            }

            Spacer(minLength: 4)
            actionButton
        }
        .padding(12)
        .card(padding: 0)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture(perform: onOpen)
        .confirmationDialog("Mark \(task.title) as not done?", isPresented: $confirmUndo, titleVisibility: .visible) {
            Button("Mark as not done", role: .destructive, action: onUndo)
        }
    }

    /// Lateness. The time lives on the timeline rail, not the card.
    @ViewBuilder private var tagLine: some View {
        if isLate {
            Text("Late")
                .font(.alloSubtext(17))
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }

    @ViewBuilder private var statusLine: some View {
        if let c = completion {
            HStack(spacing: 6) {
                if let photo = c.photo {
                    PhotoView(photo: photo)
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                Text(completedText(c))
                    .lineLimit(1)
            }
            .font(.allo(16, .medium))
            .foregroundStyle(Color.boubaGreen)
        } else if let detail = detailText {
            Text(detail)
                .font(.alloSubtext(16))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    private func completedText(_ c: Completion) -> String {
        var parts = [c.date.timeString]
        if let option = c.option { parts.append(option) }
        return parts.joined(separator: " · ")
    }

    private var detailText: String? {
        var parts: [String] = []
        if !task.amount.isEmpty { parts.append(task.amount) }
        if let last = task.lastCompletion {
            parts.append("Last \(last.date.relativeDay.lowercased()) \(last.date.timeString)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Round check button: empty gray ring to complete, green fill with a check when done.
    @ViewBuilder private var actionButton: some View {
        if completion != nil {
            Button { confirmUndo = true } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.boubaGreen, in: Circle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Done. Tap to undo")
        } else if isFuture {
            Image(systemName: "clock")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 30, height: 30)
                .accessibilityLabel("Upcoming")
        } else {
            Button(action: onComplete) {
                // Empty ring: no fill, no check until it's done.
                Circle()
                    .strokeBorder(Color(.systemGray3).opacity(0.5), lineWidth: 2)
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Complete \(task.title)")
        }
    }
}

// MARK: - Timeline

/// One width shared by the header avatar, the selected day, and the timeline's time markers,
/// so the left edge reads as a single column.
enum TimelineMetrics {
    static let railWidth: CGFloat = 56
}

private struct TimeMarker: View {
    let task: CareTask

    var body: some View {
        // "10:00 AM" → "10:00" over "AM".
        let parts = task.timeString.split(whereSeparator: \.isWhitespace).map(String.init)
        VStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(Color.fieldFill, in: Circle())
            VStack(spacing: -2) {
                Text(parts.first ?? task.timeString)
                if parts.count > 1 { Text(parts.dropFirst().joined(separator: " ")) }
            }
            .font(.allo(15, .semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(.top, 6)
        .padding(.bottom, 10)
        .frame(width: TimelineMetrics.railWidth)
        .background(Color(.systemBackground), in: Capsule())
        .layeredShadow(Capsule())
    }
}

/// The dashed line linking one time marker to the next.
private struct DashedRail: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                p.move(to: CGPoint(x: geo.size.width / 2, y: 0))
                p.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height))
            }
            .stroke(Color(.systemGray4), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
        }
    }
}

// MARK: - Week strip

struct WeekStrip: View {
    @Environment(AppStore.self) private var store
    @State private var scrolledDay: Date?

    private let days: [Date] = (-7...13).map { Date().startOfDay.adding(days: $0) }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(days, id: \.self) { day in
                    DayCell(day: day,
                            isSelected: Calendar.current.isDate(day, inSameDayAs: store.selectedDate),
                            dot: dotColor(for: day))
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
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .onAppear {
            if scrolledDay == nil { scrolledDay = Date().startOfDay }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: store.selectedDate)
    }

    private func dotColor(for day: Date) -> Color {
        let tasks = store.pet.tasks
        guard !tasks.isEmpty, day.startOfDay <= Date().startOfDay else { return .clear }
        let done = tasks.filter { $0.completion(on: day) != nil }.count
        if done == tasks.count { return .boubaGreen }
        if done > 0 { return .boubaOrange }
        return Color(.systemGray4)
    }
}

private struct DayCell: View {
    let day: Date
    let isSelected: Bool
    let dot: Color

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    var body: some View {
        // Allo's line height leaves a big gap between lines, so pull the date up.
        VStack(spacing: -2) {
            Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                .font(.allo(15, .semibold))
                .foregroundStyle(isToday ? Color.red : (isSelected ? Color.primary : Color.secondary))
            Text(day.formatted(.dateTime.day()))
                .font(.allo(30, .semibold))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            Circle()
                .fill(dot)
                .frame(width: 5, height: 5)
                .padding(.top, 8)
        }
        .frame(width: TimelineMetrics.railWidth, height: 88)
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
    /// Completes a task from the Up next card (caretakers only), same as checking it off below.
    var onComplete: (CareTask) -> Void = { _ in }

    var body: some View {
        let pet = store.pet
        let date = store.selectedDate
        let total = pet.tasks.count
        let done = pet.tasks.filter { $0.completion(on: date) != nil }.count

        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Group {
                    if store.isOwner {
                        caringCard(pet: pet, date: date)
                    } else {
                        checkInCard(pet: pet)
                    }
                    nextCard(pet: pet, date: date, allDone: total > 0 && done == total)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .card(padding: 16)
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date.relativeDay.uppercased())
                        .font(.allo(15, .semibold))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                    Text(total == 0 ? "Nothing scheduled" : "\(done) of \(total) done")
                        .font(.allo(26, .bold))
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 0)
                PieProgress(progress: total == 0 ? 0 : Double(done) / Double(total),
                            color: done == total && total > 0 ? Color.boubaGreen : Color.boubaOrange)
                    .frame(width: 56, height: 56)
            }
            .card(padding: 18)
        }
    }

    // MARK: Small cards

    private func smallCard<Icon: View>(title: String, detail: String, @ViewBuilder icon: () -> Icon) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            icon()
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.allo(16, .semibold))
                    .lineLimit(2)
                Text(detail)
                    .font(.alloSubtext(15))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private func caringCard(pet: Pet, date: Date) -> some View {
        let sitters = pet.caretakers.filter { $0.role == .temporary && $0.isActive(on: date) }
        if let sitter = sitters.first {
            smallCard(title: "\(sitter.name) is caring",
                      detail: store.checkedInAt.map { "Checked in at \($0.timeString)" }
                          ?? "Through \(sitter.end.formatted(.dateTime.month(.abbreviated).day()))") {
                InitialsAvatar(name: sitter.name, color: sitter.color, size: 40)
                    .overlay(alignment: .bottomTrailing) {
                        if store.isCheckedIn {
                            Circle().fill(Color.boubaGreen)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().strokeBorder(Color.cardFill, lineWidth: 2))
                        }
                    }
            }
        } else {
            let team = pet.caretakers.filter { $0.role == .coOwner }.map(\.name)
            smallCard(title: team.isEmpty ? "Just you" : "You & \(team.joined(separator: ", "))",
                      detail: "On care today") {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .background(Color.fieldFill, in: Circle())
            }
        }
    }

    private func checkInCard(pet: Pet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            smallCard(title: store.isCheckedIn ? "You're with \(pet.name)" : "Visiting \(pet.name)?",
                      detail: store.checkedInAt.map { "Since \($0.timeString)" } ?? "Let \(store.ownerName) know") {
                InitialsAvatar(name: store.ownerName, color: .boubaOrange, size: 40)
            }
            Spacer(minLength: 0)
            if store.isCheckedIn {
                Button("Check out") { withAnimation { store.toggleCheckIn() } }
                    .font(.allo(15, .semibold))
                    .buttonStyle(.glass)
            } else {
                Button("Check in") { withAnimation { store.toggleCheckIn() } }
                    .font(.allo(15, .semibold))
                    .buttonStyle(.glassProminent)
            }
        }
        .sensoryFeedback(.impact, trigger: store.isCheckedIn)
    }

    @ViewBuilder
    private func nextCard(pet: Pet, date: Date, allDone: Bool) -> some View {
        if let next = nextTask(pet: pet, date: date) {
            let isToday = Calendar.current.isDateInToday(date)
            VStack(alignment: .leading, spacing: 10) {
                smallCard(title: next.title,
                          detail: "\(isToday ? "Up next" : "First up") at \(next.timeString)") {
                    IconTile(kind: next.kind, size: 40)
                }
                // Caretakers can check off what's next without scrolling to it.
                if isToday && !store.isOwner {
                    Spacer(minLength: 0)
                    Button("Complete") { onComplete(next) }
                        .font(.allo(15, .semibold))
                        .buttonStyle(.glass)
                        .tint(Color.primary)
                }
            }
        } else if allDone {
            smallCard(title: "All done", detail: "Nothing left today") {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.boubaGreen, in: Circle())
            }
        } else {
            smallCard(title: "Nothing up next", detail: "Enjoy the quiet") {
                Image(systemName: "moon.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .background(Color.fieldFill, in: Circle())
            }
        }
    }

    /// Today: the next task not yet done. Other days: the first task of the day.
    private func nextTask(pet: Pet, date: Date) -> CareTask? {
        guard Calendar.current.isDateInToday(date) else {
            return pet.tasks.min { $0.minutesOfDay < $1.minutesOfDay }
        }
        let nowMinutes = Calendar.current.component(.hour, from: Date()) * 60 + Calendar.current.component(.minute, from: Date())
        return pet.tasks
            .filter { $0.completion(on: date) == nil && $0.minutesOfDay >= nowMinutes - 30 }
            .min { $0.minutesOfDay < $1.minutesOfDay }
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
