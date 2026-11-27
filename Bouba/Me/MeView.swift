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
                            Text(store.currentUserName).font(.bouba(.title2))
                            Text(store.isOwner ? "Owner · \(store.pets.count) pets" : "Pet sitter for \(store.pets[0].name)")
                                .font(.boubaSecondary(.body))
                                .foregroundStyle(Color.textSecondary)
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
                    header("Prototype")
                } footer: {
                    footer("Switch perspectives to see what owners and caretakers each get. Completing tasks as Andrew sends Brian notifications.")
                }

                Section {
                    Toggle("Task reminders", isOn: $remindTasks)
                        .tint(Color.toggleTint)
                    Toggle("When tasks are completed", isOn: $notifyCompletions)
                        .tint(Color.toggleTint)
                    Toggle("Photo updates", isOn: $notifyPhotos)
                        .tint(Color.toggleTint)
                } header: {
                    header("Notifications")
                }

                Section {
                    ForEach(store.isOwner ? store.pets : [store.pets[0]]) { pet in
                        Button {
                            store.selectedPetID = pet.id
                        } label: {
                            // Avatar matches the list's icon size, and the 16pt gap puts the names on the
                            // same edge as "Join a pet with a code" below.
                            HStack(spacing: 16) {
                                PetAvatar(pet: pet, size: 24)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(pet.name).font(.bouba(.callout, .semibold))
                                    Text(pet.subtitle).font(.boubaSecondary(.subhead)).foregroundStyle(Color.textSecondary)
                                }
                                .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.boubaOrange)
                                    .opacity(pet.id == store.selectedPetID ? 1 : 0)
                                    .instantSelection()
                                    .accessibilityHidden(pet.id != store.selectedPetID)
                            }
                        }
                        .tint(Color.primary)
                        .sensoryFeedback(trigger: store.selectedPetID) { _, new in new == pet.id ? .boubaSelect : nil }
                    }
                    Button("Join a pet with a code", systemImage: "link") { showJoin = true }
                } header: {
                    header("Pets")
                }

                if store.isOwner {
                    Section {
                        LabeledContent("Bouba Free", value: "1 free sitter left")
                        Button("Refer a friend, get a free sitter", systemImage: "gift.fill") {}
                    } header: {
                        header("Plan")
                    } footer: {
                        footer("You and co-owners are always free. Temporary sitters are part of Bouba Plus.")
                    }
                }

                Section {
                    Button("Replay onboarding", systemImage: "arrow.counterclockwise") {
                        store.hasOnboarded = false
                    }
                    Button(role: .destructive) {
                        store.role = .owner
                        store.hasOnboarded = false
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(Color.red)
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

    private func header(_ text: String) -> some View {
        Text(text).formHeaderStyle()
    }

    private func footer(_ text: String) -> some View {
        Text(text).formFooterStyle()
    }
}
