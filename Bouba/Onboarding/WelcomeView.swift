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
                hero
                Spacer()

                VStack(spacing: 12) {
                    PrimaryButton(title: "Continue") {
                        path.append(.phone)
                    }

                    Text("By continuing you agree to Bouba's Terms & Privacy Policy.")
                        .font(.alloSubtext(14))
                        .foregroundStyle(.secondary)
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

    private var hero: some View {
        VStack(spacing: 22) {
            ZStack {
                bubble("cat.fill", color: .teal, size: 84).offset(x: -78, y: 26)
                bubble("tennisball.fill", color: Color(red: 0.56, green: 0.40, blue: 0.95), size: 60).offset(x: 84, y: -34)
                bubble("dog.fill", color: .boubaOrange, size: 128)
            }
            .frame(height: 160)

            VStack(spacing: 8) {
                Text("Bouba").font(.allo(54, .bold))
                Text("Everything your pet's people need,\nall in one place.")
                    .font(.alloSubtext(20))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func bubble(_ symbol: String, color: Color, size: CGFloat) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 4))
    }
}

// MARK: - Owner or caretaker?

struct RoleChoiceView: View {
    @Environment(AppStore.self) private var store
    @Binding var path: [OnboardingRoute]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How will you\nuse Bouba?")
                .font(.allo(34, .bold))
                .padding(.bottom, 8)

            choice(symbol: "house.fill", title: "I have a pet",
                   detail: "Set up a profile, routine and instructions, then invite people to help.") {
                path.append(.createPet)
            }
            choice(symbol: "heart.fill", title: "I'm caring for a pet",
                   detail: "Join with the invite link or code an owner sent you.") {
                path.append(.join)
            }

            Spacer()

            Button {
                store.startAsOwner()
            } label: {
                Text("Just exploring? Try a sample pet")
                    .font(.allo(15, .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .padding(.bottom, 8)
        }
        .padding(24)
        .background(OnboardingBackground())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func choice(symbol: String, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.boubaOrange)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.allo(19, .semibold)).foregroundStyle(.primary)
                    Text(detail).font(.alloSubtext(16)).foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .card(padding: 16)
        }
        .buttonStyle(PressableStyle())
    }
}
