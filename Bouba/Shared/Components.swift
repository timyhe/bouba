import SwiftUI
import UIKit

// MARK: - Card container (light gray fill, rounded, no border)

struct CardStyle: ViewModifier {
    var padding: CGFloat = 16
    var radius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardFill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func card(padding: CGFloat = 16, radius: CGFloat = 24) -> some View {
        modifier(CardStyle(padding: padding, radius: radius))
    }

    /// Rounded gray input field style used across forms outside of `Form`.
    func fieldStyle() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.fieldFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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

/// For selection tiles: no press dim or shrink, so the new selection shows the instant you tap.
struct InstantSelectStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.contentShape(Rectangle())
    }
}

/// A quick scale bump when something becomes selected; deselected items just snap off.
struct SelectionPop: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 1.0, trigger: isSelected) { view, scale in
            view.scaleEffect(isSelected ? scale : 1)
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
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.allo(17, .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .tint(Color.boubaOrange)
        .controlSize(.large)
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

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.allo(size * 0.42, .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: Circle())
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
    var tint: Color = .boubaOrange
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
        .sensoryFeedback(.impact(weight: .light), trigger: isSelected)
    }
}

struct Tag: View {
    let text: String
    var color: Color = .red
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

struct InfoCard<Content: View>: View {
    let title: String
    let symbol: String
    var tint: Color = .boubaOrange
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(tint, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(title).font(.allo(18, .semibold))
            }
            content
        }
        .card(padding: 18)
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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.alloSubtext(15)).foregroundStyle(.secondary)
                Text(secret && !revealed ? String(repeating: "•", count: max(value.count, 4)) : value)
                    .font(.allo(16, .medium))
                    .textSelection(.enabled)
            }
            Spacer(minLength: 8)
            if secret {
                Button(revealed ? "Hide" : "Show") { withAnimation { revealed.toggle() } }
                    .font(.allo(14, .semibold))
                    .buttonStyle(.borderless)
            }
            if copyable {
                Button {
                    UIPasteboard.general.string = value
                    withAnimation { copied = true }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .sensoryFeedback(.success, trigger: copied)
            }
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
