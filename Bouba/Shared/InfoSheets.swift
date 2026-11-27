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
                            Text("Emergency info").font(.allo(26, .bold))
                            Text("If something's wrong with \(pet.name)")
                                .font(.alloSubtext(17))
                                .foregroundStyle(Color.textSecondary)
                        }
                    }

                    InfoCard(title: pet.vet.clinic.isEmpty ? "Vet" : pet.vet.clinic, symbol: "cross.case.fill", tint: .red) {
                        if !pet.vet.address.isEmpty {
                            KeyValueRow(symbol: "mappin.and.ellipse", label: "Address", value: pet.vet.address, copyable: true)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: pet.vet.permission.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.boubaGreenText)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pet.vet.permission.label).font(.allo(16, .semibold))
                                Text(pet.vet.permission.detail).font(.alloSubtext(16)).foregroundStyle(Color.textSecondary)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.boubaGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        if let url = telURL(pet.vet.phone), !pet.vet.phone.isEmpty {
                            Link(destination: url) {
                                Label("Call \(pet.vet.phone)", systemImage: "phone.fill")
                                    .font(.allo(19, .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(Color.dangerText)
                            .controlSize(.large)
                        }
                    }

                    if !pet.contacts.isEmpty {
                        InfoCard(title: "Emergency contacts", symbol: "phone.fill", tint: .red) {
                            ForEach(pet.contacts) { contact in
                                HStack(spacing: 12) {
                                    InitialsAvatar(name: contact.name, color: .boubaOrange, size: 40)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(contact.name).font(.allo(16, .semibold))
                                        Text("\(contact.relation) · \(contact.phone)")
                                            .font(.alloSubtext(16))
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
                        InfoCard(title: "Medical notes", symbol: "heart.text.square.fill", tint: .red) {
                            Text(pet.medical).font(.allo(16))
                        }
                    }

                    if !pet.mustNotEat.isEmpty {
                        InfoCard(title: "Must not eat", symbol: "nosign", tint: .red) {
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
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: n.symbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(n.color, in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(n.title).font(.allo(16, .semibold))
                                Text(n.body).font(.alloSubtext(16)).foregroundStyle(Color.textSecondary)
                                Text("\(n.date.relativeDay) · \(n.date.timeString)")
                                    .font(.alloSubtext(15))
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
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
        .presentationDetents([.medium, .large])
    }
}
