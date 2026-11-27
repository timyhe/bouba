import SwiftUI

enum OnboardingRoute: Hashable {
    case phone, verify(String), choice, createPet, join
}

struct OnboardingBackground: View {
    var body: some View {
        Color(.systemBackground).ignoresSafeArea()
    }
}

// MARK: - Welcome / sign in

struct WelcomeView: View {
    @State private var path: [OnboardingRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Spacer()
                OrbitHero()
                Spacer()

                // Title and tagline sit right on top of the button.
                VStack(spacing: 8) {
                    Text("Bouba").font(.allo(46, .bold))
                    Text("Everything your pet needs,\nin good hands.")
                        .font(.alloSubtext(20))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)

                VStack(spacing: 12) {
                    PrimaryButton(title: "Continue") {
                        path.append(.phone)
                    }

                    Text("By continuing you agree to Bouba's Terms & Privacy Policy.")
                        .font(.alloSubtext(14))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .background(OnboardingBackground())
            .navigationDestination(for: OnboardingRoute.self) { route in
                switch route {
                case .phone: PhoneEntryView(path: $path)
                case .verify(let phone): VerifyCodeView(phone: phone, path: $path)
                case .choice: RoleChoiceView(path: $path)
                case .createPet: CreatePetFlow()
                case .join: JoinInviteView(onFinish: {})
                }
            }
        }
    }

}

// MARK: - Splash hero: icon circles orbiting the dog

struct OrbitHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Orbiter {
        let symbol: String
        let color: Color
        let size: CGFloat
        let radius: CGFloat
        let phase: Double   // starting angle, radians
        let speed: Double   // radians per second; negative runs the other way
    }

    private static let purple = Color(red: 0.56, green: 0.40, blue: 0.95)

    // Inner ring drifts one way, outer ring the other.
    private let orbiters: [Orbiter] = {
        let inner: [(String, Color)] = [
            ("cat.fill", .teal),
            ("tennisball.fill", purple),
            ("fish.fill", .blue),
            ("heart.fill", .pink),
        ]
        let outer: [(String, Color)] = [
            ("bird.fill", .yellow),
            ("pawprint.fill", .boubaOrange),
            ("hare.fill", .mint),
            ("carrot.fill", .orange),
            ("tortoise.fill", .green),
            ("drop.fill", .cyan),
            ("leaf.fill", .indigo),
        ]
        return inner.enumerated().map { i, item in
            Orbiter(symbol: item.0, color: item.1, size: 50, radius: 104,
                    phase: Double(i) / Double(inner.count) * 2 * .pi, speed: 0.22)
        } + outer.enumerated().map { i, item in
            Orbiter(symbol: item.0, color: item.1, size: 42, radius: 162,
                    phase: (Double(i) + 0.5) / Double(outer.count) * 2 * .pi, speed: -0.14)
        }
    }()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach([104.0, 162.0], id: \.self) { r in
                    Circle()
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        .frame(width: r * 2, height: r * 2)
                }

                ForEach(orbiters.indices, id: \.self) { i in
                    let o = orbiters[i]
                    let angle = o.phase + t * o.speed
                    Self.bubble(o.symbol, color: o.color, size: o.size)
                        .offset(x: cos(angle) * o.radius, y: sin(angle) * o.radius)
                }

                Self.bubble("dog.fill", color: .boubaOrange, size: 128)
            }
        }
        .frame(height: 370)
        .accessibilityHidden(true)
    }

    static func bubble(_ symbol: String, color: Color, size: CGFloat) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: size > 60 ? 4 : 3))
    }
}

// MARK: - Owner or caretaker?

struct RoleChoiceView: View {
    @Environment(AppStore.self) private var store
    @Binding var path: [OnboardingRoute]

    private enum Role { case owner, caretaker }
    @State private var role: Role?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How will you\nuse Bouba?")
                .font(.allo(34, .bold))
                .padding(.bottom, 8)

            choice(.owner, symbol: "house.fill", title: "I have a pet",
                   detail: "Set up a profile and then invite people to help.")
            choice(.caretaker, symbol: "heart.fill", title: "I'm caring for a pet",
                   detail: "Join with the invite link or code an owner sent you.")

            Spacer()

            PrimaryButton(title: "Continue") {
                switch role {
                case .owner: path.append(.createPet)
                case .caretaker: path.append(.join)
                case nil: break
                }
            }
            .disabled(role == nil)

            Button {
                store.startAsOwner()
            } label: {
                Text("Just exploring? Try a sample pet")
                    .font(.allo(15, .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderless)
        }
        .padding(24)
        .background(OnboardingBackground())
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: role)
    }

    private func choice(_ value: Role, symbol: String, title: String, detail: String) -> some View {
        let isSelected = role == value
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return Button {
            role = value
        } label: {
            // Icon, text and checkmark share one vertical center line.
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.boubaOrangeText)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.allo(19, .semibold)).foregroundStyle(.primary)
                    Text(detail).font(.alloSubtext(16)).foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                // Space is kept for the checkmark so the text doesn't reflow when it appears.
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.boubaOrangeText)
                    .opacity(isSelected ? 1 : 0)
                    .instantSelection()
            }
            .padding(16)
            .background(Color(.systemBackground), in: shape)
            .overlay {
                shape.strokeBorder(isSelected ? Color.boubaOrangeText : Color(.systemGray5),
                                   lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(shape)
        }
        .buttonStyle(CardPressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
