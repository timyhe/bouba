import SwiftUI

struct MeView: View {
    @Environment(AppStore.self) private var store
    @State private var showJoin = false
    @State private var remindTasks = true
    @State private var notifyCompletions = true
    @State private var notifyPhotos = true

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        InitialsAvatar(name: store.currentUserName, color: store.isOwner ? .boubaOrange : .purple, size: 58)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.currentUserName).font(.allo(22, .bold))
                            Text(store.isOwner ? "Owner · \(store.pets.count) pets" : "Pet sitter for \(store.pets[0].name)")
                                .font(.alloSubtext(17))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Picker("View as", selection: $store.role) {
                        Text("Owner (Brian)").tag(Role.owner)
                        Text("Caretaker (Andrew)").tag(Role.caretaker)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: store.role) { _, role in
                        if role == .caretaker { store.selectedPetID = store.pets[0].id }
                    }
                } header: {
                    Text("Prototype")
                } footer: {
                    Text("Switch perspectives to see what owners and caretakers each get. Completing tasks as Andrew sends Brian notifications.")
                }

                Section("Notifications") {
                    Toggle("Task reminders", isOn: $remindTasks)
                        .tint(Color.boubaOrange)
                    Toggle("When tasks are completed", isOn: $notifyCompletions)
                        .tint(Color.boubaOrange)
                    Toggle("Photo updates", isOn: $notifyPhotos)
                        .tint(Color.boubaOrange)
                }

                Section("Pets") {
                    ForEach(store.isOwner ? store.pets : [store.pets[0]]) { pet in
                        Button {
                            store.selectedPetID = pet.id
                        } label: {
                            HStack(spacing: 12) {
                                PetAvatar(pet: pet, size: 38)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(pet.name).font(.allo(16, .semibold))
                                    Text(pet.subtitle).font(.alloSubtext(15)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if pet.id == store.selectedPetID {
                                    Image(systemName: "checkmark").foregroundStyle(Color.boubaOrange)
                                }
                            }
                        }
                        .tint(Color.primary)
                    }
                    Button("Join a pet with a code", systemImage: "link") { showJoin = true }
                }

                if store.isOwner {
                    Section {
                        LabeledContent("Bouba Free", value: "1 free sitter left")
                        Button("Refer a friend, get a free sitter", systemImage: "gift.fill") {}
                    } header: {
                        Text("Plan")
                    } footer: {
                        Text("You and co-owners are always free. Temporary sitters are part of Bouba Plus.")
                    }
                }

                Section {
                    Button("Replay onboarding", systemImage: "arrow.counterclockwise") {
                        store.hasOnboarded = false
                    }
                    Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        store.role = .owner
                        store.hasOnboarded = false
                    }
                }
            }
            .navigationTitle("Me")
            .sheet(isPresented: $showJoin) {
                NavigationStack {
                    JoinInviteView(onFinish: { showJoin = false })
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel", systemImage: "xmark") { showJoin = false }
                            }
                        }
                }
                .solidSheet()
            }
        }
    }
}
