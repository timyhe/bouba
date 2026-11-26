import SwiftUI

// MARK: - Phone number

struct PhoneEntryView: View {
    @Binding var path: [OnboardingRoute]

    @State private var text = ""
    @FocusState private var focused: Bool

    private var digits: String { String(text.filter(\.isNumber).prefix(10)) }
    private var isValid: Bool { digits.count == 10 }

    /// Formats up to 10 digits as (555) 555-5555.
    static func format(_ digits: String) -> String {
        let d = Array(digits.prefix(10))
        switch d.count {
        case 0: return ""
        case 1...3: return "(\(String(d))"
        case 4...6: return "(\(String(d[0..<3]))) \(String(d[3...]))"
        default: return "(\(String(d[0..<3]))) \(String(d[3..<6]))-\(String(d[6...]))"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What's your number?").font(.allo(32, .bold))
                Text("We'll text you a code to sign in. No passwords to remember.")
                    .font(.alloSubtext(18))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Text("US +1")
                    .font(.allo(20, .semibold))
                    .fieldStyle()

                // The field holds raw digits (rewriting it while typing drops keystrokes);
                // the formatted number is drawn on top.
                ZStack(alignment: .leading) {
                    TextField("", text: $text)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .focused($focused)
                        .foregroundStyle(.clear)
                        .tint(.clear)
                        .onChange(of: text) { _, newValue in
                            // Only rewrite on overflow, so normal typing is never interrupted.
                            let clean = String(newValue.filter(\.isNumber).prefix(10))
                            if newValue.count > 10 || clean.count != newValue.count { text = clean }
                        }
                    HStack(spacing: 1) {
                        Text(digits.isEmpty ? "" : Self.format(digits))
                        if focused {
                            Capsule().fill(Color.boubaOrange).frame(width: 2, height: 24)
                                .phaseAnimator([1.0, 0.0]) { view, phase in view.opacity(phase) }
                                    animation: { _ in .easeInOut(duration: 0.5) }
                        }
                        if digits.isEmpty {
                            Text("(555) 555-5555").foregroundStyle(.tertiary)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .font(.allo(20, .semibold))
                .contentShape(Rectangle())
                .onTapGesture { focused = true }
                .fieldStyle()
            }

            Spacer()

            PrimaryButton(title: "Send code") {
                path.append(.verify("+1 \(Self.format(digits))"))
            }
            .disabled(!isValid)
        }
        .padding(24)
        .background(OnboardingBackground())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focused = true }
    }
}

// MARK: - Verification code

struct VerifyCodeView: View {
    let phone: String
    @Binding var path: [OnboardingRoute]

    @State private var code = ""
    @State private var verifying = false
    @State private var secondsLeft = 30
    @State private var resent = false
    @FocusState private var focused: Bool

    private let length = 6
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Enter the code").font(.allo(32, .bold))
                HStack(spacing: 4) {
                    Text("Sent to \(phone).")
                    Button("Edit") { path.removeLast() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.boubaOrange)
                }
                .font(.alloSubtext(18))
                .foregroundStyle(.secondary)
            }

            ZStack {
                // Hidden field drives the boxes and supports SMS autofill.
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($focused)
                    .opacity(0.01)
                    .onChange(of: code) { _, newValue in
                        let clean = String(newValue.filter(\.isNumber).prefix(length))
                        if clean != newValue { code = clean }
                        if clean.count == length { verify() }
                    }

                HStack(spacing: 10) {
                    ForEach(0..<length, id: \.self) { index in
                        digitBox(index)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { focused = true }
            }

            Group {
                if verifying {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Verifying…")
                    }
                    .foregroundStyle(.secondary)
                } else if secondsLeft > 0 {
                    Text(resent ? "New code sent. Resend again in \(secondsLeft)s" : "Resend code in \(secondsLeft)s")
                        .foregroundStyle(.secondary)
                } else {
                    Button("Resend code") {
                        resent = true
                        secondsLeft = 30
                        code = ""
                    }
                    .font(.allo(15, .semibold))
                }
            }
            .font(.alloSubtext(17))

            Label("Prototype: any 6 digits will work.", systemImage: "info.circle")
                .font(.alloSubtext(16))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding(24)
        .background(OnboardingBackground())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focused = true }
        .onReceive(timer) { _ in
            if secondsLeft > 0 { secondsLeft -= 1 }
        }
        .sensoryFeedback(.success, trigger: verifying) { _, new in new }
    }

    private func digitBox(_ index: Int) -> some View {
        let chars = Array(code)
        let char = index < chars.count ? String(chars[index]) : ""
        let isCurrent = focused && index == min(chars.count, length - 1) && !verifying
        return Text(char)
            .font(.allo(28, .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(Color.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isCurrent ? Color.boubaOrange : Color.clear, lineWidth: 2)
            )
            .animation(.snappy(duration: 0.15), value: code)
    }

    private func verify() {
        guard !verifying else { return }
        verifying = true
        focused = false
        Task {
            try? await Task.sleep(for: .seconds(0.8))
            verifying = false
            path.append(.choice)
        }
    }
}
