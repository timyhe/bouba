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
            padded.background(Color.staticCardFill, in: shape)
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
    /// The tap's haptic. Pass nil when the result decides the haptic instead (success or error).
    var haptic: SensoryFeedback? = .boubaPrimary
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
            .font(.bouba(.title3))
            .foregroundStyle(Color.onInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .tint(Color.ink)
        .controlSize(.large)
        .sensoryFeedback(trigger: taps) { _, _ in haptic }
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
    var tint: Color = .boubaOrange
    /// Text and icon color once selected: a darker shade of the tint so it stays readable.
    var selectedText: Color = .boubaOrangeText
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol) }
                Text(label)
            }
            .font(.bouba(.subhead, .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? selectedText : Color.primary)
            .background(isSelected ? AnyShapeStyle(tint.opacity(0.14)) : AnyShapeStyle(Color.fieldFill), in: Capsule())
            .overlay { if isSelected { Capsule().strokeBorder(tint, lineWidth: 1.5) } }
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.boubaSelect, trigger: isSelected)
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
        .font(.bouba(.footnote, .semibold))
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
            .font(.bouba(.caption))
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
            Text(title).font(.bouba(.title2))
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
                Text(title).font(.bouba(.title3))
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
                Text(label).font(.boubaSecondary(.subhead)).foregroundStyle(Color.textSecondary)
                Text(secret && !revealed ? String(repeating: "•", count: max(value.count, 4)) : value)
                    .font(.bouba(.callout, .semibold))
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
                .copiedFeedback($copied)
            }
    }
}

// MARK: - Flow layout for chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    /// Breaks subviews into rows that fit `maxWidth`. Sizing and placement both use this, so
    /// they always agree on where rows break (they used to differ by sub-point rounding, which
    /// pushed the last item onto a row the container hadn't made room for).
    private func rows(_ subviews: Subviews, maxWidth: CGFloat) -> [[(index: Int, size: CGSize)]] {
        var rows: [[(index: Int, size: CGSize)]] = [[]]
        var x: CGFloat = 0
        for (i, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            // A half-point of slack absorbs pixel rounding of the bounds.
            if x > 0, x + size.width > maxWidth + 0.5 {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append((i, size))
            x += size.width + spacing
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(subviews, maxWidth: proposal.width ?? .infinity)
        let width = rows.map { row in
            row.reduce(0) { $0 + $1.size.width } + spacing * CGFloat(max(row.count - 1, 0))
        }.max() ?? 0
        let heights = rows.map { $0.map(\.size.height).max() ?? 0 }
        let height = heights.reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Wrap against the same width that sizing used, not the (narrower) width it returned.
        var y = bounds.minY
        for row in rows(subviews, maxWidth: proposal.width ?? bounds.width) {
            var x = bounds.minX
            let rowHeight = row.map(\.size.height).max() ?? 0
            for item in row {
                subviews[item.index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += rowHeight + spacing
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
/// In dark mode a black shadow and ring vanish against the black page, so the ring turns
/// white (like the system's dark-mode hairlines) and the shadow deepens to read on gray surfaces.
struct LayeredShadow<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let dark = colorScheme == .dark
        content.background {
            ZStack {
                shape.fill(.black.opacity(dark ? 0.4 : 0.04)).offset(y: 2).blur(radius: 2)
                shape.inset(by: 1).fill(.black.opacity(dark ? 0.5 : 0.06)).offset(y: 1).blur(radius: 1)
                // 1px spread with no blur: a hairline ring just outside the edge.
                shape.inset(by: -0.5).stroke(dark ? Color.white.opacity(0.14) : Color.black.opacity(0.06), lineWidth: 1)
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

// MARK: - Form sections

extension View {
    /// Section header text in forms and lists: Allo instead of the system's small gray caps.
    func formHeaderStyle() -> some View {
        font(.bouba(.callout, .semibold)).textCase(nil)
    }

    /// Section footer text in forms and lists.
    func formFooterStyle() -> some View {
        font(.boubaSecondary(.footnote))
    }
}

/// A form section header set in Allo.
struct FormHeader: View {
    let title: String
    var body: some View { Text(title).formHeaderStyle() }
}

extension Section where Parent == FormHeader, Footer == EmptyView, Content: View {
    /// A form section with a plain-string header set in Allo.
    init(styledHeader title: String, @ViewBuilder content: () -> Content) {
        self.init(content: content, header: { FormHeader(title: title) })
    }
}

extension View {
    /// For copy buttons: a soft tap when copying, then the checkmark turns back into the
    /// copy icon after a moment so the button can be used again.
    func copiedFeedback(_ copied: Binding<Bool>) -> some View {
        self
            .sensoryFeedback(trigger: copied.wrappedValue) { _, new in new ? .boubaTick : nil }
            .task(id: copied.wrappedValue) {
                guard copied.wrappedValue else { return }
                guard (try? await Task.sleep(for: .seconds(1.5))) != nil else { return }
                withAnimation { copied.wrappedValue = false }
            }
    }
}

// MARK: - Haptics

/// The app's haptic tiers. Every one is a soft impact; weight says how much the action matters.
/// Text links, Back/Skip/Cancel, menus, typing and anything that opens a system sheet get none.
extension SensoryFeedback {
    /// The primary button: moving forward, committing, finishing.
    static let boubaPrimary = SensoryFeedback.impact(flexibility: .soft, intensity: 1.0)
    /// Something didn't go through, like a bad invite code.
    static let boubaError = SensoryFeedback.impact(flexibility: .soft, intensity: 0.85)
    /// Picking an option: a role, species, size, chip or toggle.
    static let boubaSelect = SensoryFeedback.impact(flexibility: .soft, intensity: 0.6)
    /// Small adjustments and confirmations: steppers, swatches, calendar days, copying.
    static let boubaTick = SensoryFeedback.impact(flexibility: .soft, intensity: 0.4)
}
