import SwiftUI
import UIKit

/// Invite someone (or edit an existing caretaker's access & update preferences).
struct InviteCaretakerSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Caretaker
    @State private var created = false
    @State private var confirmRemove = false
    let isNew: Bool

    private static let colors: [Color] = [.purple, .pink, .teal, .indigo, .mint, .blue]

    init(existing: Caretaker? = nil) {
        _draft = State(initialValue: existing ?? Caretaker(
            name: "", role: .temporary,
            color: InviteCaretakerSheet.colors.randomElement() ?? .purple,
            notifyOnComplete: true, isPending: true))
        isNew = existing == nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if created {
                    InviteReadyView(caretaker: draft, petName: store.pet.name, ownerName: store.ownerName) { dismiss() }
                } else {
                    form
                }
            }
            .navigationTitle(created ? "" : (isNew ? "Invite a caretaker" : draft.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !created {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", systemImage: "xmark") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isNew ? "Create link" : "Save") {
                            store.saveCaretaker(draft)
                            if isNew {
                                withAnimation { created = true }
                            } else {
                                dismiss()
                            }
                        }
                        .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private var form: some View {
        Form {
            Section("Who's helping?") {
                TextField("Their name", text: $draft.name)
                    .textContentType(.name)
            }

            Section("Role") {
                ForEach(CaretakerRole.allCases) { role in
                    Button {
                        withAnimation(.snappy) {
                            draft.role = role
                            if role == .coOwner { draft.canEditTasks = true }
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: role.symbol)
                                .font(.system(size: 20))
                                .foregroundStyle(Color.boubaOrange)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(role.label).font(.allo(16, .semibold))
                                Text(role.detail).font(.alloSubtext(15)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: draft.role == role ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(draft.role == role ? Color.boubaOrange : Color(.systemGray3))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if draft.role == .temporary {
                Section {
                    DatePicker("Starts", selection: $draft.start, displayedComponents: .date)
                    DatePicker("Ends", selection: $draft.end, in: draft.start..., displayedComponents: .date)
                    Stepper("Early access: \(draft.earlyAccessDays) day\(draft.earlyAccessDays == 1 ? "" : "s") before",
                            value: $draft.earlyAccessDays, in: 0...7)
                } header: {
                    Text("When")
                } footer: {
                    Text("They can review \(store.pet.name)'s instructions from \(draft.start.adding(days: -draft.earlyAccessDays).shortDay). Access ends automatically after \(draft.end.shortDay).")
                }
            }

            Section {
                Toggle("Notify me when tasks are done", isOn: $draft.notifyOnComplete)
                    .tint(Color.boubaOrange)
                Picker("Photo updates", selection: $draft.photoFrequency) {
                    ForEach(PhotoFrequency.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Check in & out of visits", isOn: $draft.checkInOut)
                    .tint(Color.boubaOrange)
            } header: {
                Text("Updates you'd like")
            } footer: {
                Text("We'll let \(draft.name.isEmpty ? "them" : draft.name) know what you're hoping for, so nobody has to ask.")
            }

            Section("Permissions") {
                Toggle("Can add & edit tasks", isOn: $draft.canEditTasks)
                    .tint(Color.boubaOrange)
                Toggle("Show home access details", isOn: $draft.showHomeAccess)
                    .tint(Color.boubaOrange)
            }

            if !isNew {
                Section("Invite") {
                    ShareLink(item: draft.inviteURL,
                              subject: Text("Help care for \(store.pet.name)"),
                              message: Text(inviteMessage)) {
                        Label("Share invite link again", systemImage: "square.and.arrow.up")
                    }
                    Button("Remove access", role: .destructive) { confirmRemove = true }
                }
            }
        }
        .confirmationDialog("Remove \(draft.name)'s access to \(store.pet.name)?",
                            isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove access", role: .destructive) {
                store.removeCaretaker(draft.id)
                dismiss()
            }
        }
    }

    private var inviteMessage: String {
        "Hi \(draft.name)! I'm using Bouba to share everything about caring for \(store.pet.name). Tap to join: \(draft.inviteURL.absoluteString)"
    }
}

struct InviteReadyView: View {
    let caretaker: Caretaker
    let petName: String
    let ownerName: String
    var onDone: () -> Void

    @State private var copied = false

    private var message: String {
        "Hi \(caretaker.name)! I'm using Bouba to share everything about caring for \(petName). Tap to join: \(caretaker.inviteURL.absoluteString)"
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(Color.boubaOrange.opacity(0.15)).frame(width: 140, height: 140)
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.boubaOrange)
                    .symbolEffect(.bounce, options: .nonRepeating)
            }
            VStack(spacing: 8) {
                Text("Invite ready!").font(.allo(30, .bold))
                Text("Send this link to \(caretaker.name). They'll meet \(petName) and see everything you've set up.")
                    .font(.alloSubtext(18))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("bouba.app/join/\(caretaker.inviteCode)")
                        .font(.allo(17, .semibold))
                    Text(caretaker.role == .temporary ? "\(caretaker.role.label) · \(caretaker.accessSummary)" : caretaker.role.label)
                        .font(.alloSubtext(15))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = caretaker.inviteURL.absoluteString
                    withAnimation { copied = true }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.glass)
                .sensoryFeedback(.success, trigger: copied)
            }
            .fieldStyle()

            Spacer()

            VStack(spacing: 12) {
                ShareLink(item: caretaker.inviteURL,
                          subject: Text("Help care for \(petName)"),
                          message: Text(message)) {
                    Label("Share invite", systemImage: "square.and.arrow.up")
                        .font(.allo(17, .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)

                Button("Done", action: onDone)
                    .font(.allo(16, .semibold))
                    .buttonStyle(.glass)
                    .controlSize(.large)
            }
        }
        .padding(24)
    }
}
