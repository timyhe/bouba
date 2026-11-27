import SwiftUI

// MARK: - Emergency

struct EmergencySheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let pet = store.pet

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white)
                            .frame(width: 58, height: 58)
                            .background(Color.red, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Emergency info").boubaFont(.title)
                            Text("If something's wrong with \(pet.name)")
                                .font(.boubaSecondary(.body))
                                .foregroundStyle(Color.textSecondary)
                        }
                    }

                    InfoCard(title: pet.vet.clinic.isEmpty ? "Vet" : pet.vet.clinic) {
                        if !pet.vet.address.isEmpty {
                            KeyValueRow(symbol: "mappin.and.ellipse", label: "Address", value: pet.vet.address, copyable: true)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: pet.vet.permission.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.onGreenTint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pet.vet.permission.label).font(.bouba(.callout, .semibold))
                                Text(pet.vet.permission.detail).font(.boubaSecondary(.callout))
                            }
                            .foregroundStyle(Color.onGreenTint)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.boubaGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        if let url = telURL(pet.vet.phone), !pet.vet.phone.isEmpty {
                            Link(destination: url) {
                                Label("Call \(pet.vet.phone)", systemImage: "phone.fill")
                                    .font(.bouba(.title3))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(Color.dangerText)
                            .controlSize(.large)
                        }
                    }

                    if !pet.contacts.isEmpty {
                        InfoCard(title: "Emergency contacts") {
                            ForEach(pet.contacts) { contact in
                                HStack(spacing: 12) {
                                    InitialsAvatar(name: contact.name, color: .boubaOrange, size: 40)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(contact.name).font(.bouba(.callout, .semibold))
                                        Text("\(contact.relation) · \(contact.phone)")
                                            .font(.boubaSecondary(.callout))
                                            .foregroundStyle(Color.textSecondary)
                                    }
                                    Spacer()
                                    if let url = telURL(contact.phone) {
                                        Link(destination: url) {
                                            Image(systemName: "phone.fill")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(Color.textSecondary)
                                                .frame(width: 44, height: 44)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.borderless)
                                        .accessibilityLabel("Call \(contact.name)")
                                    }
                                }
                            }
                        }
                    }

                    if !pet.medical.isEmpty {
                        InfoCard(title: "Medical notes") {
                            Text(pet.medical).font(.bouba(.callout))
                        }
                    }

                    if !pet.mustNotEat.isEmpty {
                        InfoCard(title: "Must not eat") {
                            FlowLayout {
                                ForEach(pet.mustNotEat, id: \.self) { Tag(text: $0, color: .dangerText, symbol: "xmark") }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Notifications

struct NotificationsSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.notifications.isEmpty {
                    ContentUnavailableView("You're all caught up", systemImage: "bell.slash")
                } else {
                    List(store.notifications) { n in
                        // Action icon and avatar side by side; the text sits under the avatar.
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: n.symbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(n.color)
                                .frame(width: 36, height: 36)
                                .background(n.color.opacity(0.14), in: Circle())
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 8) {
                                if let actor = n.actor {
                                    InitialsAvatar(name: actor, color: n.actorColor, size: 36)
                                        .accessibilityHidden(true)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(Text(n.title).font(.bouba(.callout, .semibold))) \(Text(n.date.shortAgo).font(.boubaSecondary(.callout)).foregroundStyle(Color.textTertiary))")
                                        .accessibilityLabel("\(n.title), \(n.date.relativeDay) at \(n.date.timeString)")
                                    Text(n.body).font(.boubaSecondary(.callout)).foregroundStyle(Color.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 2)
                        // No line above the first notification, right under the title.
                        .listRowSeparator(n.id == store.notifications.first?.id ? .hidden : .automatic, edges: .top)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .onAppear { store.hasUnreadNotifications = false }
        }
        .presentationDetents([.large])
    }
}
