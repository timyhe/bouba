import SwiftUI
import UIKit

// MARK: - Card container
// Tappable cards are white with a layered shadow; static (non-tappable) cards are flat light gray.

struct CardStyle: ViewModifier {
    var padding: CGFloat = 16
    var radius: CGFloat = 24
    var interactive: Bool = true

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let padded = content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
        if interactive {
            padded
                .background(Color(.systemBackground), in: shape)
                .layeredShadow(shape)
        } else {
            padded.background(Color.fieldFill, in: shape)
        }
    }
}

extension View {
    /// White card with a layered shadow, for cards you can tap.
    func card(padding: CGFloat = 16, radius: CGFloat = 24) -> some View {
        modifier(CardStyle(padding: padding, radius: radius))
    }

    /// Flat light-gray card, for content that isn't tappable.
    func staticCard(padding: CGFloat = 16, radius: CGFloat = 24) -> some View {
        modifier(CardStyle(padding: padding, radius: radius, interactive: false))
    }

    /// Rounded gray input field style used across forms outside of `Form`.
    func fieldStyle() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.fieldFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            // Outermost, so a field that sets its own font keeps it.
            .font(.alloInput)
    }
}

// MARK: - Buttons

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Animate only the press itself, so a selection that changes on release snaps instead of fading.
            .animation(.spring(duration: 0.25)) { content in
                content
                    .scaleEffect(configuration.isPressed ? 0.95 : 1)
                    .opacity(configuration.isPressed ? 0.8 : 1)
            }
    }
}

/// For selection tiles: a slight shrink on press but no dim, so the new selection shows the instant you tap.
struct InstantSelectStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressScale(label: configuration.label.contentShape(Rectangle()), isPressed: configuration.isPressed)
    }
}

/// Shrinks to 0.97 while pressed. Inside a scroll view iOS reports a quick tap's press only as the finger lifts,
/// so the pressed look is held for a minimum time and quick taps still visibly shrink.
private struct PressScale<Label: View>: View {
    let label: Label
    let isPressed: Bool

    @State private var shown = false
    @State private var pressedAt = Date.distantPast
    private let minimumHold: TimeInterval = 0.12

    var body: some View {
        label
            .animation(.spring(duration: 0.25, bounce: 0)) { content in
                content.scaleEffect(shown ? 0.97 : 1)
            }
            .onChange(of: isPressed) { _, pressed in
                if pressed {
                    pressedAt = .now
                    shown = true
                } else {
                    let remaining = minimumHold - Date.now.timeIntervalSince(pressedAt)
                    guard remaining > 0 else { shown = false; return }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(remaining))
                        if !isPressed { shown = false }
                    }
                }
            }
    }
}

extension View {
    /// Checkbox and selection marks flip instantly: no cross-fade, even inside an animated change.
    func instantSelection() -> some View {
        contentTransition(.identity)
            .transaction { $0.animation = nil }
    }
}

/// For tappable cards: shrinks slightly while pressed.
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressScale(label: configuration.label, isPressed: configuration.isPressed)
    }
}

/// A quick scale bump when something becomes selected; deselected items just snap off.
struct SelectionPop: ViewModifier {
    let isSelected: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 1.0, trigger: isSelected) { view, scale in
            view.scaleEffect(isSelected && !reduceMotion ? scale : 1)
        } keyframes: { _ in
            // Cubic keyframes end exactly on their value; a spring's last keyframe can stop short of 1.0.
            CubicKeyframe(1.07, duration: 0.08)
            CubicKeyframe(0.99, duration: 0.08)
            CubicKeyframe(1.0, duration: 0.08)
        }
    }
}

extension View {
    func selectionPop(_ isSelected: Bool) -> some View { modifier(SelectionPop(isSelected: isSelected)) }
}

/// Full-width primary action using native Liquid Glass.
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    /// Shows a spinner beside the title. Pair it with `.disabled` so the button can't be tapped twice.
    var isLoading = false
    var action: () -> Void

    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    // Small and gray to match the disabled label beside it.
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color(.systemGray))
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.allo(19, .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .tint(Color.boubaOrangeFill)
        .controlSize(.large)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: taps)
    }
}

// MARK: - Icons & avatars

struct IconTile: View {
    let kind: TaskKind
    var size: CGFloat = 52

    var body: some View {
        Image(systemName: kind.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(kind.color, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

struct PetAvatar: View {
    let pet: Pet
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            if let photo = pet.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                pet.color
                Image(systemName: pet.species.symbol)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: size > 60 ? 3 : 1.5))
    }
}

struct InitialsAvatar: View {
    let name: String
    var color: Color = .boubaOrange
    var size: CGFloat = 40
    /// A bundled portrait to show instead of the initial. Defaults to "avatar-<name>" when one is bundled.
    var photo: String? = nil

    private var image: UIImage? {
        UIImage(named: photo ?? "avatar-\(name.lowercased())")
    }

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .accessibilityLabel(name)
        } else {
            Text(String(name.prefix(1)).uppercased())
                .font(.allo(size * 0.42, .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(color, in: Circle())
        }
    }
}

// MARK: - Photos

struct PhotoView: View {
    let photo: Photo

    private static let samples: [(Color, Color, String)] = [
        (.orange, .yellow, "dog.fill"),
        (.teal, .blue, "tennisball.fill"),
        (.indigo, .purple, "moon.zzz.fill"),
        (.green, .mint, "pawprint.fill"),
    ]

    var body: some View {
        Color.clear
            .overlay {
                if let image = photo.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    GeometryReader { geo in
                        let style = Self.samples[photo.sample % Self.samples.count]
                        ZStack {
                            style.0
                            Image(systemName: style.2)
                                .font(.system(size: min(geo.size.width, geo.size.height) * 0.34, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                }
            }
            .clipped()
    }
}

// MARK: - Chips & tags

struct Chip: View {
    let label: String
    var symbol: String? = nil
    var isSelected: Bool
    var tint: Color = .boubaOrangeFill
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol) }
                Text(label)
            }
            .font(.allo(15, .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(Color.fieldFill), in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: isSelected)
    }
}

struct Tag: View {
    let text: String
    var color: Color = .dangerText
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .bold)) }
            Text(text)
        }
        .font(.allo(14, .medium))
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(color.opacity(0.12), in: Capsule())
    }
}

struct StatusBadge: View {
    let status: CaretakerStatus
    var body: some View {
        Text(status.label)
            .font(.allo(12, .semibold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(status.color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Section header

struct SectionHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title).font(.allo(21, .bold))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            trailing
        }
        .padding(.top, 6)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

// MARK: - Info card & rows

/// Shared by the card title's colored tile and the gray row icons below it,
/// so every line of text in an info card starts at the same edge.
enum InfoCardMetrics {
    static let iconColumn: CGFloat = 30
    static let gap: CGFloat = 10
    static var textInset: CGFloat { iconColumn + gap }
}

struct InfoCard<Content: View, Accessory: View>: View {
    let title: String
    let symbol: String
    var tint: Color = .boubaOrange
    @ViewBuilder var content: Content
    /// Optional control pinned to the trailing edge of the header.
    @ViewBuilder var accessory: Accessory

    init(title: String, symbol: String, tint: Color = .boubaOrange,
         @ViewBuilder content: () -> Content,
         @ViewBuilder accessory: () -> Accessory) {
        self.title = title; self.symbol = symbol; self.tint = tint
        self.content = content(); self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: InfoCardMetrics.gap) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: InfoCardMetrics.iconColumn, height: InfoCardMetrics.iconColumn)
                    .background(tint, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(title).font(.allo(18, .semibold))
                Spacer(minLength: 0)
                accessory
            }
            content
        }
        .staticCard(padding: 18)
    }
}

extension InfoCard where Accessory == EmptyView {
    init(title: String, symbol: String, tint: Color = .boubaOrange, @ViewBuilder content: () -> Content) {
        self.init(title: title, symbol: symbol, tint: tint, content: content, accessory: { EmptyView() })
    }
}

struct KeyValueRow: View {
    let symbol: String
    let label: String
    let value: String
    var secret = false
    var copyable = false

    @State private var revealed = false
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: InfoCardMetrics.gap) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
                .frame(width: InfoCardMetrics.iconColumn, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.alloSubtext(15)).foregroundStyle(Color.textSecondary)
                Text(secret && !revealed ? String(repeating: "•", count: max(value.count, 4)) : value)
                    .font(.allo(16, .medium))
                    .textSelection(.enabled)
            }
            Spacer(minLength: 8)
            // Show/hide and copy sit side by side with no extra spacing; each keeps a 44pt-tall target.
            HStack(spacing: 0) { actions }
        }
    }

    @ViewBuilder private var actions: some View {
            if secret {
                // Shows the action: the open eye reveals, the crossed-out eye hides again.
                Button { withAnimation { revealed.toggle() } } label: {
                    Image(systemName: revealed ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 36, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(revealed ? "Hide \(label)" : "Show \(label)")
                .foregroundStyle(Color.textSecondary)
            }
            if copyable {
                Button {
                    UIPasteboard.general.string = value
                    withAnimation { copied = true }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(copied ? "Copied \(label)" : "Copy \(label)")
                .foregroundStyle(Color.textSecondary)
                .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: copied)
            }
    }
}

// MARK: - Flow layout for chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Phone helper

func telURL(_ phone: String) -> URL? {
    URL(string: "tel:\(phone.filter(\.isNumber))")
}

// MARK: - Layered shadow

/// SwiftUI version of the CSS shadow
/// `0 0 0 1px #0000000f, 0 1px 2px -1px #0000000f, 0 2px 4px 0 #0000000a`.
/// CSS blur is twice the Gaussian sigma, so blur 4px → radius 2; a negative spread insets the shape.
struct LayeredShadow<S: InsettableShape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        content.background {
            ZStack {
                shape.fill(.black.opacity(0.04)).offset(y: 2).blur(radius: 2)
                shape.inset(by: 1).fill(.black.opacity(0.06)).offset(y: 1).blur(radius: 1)
                // 1px spread with no blur: a hairline ring just outside the edge.
                shape.inset(by: -0.5).stroke(.black.opacity(0.06), lineWidth: 1)
            }
        }
    }
}

extension View {
    func layeredShadow<S: InsettableShape>(_ shape: S) -> some View {
        modifier(LayeredShadow(shape: shape))
    }
}

// MARK: - Sheets

extension View {
    /// Sheets get a solid background instead of the system's translucent glass.
    func solidSheet() -> some View {
        presentationBackground(Color(.systemBackground))
    }
}
