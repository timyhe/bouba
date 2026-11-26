import SwiftUI
import PhotosUI

enum HistoryItem: Identifiable {
    case completion(CareTask, Completion)
    case update(PetUpdate)

    var id: UUID {
        switch self {
        case .completion(_, let c): return c.id
        case .update(let u): return u.id
        }
    }

    var date: Date {
        switch self {
        case .completion(_, let c): return c.date
        case .update(let u): return u.date
        }
    }

    var hasPhoto: Bool {
        switch self {
        case .completion(_, let c): return c.photo != nil
        case .update(let u): return !u.photos.isEmpty
        }
    }
}

enum HistoryFilter: String, CaseIterable, Identifiable {
    case all, photos, tasks, visits
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "All"
        case .photos: return "Photos"
        case .tasks: return "Tasks"
        case .visits: return "Visits"
        }
    }
}

private struct DayGroup: Identifiable {
    let day: Date
    let items: [HistoryItem]
    var id: Date { day }
}

/// A timeline of everything that happened: completed tasks, photo updates, visits.
/// Answers the owner's "is my pet OK?" at a glance.
struct HistoryView: View {
    @Environment(AppStore.self) private var store
    @State private var filter: HistoryFilter = .all
    @State private var showPost = false

    private var groups: [DayGroup] {
        let pet = store.pet
        var items: [HistoryItem] = []
        for task in pet.tasks {
            for c in task.completions where c.date <= Date() {
                items.append(.completion(task, c))
            }
        }
        items += pet.updates.map { HistoryItem.update($0) }

        items = items.filter { item in
            switch filter {
            case .all: return true
            case .photos: return item.hasPhoto
            case .tasks:
                if case .completion = item { return true }
                return false
            case .visits:
                if case .update(let u) = item { return u.kind != .post }
                return false
            }
        }

        let byDay = Dictionary(grouping: items) { $0.date.startOfDay }
        return byDay.keys.sorted(by: >).map { day in
            DayGroup(day: day, items: (byDay[day] ?? []).sorted { $0.date > $1.date })
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Picker("Filter", selection: $filter) {
                        ForEach(HistoryFilter.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 4)

                    if groups.isEmpty {
                        ContentUnavailableView("Nothing here yet", systemImage: "clock",
                                               description: Text("Completed tasks and photo updates will show up here."))
                            .padding(.top, 40)
                    }

                    ForEach(groups) { group in
                        Text(group.day.relativeDay)
                            .font(.allo(21, .bold))
                            .padding(.top, 12)
                        ForEach(group.items) { item in
                            switch item {
                            case .completion(let task, let c):
                                HistoryCompletionRow(task: task, completion: c)
                            case .update(let u):
                                if u.kind == .post {
                                    UpdateCard(update: u)
                                } else {
                                    VisitRow(update: u)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Post update", systemImage: "camera.fill") { showPost = true }
                }
            }
            .sheet(isPresented: $showPost) { PostUpdateSheet().solidSheet() }
        }
    }
}

private struct HistoryCompletionRow: View {
    let task: CareTask
    let completion: Completion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(kind: task.kind, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Text(completion.by).font(.allo(16, .semibold))) completed \(Text(task.title).font(.allo(16, .semibold)))")
                    .font(.allo(16))
                HStack(spacing: 6) {
                    Text(completion.date.timeString)
                    if let option = completion.option {
                        Text("·")
                        Text(option)
                    }
                }
                .font(.alloSubtext(16))
                .foregroundStyle(.secondary)
                if !completion.note.isEmpty {
                    Text(completion.note).font(.allo(15))
                }
                if let photo = completion.photo {
                    PhotoView(photo: photo)
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

private struct VisitRow: View {
    let update: PetUpdate

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: update.kind == .arrived ? "door.left.hand.open" : "door.left.hand.closed")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text("\(Text(update.by).font(.allo(16, .semibold))) \(update.kind == .arrived ? "arrived" : "left")")
                .font(.allo(16))
            Spacer()
            Text(update.date.timeString).font(.alloSubtext(16)).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct UpdateCard: View {
    let update: PetUpdate
    private let grid = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                InitialsAvatar(name: update.by, color: .purple, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(update.by).font(.allo(16, .semibold))
                    Text(update.date.timeString).font(.alloSubtext(15)).foregroundStyle(.secondary)
                }
                Spacer()
                if let mood = update.mood {
                    Tag(text: mood, color: .boubaOrange, symbol: PetUpdate.moodSymbol(mood))
                }
            }

            if update.photos.count == 1, let photo = update.photos.first {
                PhotoView(photo: photo)
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else if update.photos.count > 1 {
                LazyVGrid(columns: grid, spacing: 6) {
                    ForEach(update.photos) { photo in
                        PhotoView(photo: photo)
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }

            if !update.text.isEmpty {
                Text(update.text).font(.allo(16))
            }
        }
        .card()
    }
}

// MARK: - Post an update

struct PostUpdateSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var items: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []
    @State private var text = ""
    @State private var mood: String?

    private let grid = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PhotosPicker(selection: $items, maxSelectionCount: 6, matching: .images) {
                        if images.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 34))
                                Text("Add photos of \(store.pet.name)")
                                    .font(.allo(16, .semibold))
                            }
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .background(Color.fieldFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        } else {
                            LazyVGrid(columns: grid, spacing: 8) {
                                ForEach(images.indices, id: \.self) { i in
                                    Image(uiImage: images[i])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 110)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                        }
                    }
                    .buttonStyle(PressableStyle())

                    VStack(alignment: .leading, spacing: 10) {
                        Text("How's \(store.pet.name) doing?").font(.allo(17, .semibold))
                        FlowLayout {
                            ForEach(PetUpdate.moods, id: \.self) { m in
                                Chip(label: m, symbol: PetUpdate.moodSymbol(m), isSelected: mood == m) { mood = mood == m ? nil : m }
                            }
                        }
                    }

                    TextField("Write a quick note…", text: $text, axis: .vertical)
                        .lineLimit(3...6)
                        .fieldStyle()
                }
                .padding(20)
            }
            .navigationTitle("New update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post", systemImage: "paperplane.fill") {
                        store.post(PetUpdate(date: Date(), by: store.currentUserName, text: text, mood: mood,
                                             photos: images.map { Photo(image: $0) }))
                        dismiss()
                    }
                    .disabled(images.isEmpty && text.isEmpty && mood == nil)
                }
            }
            .onChange(of: items) { _, newItems in
                Task {
                    var loaded: [UIImage] = []
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            loaded.append(image)
                        }
                    }
                    withAnimation { images = loaded }
                }
            }
        }
    }
}
