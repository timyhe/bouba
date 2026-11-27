import SwiftUI
import Observation

/// In-memory app state. No backend yet — everything resets on relaunch.
@Observable
final class AppStore {
    /// Pick a day from the week strip. When the slide direction flips, the outgoing day needs one
    /// update with the new direction before it leaves, so the date changes on the next tick.
    func selectDate(_ day: Date) {
        guard !Calendar.current.isDate(day, inSameDayAs: selectedDate) else { return }
        let edge: Edge = day > selectedDate ? .trailing : .leading
        if edge == dateSlideEdge {
            selectedDate = day
        } else {
            dateSlideEdge = edge
            Task { @MainActor in self.selectedDate = day }
        }
    }

    var hasOnboarded = false
    /// Meet the pet is shown from the root during onboarding, so finishing can swap
    /// to the app underneath and slide the modal down to reveal it.
    var showingMeet = false
    var role: Role = .owner
    var pets: [Pet]
    var selectedPetID: UUID
    var selectedDate: Date = Date().startOfDay
    /// Which edge the day's content slides in from: later days come from the right, earlier from the left.
    private(set) var dateSlideEdge: Edge = .trailing
    var notifications: [AppNotification]
    var hasUnreadNotifications = true
    var checkedInAt: Date? = nil
    /// The pet just created, so Activity can welcome it with a celebratory toast once.
    var newlyAddedPetID: UUID?

    let ownerName = "Brian"
    let ownerPhoto: String? = "avatar-brian"
    let sitterName = "Andrew"

    init() {
        let felix = AppStore.makeFelix()
        let mochi = AppStore.makeMochi()
        pets = [felix, mochi]
        selectedPetID = felix.id
        notifications = AppStore.makeNotifications()
    }

    // MARK: Derived

    var isOwner: Bool { role == .owner }
    var currentUserName: String { isOwner ? ownerName : sitterName }
    var isCheckedIn: Bool { checkedInAt != nil }

    var pet: Pet {
        get { pets.first { $0.id == selectedPetID } ?? pets[0] }
        set {
            if let i = pets.firstIndex(where: { $0.id == newValue.id }) { pets[i] = newValue }
        }
    }

    func task(_ id: UUID) -> CareTask? {
        pet.tasks.first { $0.id == id }
    }

    // MARK: Mutations

    func modifyPet(_ change: (inout Pet) -> Void) {
        guard let i = pets.firstIndex(where: { $0.id == selectedPetID }) else { return }
        change(&pets[i])
    }

    func modifyTask(_ id: UUID, _ change: (inout CareTask) -> Void) {
        modifyPet { pet in
            guard let t = pet.tasks.firstIndex(where: { $0.id == id }) else { return }
            change(&pet.tasks[t])
        }
    }

    /// Marks a task done for the selected day. Returns the new completion's id.
    @discardableResult
    func complete(_ taskID: UUID) -> UUID? {
        guard let task = task(taskID) else { return nil }
        let isToday = Calendar.current.isDateInToday(selectedDate)
        let date = isToday ? Date() : selectedDate.at(hour: task.hour, minute: task.minute)
        let completion = Completion(date: date, by: currentUserName)
        modifyTask(taskID) { $0.completions.append(completion) }
        if !isOwner {
            notifications.insert(
                AppNotification(date: Date(), symbol: task.kind.symbol, color: task.kind.color,
                                title: "\(sitterName) completed \(task.title)",
                                body: "\(pet.name)'s \(task.title.lowercased()) is done.",
                                actor: sitterName),
                at: 0)
            hasUnreadNotifications = true
        }
        return completion.id
    }

    func modifyCompletion(taskID: UUID, completionID: UUID, _ change: (inout Completion) -> Void) {
        modifyTask(taskID) { task in
            guard let c = task.completions.firstIndex(where: { $0.id == completionID }) else { return }
            change(&task.completions[c])
        }
    }

    func undoCompletion(taskID: UUID, on day: Date) {
        modifyTask(taskID) { task in
            task.completions.removeAll { Calendar.current.isDate($0.date, inSameDayAs: day) }
        }
    }

    func saveTask(_ task: CareTask) {
        modifyPet { pet in
            if let i = pet.tasks.firstIndex(where: { $0.id == task.id }) {
                pet.tasks[i] = task
            } else {
                // New tasks slot in by time; after that the owner's drag order wins.
                let i = pet.tasks.firstIndex { $0.minutesOfDay > task.minutesOfDay } ?? pet.tasks.endIndex
                pet.tasks.insert(task, at: i)
            }
        }
    }

    func deleteTask(_ id: UUID) {
        modifyPet { $0.tasks.removeAll { $0.id == id } }
    }

    func post(_ update: PetUpdate) {
        modifyPet { $0.updates.append(update) }
        if !isOwner {
            let count = update.photos.count
            notifications.insert(
                AppNotification(date: Date(), symbol: "paperplane.fill", color: .pink,
                                title: count > 0 ? "\(sitterName) shared \(count) photo\(count == 1 ? "" : "s")" : "\(sitterName) shared an update",
                                body: update.text,
                                actor: sitterName,
                                mood: update.mood,
                                photos: update.photos),
                at: 0)
            hasUnreadNotifications = true
        }
    }

    func toggleCheckIn() {
        let now = Date()
        if checkedInAt == nil {
            checkedInAt = now
            post(PetUpdate(date: now, by: currentUserName, kind: .arrived))
        } else {
            checkedInAt = nil
            post(PetUpdate(date: now, by: currentUserName, kind: .left))
        }
    }

    func saveCaretaker(_ caretaker: Caretaker) {
        modifyPet { pet in
            if let i = pet.caretakers.firstIndex(where: { $0.id == caretaker.id }) {
                pet.caretakers[i] = caretaker
            } else {
                pet.caretakers.append(caretaker)
            }
        }
    }

    func removeCaretaker(_ id: UUID) {
        modifyPet { $0.caretakers.removeAll { $0.id == id } }
    }

    func addPet(_ pet: Pet) {
        var pet = pet
        // Start in time order; the owner can drag tasks around from there.
        pet.tasks = pet.tasks.byTime
        pets.append(pet)
        selectedPetID = pet.id
        selectedDate = Date().startOfDay
        newlyAddedPetID = pet.id
    }

    func joinAsCaretaker() {
        role = .caretaker
        selectedPetID = pets[0].id
        selectedDate = Date().startOfDay
        hasOnboarded = true
    }

    func startAsOwner() {
        role = .owner
        selectedDate = Date().startOfDay
        hasOnboarded = true
    }
}

// MARK: - Sample data

extension AppStore {
    static func makeFelix() -> Pet {
        let today = Date().startOfDay
        var tasks: [CareTask] = [
            CareTask(kind: .medication, title: "Joint supplement", hour: 8, minute: 15, amount: "1 chew",
                     instructions: "Give with breakfast. He'll take it right from your hand — chews are in the jar next to the coffee maker.",
                     isTimeSensitive: true),
            CareTask(kind: .food, title: "Breakfast", hour: 8, minute: 15, amount: "1 cup kibble",
                     instructions: "Kibble is in the bin under the sink, scoop inside. Once a day only — he will beg. Stay strong!",
                     isTimeSensitive: true),
            CareTask(kind: .water, title: "Last water", hour: 19, minute: 45, amount: "Fill bowl",
                     instructions: "Top up his bowl, then pick it up at 8 PM. No water after 8 so he sleeps through the night.",
                     isTimeSensitive: true),
            CareTask(kind: .bathroom, title: "Morning potty", hour: 8, minute: 0,
                     instructions: "Quick trip out front. He likes the tree by the hydrant."),
            CareTask(kind: .walk, title: "Walk", hour: 12, minute: 0, amount: "30 min",
                     instructions: "Harness + leash are on the hook by the door. Pulls a little at first, then settles. Friendly with people, a bit shy with big dogs."),
            CareTask(kind: .play, title: "Park & social time", hour: 15, minute: 30, amount: "30 min",
                     instructions: "The dog run at Gantry Plaza is his favorite. Recall is good — say \"Felix, come!\" and show a treat."),
            CareTask(kind: .bathroom, title: "Afternoon potty", hour: 17, minute: 0),
            CareTask(kind: .treat, title: "Treats", hour: 18, minute: 0, amount: "1–2 biscuits",
                     instructions: "A couple of treats a day are fine. Biscuits are in the top kitchen drawer."),
            CareTask(kind: .bathroom, title: "Bedtime potty", hour: 20, minute: 0),
        ]

        let now = Date()
        for i in tasks.indices {
            let task = tasks[i]
            for daysAgo in 1...3 {
                let date = today.adding(days: -daysAgo).at(hour: task.hour, minute: task.minute).adding(minutes: Int.random(in: 0...14))
                var completion = Completion(date: date, by: daysAgo == 3 ? "Brian" : "Andrew", option: task.kind.quickOptions.first)
                if task.kind == .play && daysAgo == 1 {
                    completion.photo = Photo(sample: 1)
                    completion.note = "Played fetch for ages, then napped in the sun."
                }
                tasks[i].completions.append(completion)
            }
            let due = today.at(hour: task.hour, minute: task.minute)
            if due.adding(minutes: 20) < now {
                tasks[i].completions.append(
                    Completion(date: due.adding(minutes: Int.random(in: 0...10)), by: "Andrew", option: task.kind.quickOptions.first))
            }
        }

        let kayla = Caretaker(name: "Kayla", role: .coOwner, color: .teal, photo: "avatar-kayla", notifyOnComplete: true,
                              photoFrequency: .none, canEditTasks: true)
        let andrew = Caretaker(name: "Andrew", role: .temporary, color: .purple, photo: "avatar-andrew",
                               start: today.adding(days: -1), end: today.adding(days: 3), earlyAccessDays: 3,
                               notifyOnComplete: true, photoFrequency: .daily, checkInOut: false,
                               inviteCode: "FX7K2Q")
        let maya = Caretaker(name: "Maya", role: .regular, color: .pink, photoFrequency: .everyVisit, isPending: true)

        let updates: [PetUpdate] = [
            PetUpdate(date: today.adding(days: -1).at(hour: 16, minute: 10), by: "Andrew",
                      text: "Felix made a new best friend at the dog run!", mood: "Playful",
                      photos: [Photo(sample: 0), Photo(sample: 1)]),
            PetUpdate(date: today.adding(days: -1).at(hour: 21, minute: 30), by: "Andrew",
                      text: "Out like a light.", mood: "Sleepy", photos: [Photo(sample: 2)]),
            PetUpdate(date: today.adding(days: -2).at(hour: 9, minute: 5), by: "Andrew",
                      text: "Settled in great! Ate all his breakfast.", mood: "Happy", photos: [Photo(sample: 3)]),
        ]

        return Pet(
            name: "Felix", species: .dog, breed: "Goldendoodle", age: 8, size: .medium,
            photo: UIImage(named: "pet-felix"),
            color: .boubaOrange,
            tasks: tasks.byTime,
            notes: [
                InstructionNote(title: "Personality", body: "Easy-going and loves everyone. A little shy around big dogs at first.", symbol: "face.smiling.inverse"),
                InstructionNote(title: "Bedtime", body: "Sleeps in his bed in the living room. Lights out around 10 PM.", symbol: "moon.fill"),
                InstructionNote(title: "Leash & walks", body: "Harness on the hook by the door. Keep him leashed except in the dog run.", symbol: "figure.walk"),
            ],
            mustNotEat: ["Chocolate", "Grapes & raisins", "Cooked bones", "Onions & garlic"],
            medical: "Mild arthritis in his back legs — joint supplement every morning. No allergies.",
            home: HomeAccess(address: "27-14 Jackson Ave, Apt 5C\nLong Island City, NY",
                             entry: "Key is in the lockbox on the front gate",
                             code: "4821",
                             wifiName: "FelixFanClub",
                             wifiPassword: "goodboy2024",
                             notes: "Spare key with the doorman — ask for Luis."),
            vet: VetInfo(clinic: "LIC Animal Hospital", phone: "(718) 555-0142",
                         address: "10-40 Jackson Ave, Long Island City", permission: .anytime),
            contacts: [
                Contact(name: "Brian", relation: "Owner", phone: "(917) 555-0101"),
                Contact(name: "Kayla", relation: "Co-owner", phone: "(917) 555-0123"),
            ],
            caretakers: [kayla, andrew, maya],
            updates: updates
        )
    }

    static func makeMochi() -> Pet {
        let today = Date().startOfDay
        var tasks: [CareTask] = [
            CareTask(kind: .litter, title: "Scoop litter", hour: 9, minute: 0,
                     instructions: "Litter box is in the bathroom. Bags and scoop are on the shelf above.", isTimeSensitive: true),
            CareTask(kind: .water, title: "Clean water bowl", hour: 9, minute: 0, amount: "Rinse & refill",
                     instructions: "Rinse the fountain bowl and refill with filtered water from the fridge."),
            CareTask(kind: .play, title: "Play time", hour: 19, minute: 0, amount: "15 min",
                     instructions: "She loves the feather wand (in the basket by the couch). The automatic feeder handles meals."),
        ]
        for i in tasks.indices {
            tasks[i].completions.append(
                Completion(date: today.adding(days: -1).at(hour: tasks[i].hour, minute: tasks[i].minute), by: "Brian"))
        }
        return Pet(
            name: "Mochi", species: .cat, breed: "Tabby", age: 4, size: .small,
            color: .teal,
            tasks: tasks.byTime,
            notes: [InstructionNote(title: "Feeding", body: "Automatic feeder dispenses at 7 AM and 6 PM. Just make sure it isn't jammed.", symbol: "fork.knife")],
            mustNotEat: ["Lilies (toxic!)", "Milk"],
            home: HomeAccess(address: "27-14 Jackson Ave, Apt 5C\nLong Island City, NY", entry: "Lockbox on the front gate", code: "4821"),
            vet: VetInfo(clinic: "LIC Animal Hospital", phone: "(718) 555-0142", permission: .callFirst),
            contacts: [Contact(name: "Brian", relation: "Owner", phone: "(917) 555-0101")],
            caretakers: [Caretaker(name: "Kayla", role: .coOwner, color: .teal, photo: "avatar-kayla", canEditTasks: true)]
        )
    }

    static func makeNotifications() -> [AppNotification] {
        let now = Date()
        return [
            AppNotification(date: now.adding(minutes: -35), symbol: "fork.knife", color: .petOrange,
                            title: "Andrew completed Breakfast", body: "Felix ate it all.", actor: "Andrew", actorColor: .purple),
            AppNotification(date: now.adding(minutes: -60 * 18), symbol: "paperplane.fill", color: .pink,
                            title: "Andrew shared 2 photos", body: "Felix made a new best friend at the dog run!", actor: "Andrew", actorColor: .purple,
                            mood: "Playful", photos: [Photo(sample: 0), Photo(sample: 1)]),
            AppNotification(date: now.adding(minutes: -60 * 26), symbol: "person.badge.plus", color: .blue,
                            title: "Andrew joined Felix's care team", body: "Access through \(Date().adding(days: 3).shortDay).", actor: "Andrew", actorColor: .purple),
        ]
    }
}

extension Array where Element == CareTask {
    /// Earliest first. Tasks at the same time keep their order.
    var byTime: [CareTask] {
        enumerated()
            .sorted { ($0.element.minutesOfDay, $0.offset) < ($1.element.minutesOfDay, $1.offset) }
            .map(\.element)
    }
}
