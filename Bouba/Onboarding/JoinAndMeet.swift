import SwiftUI
import UIKit

// MARK: - Join with invite

struct JoinInviteView: View {
    var onFinish: () -> Void

    @State private var code = ""
    @State private var showMeet = false
    @State private var invalid = false

    private var normalizedCode: String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.split(separator: "/").last.map(String.init) ?? trimmed).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Join with an invite").font(.allo(32, .bold))
                Text("Paste the link the owner sent you, or type the 6-character code.")
                    .font(.alloSubtext(18))
                    .foregroundStyle(.secondary)
            }

            TextField("bouba.app/join/…", text: $code)
                .font(.allo(20, .semibold))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .fieldStyle()
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(invalid ? Color.red : Color.clear, lineWidth: 1.5)
                )

            HStack(spacing: 10) {
                Button("Paste", systemImage: "doc.on.clipboard") {
                    code = UIPasteboard.general.string ?? ""
                }
                .font(.allo(15, .semibold))
                .buttonStyle(.glass)
                .tint(Color.primary)

                Button("Use demo code") { code = "bouba.app/join/FX7K2Q" }
                    .font(.allo(15, .semibold))
                    .buttonStyle(.glass)
                    .tint(Color.primary)
            }

            if invalid {
                Text("That code doesn't look right. Codes are 6 letters and numbers.")
                    .font(.allo(14))
                    .foregroundStyle(.red)
            }

            Spacer()

            PrimaryButton(title: "Join") {
                if normalizedCode.count == 6 {
                    invalid = false
                    showMeet = true
                } else {
                    withAnimation { invalid = true }
                }
            }
            .disabled(code.isEmpty)
            .sensoryFeedback(.error, trigger: invalid)
        }
        .padding(24)
        .background(OnboardingBackground())
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showMeet) {
            MeetThePetView(onFinish: onFinish)
                .navigationBarBackButtonHidden()
        }
    }
}

// MARK: - Meet the pet (swipe-through intro for new caretakers)

struct MeetThePetView: View {
    @Environment(AppStore.self) private var store
    var onFinish: () -> Void

    @State private var page = 0
    private let pageCount = 5

    var body: some View {
        // The invite in this prototype always points at the sample pet.
        let pet = store.pets[0]

        VStack(spacing: 0) {
            TabView(selection: $page) {
                introCard(pet).tag(0)
                routineCard(pet).tag(1)
                mustKnowCard(pet).tag(2)
                homeCard(pet).tag(3)
                emergencyCard(pet).tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            PrimaryButton(title: page == pageCount - 1 ? "Start caring for \(pet.name)" : "Next") {
                if page < pageCount - 1 {
                    withAnimation { page += 1 }
                } else {
                    store.joinAsCaretaker()
                    onFinish()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .background(OnboardingBackground())
        .sensoryFeedback(.selection, trigger: page)
    }

    private func introCard(_ pet: Pet) -> some View {
        MeetCard(eyebrow: "Meet \(pet.name)", title: "Hi, I'm \(pet.name)!") {
            HStack {
                Spacer()
                PetAvatar(pet: pet, size: 150)
                Spacer()
            }
            .padding(.vertical, 8)
            Text(pet.subtitle)
                .font(.allo(17, .semibold))
                .frame(maxWidth: .infinity)
            if let personality = pet.notes.first {
                Text(personality.body)
                    .font(.alloSubtext(19))
                    .foregroundStyle(.secondary)
            }
            Text("\(store.ownerName) invited you to help care for \(pet.name). Here's what you need to know.")
                .font(.alloSubtext(17))
                .foregroundStyle(.secondary)
        }
    }

    private func routineCard(_ pet: Pet) -> some View {
        MeetCard(eyebrow: "My day", title: "Here's my routine") {
            ForEach(pet.tasks.sorted { $0.minutesOfDay < $1.minutesOfDay }.prefix(7)) { task in
                HStack(spacing: 12) {
                    IconTile(kind: task.kind, size: 36)
                    Text(task.title).font(.allo(16, .semibold))
                    Spacer()
                    Text(task.timeString).font(.alloSubtext(17)).foregroundStyle(.secondary)
                }
            }
            Text("You'll get reminders and can check things off as you go.")
                .font(.alloSubtext(16))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private func mustKnowCard(_ pet: Pet) -> some View {
        MeetCard(eyebrow: "Please don't forget", title: "The important stuff") {
            ForEach(pet.tasks.filter(\.isTimeSensitive)) { task in
                HStack(alignment: .top, spacing: 12) {
                    IconTile(kind: task.kind, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(task.title) · \(task.timeString)").font(.allo(16, .semibold))
                        if !task.instructions.isEmpty {
                            Text(task.instructions).font(.alloSubtext(16)).foregroundStyle(.secondary).lineLimit(3)
                        }
                    }
                }
            }
            if !pet.mustNotEat.isEmpty {
                Text("Never feed me").font(.allo(16, .semibold)).padding(.top, 6)
                FlowLayout {
                    ForEach(pet.mustNotEat, id: \.self) { Tag(text: $0, color: .red, symbol: "xmark") }
                }
            }
        }
    }

    private func homeCard(_ pet: Pet) -> some View {
        MeetCard(eyebrow: "Getting in", title: "Where I live") {
            KeyValueRow(symbol: "mappin.and.ellipse", label: "Address", value: pet.home.address, copyable: true)
            KeyValueRow(symbol: "door.left.hand.closed", label: "Entry", value: pet.home.entry)
            KeyValueRow(symbol: "lock.fill", label: "Lockbox code", value: pet.home.code, secret: true)
            if !pet.home.wifiName.isEmpty {
                KeyValueRow(symbol: "wifi", label: "Wi-Fi · \(pet.home.wifiName)", value: pet.home.wifiPassword, secret: true, copyable: true)
            }
        }
    }

    private func emergencyCard(_ pet: Pet) -> some View {
        MeetCard(eyebrow: "Just in case", title: "If something's wrong") {
            KeyValueRow(symbol: "stethoscope", label: "Vet", value: "\(pet.vet.clinic)\n\(pet.vet.phone)")
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: pet.vet.permission.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.boubaGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pet.vet.permission.label).font(.allo(16, .semibold))
                    Text(pet.vet.permission.detail).font(.alloSubtext(16)).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.boubaGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Label { Text("Tap \(Image(systemName: "exclamationmark.triangle")) on the Activity screen anytime for this info.") } icon: { Image(systemName: "info.circle") }
                .font(.alloSubtext(16))
                .foregroundStyle(.secondary)
        }
    }
}

private struct MeetCard<Content: View>: View {
    let eyebrow: String
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(eyebrow.uppercased())
                    .font(.allo(13, .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Color.boubaOrange)
                Text(title).font(.allo(30, .bold))
                content
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).strokeBorder(Color.cardStroke, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 48)
    }
}
