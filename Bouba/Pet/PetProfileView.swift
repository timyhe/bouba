import SwiftUI
import PhotosUI

/// Everything a caretaker needs to know: personality, food rules, home access, vet.
/// Owners also manage who has access from here.
struct PetProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var showEdit = false
    @State private var showInvite = false
    @State private var editingCaretaker: Caretaker?
    @State private var showMeet = false

    var body: some View {
        let pet = store.pet

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header(pet)

                    if !pet.notes.isEmpty {
                        InfoCard(title: "About \(pet.name)", symbol: "heart.fill", tint: .pink) {
                            ForEach(pet.notes) { note in
                                KeyValueRow(symbol: note.symbol, label: note.title, value: note.body)
                            }
                        }
                    }

                    if !pet.mustNotEat.isEmpty {
                        InfoCard(title: "Must not eat", symbol: "nosign", tint: .red) {
                            FlowLayout {
                                ForEach(pet.mustNotEat, id: \.self) { Tag(text: $0, color: .dangerText, symbol: "xmark") }
                            }
                            .padding(.leading, InfoCardMetrics.textInset)
                        }
                    }

                    if store.isOwner || accessForCaretaker(pet) {
                        InfoCard(title: "Getting in", symbol: "key.fill", tint: .blue) {
                            if !pet.home.address.isEmpty {
                                KeyValueRow(symbol: "mappin.and.ellipse", label: "Address", value: pet.home.address, copyable: true)
                            }
                            if !pet.home.entry.isEmpty {
                                KeyValueRow(symbol: "door.left.hand.closed", label: "Entry", value: pet.home.entry)
                            }
                            if !pet.home.code.isEmpty {
                                KeyValueRow(symbol: "lock.fill", label: "Lockbox code", value: pet.home.code, secret: true)
                            }
                            if !pet.home.wifiName.isEmpty {
                                KeyValueRow(symbol: "wifi", label: "Wi-Fi", value: pet.home.wifiName)
                            }
                            if !pet.home.wifiPassword.isEmpty {
                                KeyValueRow(symbol: "key.horizontal.fill", label: "Wi-Fi password", value: pet.home.wifiPassword, secret: true, copyable: true)
                            }
                            if !pet.home.notes.isEmpty {
                                KeyValueRow(symbol: "note.text", label: "Notes", value: pet.home.notes)
                            }
                        }
                    }

                    InfoCard(title: "Vet & emergency", symbol: "cross.case.fill", tint: .red) {
                        if !pet.vet.clinic.isEmpty {
                            KeyValueRow(symbol: "stethoscope", label: "Vet", value: pet.vet.clinic)
                        }
                        if !pet.vet.phone.isEmpty {
                            KeyValueRow(symbol: "phone.fill", label: "Vet phone", value: pet.vet.phone, copyable: true)
                        }
                        KeyValueRow(symbol: pet.vet.permission.symbol, label: "If something's wrong", value: pet.vet.permission.label)
                        if !pet.medical.isEmpty {
                            KeyValueRow(symbol: "heart.text.square.fill", label: "Medical notes", value: pet.medical)
                        }
                    }

                    if store.isOwner {
                        caretakersCard(pet)
                    } else {
                        Button { showMeet = true } label: {
                            Label("Replay \u{201C}Meet \(pet.name)\u{201D}", systemImage: "rectangle.stack.fill")
                                .font(.allo(16, .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if store.isOwner {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showEdit = true } label: { Text("Edit").font(.allo(17, .medium)) }
                    }
                }
            }
            .sheet(isPresented: $showEdit) { EditPetSheet(pet: pet).solidSheet() }
            .sheet(isPresented: $showInvite) { InviteCaretakerSheet().solidSheet() }
            .sheet(item: $editingCaretaker) { c in InviteCaretakerSheet(existing: c).solidSheet() }
            .fullScreenCover(isPresented: $showMeet) {
                NavigationStack { MeetThePetView(onFinish: { showMeet = false }) }
            }
        }
    }

    private func accessForCaretaker(_ pet: Pet) -> Bool {
        pet.caretakers.first { $0.name == store.sitterName }?.showHomeAccess ?? true
    }

    private func header(_ pet: Pet) -> some View {
        VStack(spacing: 12) {
            PetAvatar(pet: pet, size: 116)
            VStack(spacing: 4) {
                Text(pet.name).font(.allo(34, .bold))
                Text(pet.breed.isEmpty ? pet.species.label : pet.breed)
                    .font(.alloSubtext(18))
                    .foregroundStyle(Color.textSecondary)
            }
            HStack(spacing: 10) {
                fact("\(pet.age)", "years old")
                fact(pet.size.label, "size")
                fact(pet.species.label, "species")
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }

    private func fact(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.allo(20, .bold))
            Text(label).font(.alloSubtext(15)).foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .layeredShadow(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func caretakersCard(_ pet: Pet) -> some View {
        InfoCard(title: "Care team", symbol: "person.2.fill", tint: .purple) {
            HStack(spacing: InfoCardMetrics.gap) {
                InitialsAvatar(name: store.ownerName, color: .boubaOrange, size: InfoCardMetrics.iconColumn)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(store.ownerName) (you)").font(.allo(16, .semibold))
                    Text("Owner").font(.alloSubtext(15)).foregroundStyle(Color.textSecondary)
                }
                Spacer()
            }
            ForEach(pet.caretakers) { c in
                Button { editingCaretaker = c } label: {
                    HStack(spacing: InfoCardMetrics.gap) {
                        InitialsAvatar(name: c.name, color: c.color, size: InfoCardMetrics.iconColumn)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.name).font(.allo(16, .semibold))
                            Text("\(c.role.label) · \(c.accessSummary)")
                                .font(.alloSubtext(15))
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                        StatusBadge(status: c.status)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Button { showInvite = true } label: {
                Label("Invite a caretaker", systemImage: "person.badge.plus")
                    .font(.allo(18, .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding(.top, 4)
        }
    }
}

// MARK: - Edit profile

struct EditPetSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Pet
    @State private var photoItem: PhotosPickerItem?
    @State private var newAvoid = ""

    init(pet: Pet) {
        _draft = State(initialValue: pet)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            VStack(spacing: 8) {
                                PetAvatar(pet: draft, size: 100)
                                Text("Change photo").font(.allo(14, .semibold))
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

                Section("Basics") {
                    TextField("Name", text: $draft.name).font(.alloInput)
                    Picker("Species", selection: $draft.species) {
                        ForEach(Species.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
                    }
                    TextField("Breed", text: $draft.breed).font(.alloInput)
                    Stepper("Age: \(draft.age) yr\(draft.age == 1 ? "" : "s")", value: $draft.age, in: 0...30)
                    Picker("Size", selection: $draft.size) {
                        ForEach(PetSize.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("About") {
                    ForEach($draft.notes) { $note in
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Title", text: $note.title).font(.allo(16, .semibold))
                            TextField("Details", text: $note.body, axis: .vertical).font(.alloInput)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                    .onDelete { draft.notes.remove(atOffsets: $0) }
                    Button("Add note", systemImage: "plus") {
                        draft.notes.append(InstructionNote(title: "", body: ""))
                    }
                }

                Section("Must not eat") {
                    if !draft.mustNotEat.isEmpty {
                        FlowLayout {
                            ForEach(draft.mustNotEat, id: \.self) { item in
                                Chip(label: item, symbol: "xmark", isSelected: true, tint: .dangerText) {
                                    withAnimation { draft.mustNotEat.removeAll { $0 == item } }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    HStack {
                        TextField("Add a food", text: $newAvoid).font(.alloInput)
                            .onSubmit(addAvoid)
                        Button("Add", action: addAvoid)
                            .disabled(newAvoid.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section("Home access") {
                    TextField("Address", text: $draft.home.address, axis: .vertical).font(.alloInput)
                    TextField("How to get in", text: $draft.home.entry).font(.alloInput)
                    TextField("Door or lockbox code", text: $draft.home.code).font(.alloInput)
                    TextField("Wi-Fi name", text: $draft.home.wifiName).font(.alloInput)
                    TextField("Wi-Fi password", text: $draft.home.wifiPassword).font(.alloInput)
                    TextField("Other notes", text: $draft.home.notes, axis: .vertical).font(.alloInput)
                }

                Section {
                    TextField("Vet clinic", text: $draft.vet.clinic).font(.alloInput)
                    TextField("Vet phone", text: $draft.vet.phone).font(.alloInput)
                        .keyboardType(.phonePad)
                    TextField("Vet address", text: $draft.vet.address).font(.alloInput)
                    Picker("If something's wrong", selection: $draft.vet.permission) {
                        ForEach(VetPermission.allCases) { Text($0.label).tag($0) }
                    }
                    TextField("Medical notes", text: $draft.medical, axis: .vertical).font(.alloInput)
                } header: {
                    Text("Vet & emergency")
                } footer: {
                    Text("Caretakers see this from the \(Image(systemName: "exclamationmark.triangle")) button on the Activity screen.")
                }
            }
            .navigationTitle("Edit \(draft.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        store.pet = draft
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        draft.photo = image
                    }
                }
            }
        }
    }

    private func addAvoid() {
        let trimmed = newAvoid.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        withAnimation { draft.mustNotEat.append(trimmed) }
        newAvoid = ""
    }
}
