import SwiftUI
import PhotosUI

// MARK: - Task detail

struct TaskDetailSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let taskID: UUID

    @State private var editing: CareTask?
    @State private var detailsFor: CompletionToast?
    /// Full height of the scroll content plus its insets, so the sheet can hug it.
    @State private var fittedHeight: CGFloat?
    @State private var detent: PresentationDetent = .medium

    var body: some View {
        NavigationStack {
            Group {
                if let task = store.task(taskID) {
                    content(task)
                } else {
                    ContentUnavailableView("Task removed", systemImage: "trash")
                }
            }
            .navigationTitle(store.task(taskID)?.title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
                if store.isOwner, let task = store.task(taskID) {
                    ToolbarItem(placement: .primaryAction) {
                        Button { editing = task } label: { Text("Edit").font(.bouba(.body, .medium)) }
                    }
                }
            }
            .sheet(item: $editing) { task in
                TaskEditorSheet(task: task, isNew: false, onDelete: { dismiss() })
                .solidSheet()
            }
            .sheet(item: $detailsFor) { info in
                CompletionDetailsSheet(taskID: info.taskID, completionID: info.completionID)
                .solidSheet()
            }
        }
        .presentationDetents([smallDetent, .large], selection: $detent)
        .presentationDragIndicator(.visible)
    }

    /// Half the screen, the system's medium height.
    private var halfScreen: CGFloat {
        let screen = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen.bounds.height }.first
        return (screen ?? 874) / 2
    }

    /// Opens small: hugging short content, or at half height when there's more, then drags up to full.
    private var smallDetent: PresentationDetent {
        guard let fittedHeight, fittedHeight < halfScreen else { return .medium }
        return .height(fittedHeight)
    }

    private func content(_ task: CareTask) -> some View {
        let today = store.selectedDate
        let done = task.completion(on: today)
        let isFuture = today.startOfDay > Date().startOfDay

        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    IconTile(kind: task.kind, size: 50)
                    // The schedule is the headline; timing is a quieter note under it, in orange
                    // (plus its own icon and words) only when it has to happen on time.
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily at \(task.timeString)")
                            .font(.bouba(.body, .semibold))
                        Label(task.isTimeSensitive ? "Time sensitive" : "Flexible timing",
                              systemImage: task.isTimeSensitive ? "clock.badge.exclamationmark.fill" : "clock.fill")
                            .font(.boubaSecondary(.subhead))
                            .foregroundStyle(task.isTimeSensitive ? Color.boubaOrangeText : Color.textSecondary)
                    }
                }

                if !task.amount.isEmpty || !task.instructions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        if !task.amount.isEmpty {
                            KeyValueRow(symbol: "scalemass.fill", label: "Amount", value: task.amount)
                        }
                        if !task.instructions.isEmpty {
                            KeyValueRow(symbol: "text.quote", label: "How to", value: task.instructions)
                        }
                    }
                    .staticCard()
                }

                if let done {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.boubaGreen)
                        Text("Done by \(done.by) at \(done.date.timeString)")
                            .font(.bouba(.subhead, .semibold))
                            .foregroundStyle(Color.onGreenTint)
                        Spacer()
                        Button("Add details") {
                            detailsFor = CompletionToast(taskID: task.id, completionID: done.id, title: task.title)
                        }
                        .font(.bouba(.footnote, .semibold))
                        .buttonStyle(.glass)
                    }
                    .padding(14)
                    .background(Color.boubaGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else if !isFuture {
                    PrimaryButton(title: "Mark complete", systemImage: "checkmark") {
                        withAnimation {
                            if let id = store.complete(task.id) {
                                detailsFor = CompletionToast(taskID: task.id, completionID: id, title: task.title)
                            }
                        }
                    }
                }

                let history = task.completions.filter { $0.date <= Date() }.sorted { $0.date > $1.date }.prefix(8)
                if !history.isEmpty {
                    Text("Recent").font(.bouba(.title3)).padding(.top, 4)
                    // Laid out like the notifications list: plain rows split by hairlines, no card.
                    VStack(spacing: 0) {
                        ForEach(Array(history)) { c in
                            if c.id != history.first?.id { Divider() }
                            CompletionRow(completion: c)
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.top, -8)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Measure the content so short tasks can open at exactly their height.
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentSize.height + geo.contentInsets.top + geo.contentInsets.bottom
        } action: { _, height in
            let height = height.rounded()
            guard height != fittedHeight else { return }
            fittedHeight = height
            // Follow the content while small, but leave it alone once someone drags it up.
            if detent != .large { detent = smallDetent }
        }
    }
}

struct CompletionRow: View {
    let completion: Completion
    @Environment(AppStore.self) private var store

    /// The option picked and any note, as the row's secondary line.
    private var detail: String? {
        let parts = [completion.option, completion.note.isEmpty ? nil : completion.note].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        // Styled like a notification row, minus the action circle, with the text beside the avatar.
        HStack(alignment: .top, spacing: 12) {
            InitialsAvatar(name: completion.by, color: completion.by == store.ownerName ? .boubaOrange : .purple, size: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Text(completion.by).font(.bouba(.callout, .semibold))) \(Text(completion.date.shortAgo).font(.boubaSecondary(.callout)).foregroundStyle(Color.textTertiary))")
                    .accessibilityLabel("\(completion.by), \(completion.date.relativeDay) at \(completion.date.timeString)")
                // Always two lines, so rows without an option or note don't leave a gap beside the avatar.
                Text(detail ?? "No details").font(.boubaSecondary(.callout)).foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let photo = completion.photo {
                PhotoView(photo: photo)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

// MARK: - Task editor

struct TaskEditorSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var task: CareTask
    @State private var time: Date
    @State private var confirmDelete = false
    let isNew: Bool
    var onDelete: (() -> Void)? = nil

    init(task: CareTask, isNew: Bool, onDelete: (() -> Void)? = nil) {
        _task = State(initialValue: task)
        _time = State(initialValue: Date().at(hour: task.hour, minute: task.minute))
        self.isNew = isNew
        self.onDelete = onDelete
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        NavigationStack {
            Form {
                Section(styledHeader: "What kind of task?") {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(TaskKind.allCases) { kind in
                            Button {
                                if task.title.isEmpty || task.title == task.kind.defaultTitle {
                                    task.title = kind.defaultTitle
                                }
                                task.kind = kind
                            } label: {
                                VStack(spacing: 6) {
                                    IconTile(kind: kind, size: 44)
                                        .opacity(task.kind == kind ? 1 : 0.35)
                                        .scaleEffect(task.kind == kind ? 1.08 : 1)
                                    Text(kind.label)
                                        .font(.bouba(.caption))
                                        .foregroundStyle(task.kind == kind ? Color.primary : Color.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                    .sensoryFeedback(.boubaSelect, trigger: task.kind)
                }

                Section(styledHeader: "Details") {
                    TextField("Name", text: $task.title).font(.alloInput)
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    TextField("Amount (e.g. 1 cup, 30 min)", text: $task.amount).font(.alloInput)
                    Toggle(isOn: $task.isTimeSensitive) {
                        Label("Time sensitive", systemImage: "clock.badge.exclamationmark")
                    }
                    .tint(Color.toggleTint)
                }

                Section(styledHeader: "Instructions") {
                    TextField("How should this be done?", text: $task.instructions, axis: .vertical).font(.alloInput)
                        .lineLimit(3...8)
                }

                if !isNew {
                    Section {
                        Button("Delete task", role: .destructive) {
                            confirmDelete = true
                        }
                        .confirmationDialog("Delete \u{201C}\(task.title)\u{201D}?", isPresented: $confirmDelete, titleVisibility: .visible) {
                            Button("Delete task", role: .destructive) {
                                store.deleteTask(task.id)
                                dismiss()
                                onDelete?()
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Its history will be removed too. This can\u{2019}t be undone.")
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New task" : "Edit task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
                        task.hour = comps.hour ?? task.hour
                        task.minute = comps.minute ?? task.minute
                        store.saveTask(task)
                        dismiss()
                    }
                    .disabled(task.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Add photo / note to a completion

struct CompletionDetailsSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let taskID: UUID
    let completionID: UUID

    @State private var option: String?
    @State private var note = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var loaded = false

    var body: some View {
        let task = store.task(taskID)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let task, !task.kind.quickOptions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("How did it go?").font(.bouba(.body, .semibold))
                            FlowLayout {
                                ForEach(task.kind.quickOptions, id: \.self) { o in
                                    Chip(label: o, isSelected: option == o) {
                                        option = option == o ? nil : o
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Photo").font(.bouba(.body, .semibold))
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            if let image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 220)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill").font(.system(size: 28))
                                    Text("Add a photo").font(.bouba(.subhead, .semibold))
                                }
                                .foregroundStyle(Color.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 140)
                                .background(Color.fieldFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            }
                        }
                        .buttonStyle(PressableStyle())
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Note").font(.bouba(.body, .semibold))
                        TextField("Anything worth sharing?", text: $note, axis: .vertical).font(.alloInput)
                            .lineLimit(2...5)
                            .fieldStyle()
                    }
                }
                .padding(20)
            }
            .navigationTitle(task?.title ?? "Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        store.modifyCompletion(taskID: taskID, completionID: completionID) { c in
                            c.option = option
                            c.note = note
                            if let image { c.photo = Photo(image: image) }
                        }
                        dismiss()
                    }
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        withAnimation { image = ui }
                    }
                }
            }
            .onAppear {
                guard !loaded, let c = task?.completions.first(where: { $0.id == completionID }) else { return }
                option = c.option
                note = c.note
                image = c.photo?.image
                loaded = true
            }
        }
    }
}
