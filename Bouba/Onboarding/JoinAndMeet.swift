import SwiftUI
import UIKit

// MARK: - Join with invite

struct JoinInviteView: View {
    @Environment(AppStore.self) private var store
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
                    .foregroundStyle(Color.textSecondary)
            }

            TextField("bouba.app/join/…", text: $code)
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
                Text("Enter the 6-character code from your invite, like FX7K2Q.")
                    .font(.allo(14))
                    .foregroundStyle(Color.dangerText)
            }

            Spacer()

            PrimaryButton(title: "Join") {
                if normalizedCode.count == 6 {
                    invalid = false
                    // During onboarding the intro opens as a modal from the root; joining
                    // another pet later pushes it inside the join sheet.
                    if store.hasOnboarded { showMeet = true } else { store.showingMeet = true }
                } else {
                    withAnimation { invalid = true }
                }
            }
            .disabled(code.isEmpty)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.8), trigger: invalid)
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

// MARK: - Meet the pet (a stack of cards new caretakers flip through)

struct MeetThePetView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onFinish: () -> Void

    @State private var page = 0
    @State private var drag: CGFloat = 0
    /// True while the drag is far enough to flip; the haptic fires as it turns on.
    @State private var pastThreshold = false

    private let pageCount = 5
    private let threshold: CGFloat = 90
    private let flip = Animation.spring(duration: 0.4, bounce: 0)

    var body: some View {
        // The invite in this prototype always points at the sample pet.
        let pet = store.pets[0]

        VStack(spacing: 0) {
            // An invisible copy of every card sets the stack's height to the tallest one;
            // the real cards are laid over it.
            ZStack {
                ForEach(0..<pageCount, id: \.self) { cardContent($0, pet: pet) }
            }
            .environment(\.meetCardMeasuring, true)
            .hidden()
            .accessibilityHidden(true)
            .overlay {
                ZStack {
                    // Only the cards near the top of the stack are drawn.
                    ForEach(max(page - 1, 0)..<min(page + 3, pageCount), id: \.self) { index in
                        card(index, pet: pet)
                            .zIndex(Double(pageCount - index))
                    }
                }
            }
            .padding(.horizontal, 32)
            // The two cards peeking below add 28pt; lift by half so the whole stack sits centered.
            .offset(y: -14)
            .frame(maxHeight: .infinity)

            PrimaryButton(title: page == pageCount - 1 ? "Start caring for \(pet.name)" : "Next") {
                if page < pageCount - 1 {
                    withAnimation(flip) { page += 1 }
                } else {
                    store.joinAsCaretaker()
                    onFinish()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .background(OnboardingBackground())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .close) { dismiss() }
            }
            ToolbarItem(placement: .principal) {
                Text("Meet \(pet.name)").font(.allo(17, .semibold))
            }
        }
        .sensoryFeedback(trigger: pastThreshold) { _, crossed in crossed ? .impact(flexibility: .soft, intensity: 0.7) : nil }
    }

    // MARK: Stack

    @ViewBuilder
    private func card(_ index: Int, pet: Pet) -> some View {
        let depth = CGFloat(index - page)
        let isTop = index == page
        let isGone = index < page

        cardContent(index, pet: pet)
        // Cards underneath sit a little smaller and peek out below the top one.
        .scaleEffect(isGone || isTop ? 1 : 1 - 0.05 * depth, anchor: .bottom)
        .offset(y: isGone || isTop ? 0 : 14 * depth)
        .opacity(depth > 2 ? 0 : 1)
        // The top card follows the finger; flipped cards wait off to the left.
        .offset(x: isTop ? drag : (isGone && !reduceMotion ? -600 : 0))
        .rotationEffect(.degrees(isTop ? Double(drag / 22) : (isGone && !reduceMotion ? -18 : 0)), anchor: .bottom)
        .opacity(isGone ? 0 : 1)
        .allowsHitTesting(isTop)
        .accessibilityHidden(!isTop)
        .simultaneousGesture(isTop ? dragGesture : nil)
        .accessibilityAction(named: "Previous card") {
            guard page > 0 else { return }
            withAnimation(flip) { page -= 1 }
        }
    }

    @ViewBuilder
    private func cardContent(_ index: Int, pet: Pet) -> some View {
        switch index {
        case 0: introCard(pet)
        case 1: routineCard(pet)
        case 2: mustKnowCard(pet)
        case 3: homeCard(pet)
        default: emergencyCard(pet)
        }
    }

    /// Swipe left for the next card, right to go back one.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) || drag != 0 else { return }
                let dx = value.translation.width
                let canGo = dx < 0 ? page < pageCount - 1 : page > 0
                // Rubber-band when there's nothing to flip to.
                drag = canGo ? dx : dx * 0.25
                pastThreshold = canGo && abs(dx) > threshold
            }
            .onEnded { value in
                let dx = value.predictedEndTranslation.width
                withAnimation(flip) {
                    if pastThreshold || (abs(dx) > threshold * 2 && abs(drag) > threshold / 2) {
                        if dx < 0, page < pageCount - 1 { page += 1 }
                        else if dx > 0, page > 0 { page -= 1 }
                    }
                    drag = 0
                }
                pastThreshold = false
            }
    }

    // MARK: Cards

    private func introCard(_ pet: Pet) -> some View {
        MeetCard(title: "Hi, I'm \(pet.name)!") {
            PetAvatar(pet: pet, size: 120)
                .padding(.vertical, 4)
            Text(pet.subtitle)
                .font(.allo(17, .semibold))
            if let personality = pet.notes.first {
                Text(personality.body)
                    .font(.alloSubtext(17))
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private func routineCard(_ pet: Pet) -> some View {
        MeetCard(title: "Here's my routine") {
            ForEach(pet.tasks.sorted { $0.minutesOfDay < $1.minutesOfDay }.prefix(7)) { task in
                HStack(spacing: 12) {
                    IconTile(kind: task.kind, size: 32)
                    Text(task.title).font(.allo(15, .semibold)).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(task.timeString).font(.alloSubtext(15)).foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    private func mustKnowCard(_ pet: Pet) -> some View {
        MeetCard(title: "The important stuff") {
            ForEach(pet.tasks.filter(\.isTimeSensitive)) { task in
                HStack(alignment: .top, spacing: 12) {
                    IconTile(kind: task.kind, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(task.title) · \(task.timeString)").font(.allo(15, .semibold))
                        if !task.instructions.isEmpty {
                            Text(task.instructions).font(.alloSubtext(15)).foregroundStyle(Color.textSecondary).lineLimit(3)
                        }
                    }
                }
            }
            if !pet.mustNotEat.isEmpty {
                Text("Never feed me").font(.allo(15, .semibold)).padding(.top, 4)
                FlowLayout {
                    ForEach(pet.mustNotEat, id: \.self) { Tag(text: $0, color: .dangerText, symbol: "xmark") }
                }
            }
        }
    }

    private func homeCard(_ pet: Pet) -> some View {
        MeetCard(title: "Where I live") {
            KeyValueRow(symbol: "mappin.and.ellipse", label: "Address", value: pet.home.address, copyable: true)
            KeyValueRow(symbol: "door.left.hand.closed", label: "Entry", value: pet.home.entry)
            KeyValueRow(symbol: "lock.fill", label: "Lockbox code", value: pet.home.code, secret: true)
            if !pet.home.wifiName.isEmpty {
                KeyValueRow(symbol: "wifi", label: "Wi-Fi · \(pet.home.wifiName)", value: pet.home.wifiPassword, secret: true, copyable: true)
            }
        }
    }

    private func emergencyCard(_ pet: Pet) -> some View {
        MeetCard(title: "If something's wrong") {
            KeyValueRow(symbol: "stethoscope", label: "Vet", value: "\(pet.vet.clinic)\n\(pet.vet.phone)")
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: pet.vet.permission.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.boubaGreenText)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pet.vet.permission.label).font(.allo(15, .semibold))
                    Text(pet.vet.permission.detail).font(.alloSubtext(15)).foregroundStyle(Color.textSecondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.boubaGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

extension EnvironmentValues {
    /// Set on the invisible copy of the stack that only measures card heights.
    @Entry var meetCardMeasuring = false
}

private struct MeetCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @Environment(\.meetCardMeasuring) private var measuring

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)
        let stack = VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.allo(26, .bold))
            content
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)

        if measuring {
            stack
        } else {
            chrome(stack, shape: shape)
        }
    }

    /// Scrolls only if the card is taller than the space left on screen.
    private func chrome(_ stack: some View, shape: RoundedRectangle) -> some View {
        ScrollView { stack }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .clipShape(shape)
        .layeredShadow(shape)
    }
}
