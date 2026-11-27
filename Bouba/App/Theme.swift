import SwiftUI
import UIKit
import CoreText

// MARK: - Allo font

/// Registers the bundled Allo variable font and vends it at any weight.
enum AlloFont {
    private static var postScriptName = "AlloVariable-Regular"
    private static var familyName = "Allo Variable"
    private static var cache: [String: UIFont] = [:]
    /// The text size the user picked in Settings. RootView keeps this in sync so Allo scales with Dynamic Type.
    private static var contentSize: UIContentSizeCategory = .large

    static func setContentSize(_ size: DynamicTypeSize) {
        contentSize = UIContentSizeCategory(size)
    }

    /// OpenType 'wght' axis tag.
    private static let weightAxis = 0x77676874
    /// Allo's 'ROND' axis: 0 is square, 50 the default, 100 fully round.
    private static let roundnessAxis = 0x524F4E44
    private static let roundness: CGFloat = 100

    static func register() {
        guard let url = Bundle.main.url(forResource: "AlloVariable", withExtension: "ttf") else {
            print("⚠️ AlloVariable.ttf missing from bundle — falling back to system font")
            return
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        if let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
           let first = descriptors.first {
            if let name = CTFontDescriptorCopyAttribute(first, kCTFontNameAttribute) as? String {
                postScriptName = name
            }
            if let family = CTFontDescriptorCopyAttribute(first, kCTFontFamilyNameAttribute) as? String {
                familyName = family
            }
        }
    }

    static func uiFont(size: CGFloat, weight: CGFloat) -> UIFont {
        let key = "\(size)-\(weight)-\(contentSize.rawValue)"
        if let cached = cache[key] { return cached }
        let variationKey = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: postScriptName,
            .family: familyName,
            variationKey: [weightAxis: weight, roundnessAxis: roundness],
        ])
        let base = UIFont(descriptor: descriptor, size: size)
        // Scale relative to the default (Large) size, capped at 2x so layouts stay intact.
        let font = UIFontMetrics.default.scaledFont(
            for: base,
            maximumPointSize: size * 2,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: contentSize)
        )
        cache[key] = font
        return font
    }

    static func value(for weight: Font.Weight) -> CGFloat {
        if weight == .black { return 900 }
        if weight == .heavy { return 800 }
        if weight == .bold { return 700 }
        if weight == .semibold { return 600 }
        if weight == .medium { return 530 }
        if weight == .light { return 300 }
        if weight == .thin { return 200 }
        if weight == .ultraLight { return 100 }
        // Allo's 400 reads thin on screen, so regular sits a little heavier.
        return 450
    }

    /// Navigation bar titles in Allo.
    @MainActor
    static func applyAppearance() {
        let large = uiFont(size: BoubaTextStyle.largeTitle.size, weight: 700)
        let inline = uiFont(size: 17, weight: 600)
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: large, .kern: BoubaTextStyle.largeTitle.tracking]
        UINavigationBar.appearance().titleTextAttributes = [.font: inline]
    }
}

/// The app's type scale. Every piece of text picks a role; the role sets the size,
/// and headings carry their own weight so a role is one decision, not three.
enum BoubaTextStyle {
    /// Tiny badges ("Soon", counts).
    case caption
    /// Small buttons, chips, notes.
    case footnote
    /// Secondary lines, labels, small row titles.
    case subhead
    /// Row titles and card text.
    case callout
    /// Default reading size.
    case body
    /// Section headings, card titles, primary button labels.
    case title3
    /// Screen-section headings.
    case title2
    /// Sheet and page titles.
    case title
    /// Onboarding and full-screen titles.
    case largeTitle
    /// Hero numbers and the wordmark.
    case display

    var size: CGFloat {
        switch self {
        case .caption: 12
        case .footnote: 14
        case .subhead: 15
        case .callout: 16
        case .body: 17
        case .title3: 19
        case .title2: 22
        case .title: 28
        case .largeTitle: 32
        case .display: 44
        }
    }

    /// Large headings pull in slightly (-0.015em to -0.02em) so they read as one shape; text stays at 0.
    var tracking: CGFloat {
        switch self {
        case .title: size * -0.015
        case .largeTitle, .display: size * -0.02
        default: 0
        }
    }

    var defaultWeight: Font.Weight {
        switch self {
        case .caption, .title3: .semibold
        case .title2, .title, .largeTitle, .display: .bold
        case .footnote, .subhead, .callout, .body: .regular
        }
    }
}

extension View {
    /// Sets a role's font and its tracking together. Use this for headings; `.font(.bouba(_:))` is fine for text.
    func boubaFont(_ style: BoubaTextStyle, _ weight: Font.Weight? = nil) -> some View {
        font(.bouba(style, weight)).tracking(style.tracking)
    }
}

extension Font {
    /// Allo at a role on the type scale, at the role's own weight unless one is given.
    static func bouba(_ style: BoubaTextStyle, _ weight: Font.Weight? = nil) -> Font {
        allo(style.size, weight ?? style.defaultWeight)
    }

    /// Gray secondary text: heavier than regular (470) so it holds up in gray at small sizes.
    static func boubaSecondary(_ style: BoubaTextStyle) -> Font {
        Font(AlloFont.uiFont(size: style.size, weight: 470) as CTFont)
    }

    /// Text typed into inputs, a step heavier than body text.
    static var alloInput: Font { bouba(.body, .medium) }

    /// Allo at an arbitrary size. Prefer `bouba(_:)`; this is for one-off display numerals.
    static func allo(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font(AlloFont.uiFont(size: size, weight: AlloFont.value(for: weight)) as CTFont)
    }
}

// MARK: - Colors

extension ShapeStyle where Self == Color {
    /// The original orange, kept as the Food category color. Not the accent.
    static var petOrange: Color { Color(red: 1.0, green: 0.498, blue: 0.227) }
    /// Brand orange, #F86210: bright and saturated, and the brightest that keeps 3:1 on white,
    /// so it can also mark selection (outlines, checkmarks, selected icons).
    /// Never for text or behind white text: it doesn't reach 4.5:1.
    static var boubaOrange: Color { Color(red: 248/255, green: 98/255, blue: 16/255) }
    static var boubaGreen: Color { Color(red: 0.13, green: 0.62, blue: 0.33) }

    // Two accents. Ink is for actions (buttons, focus, emphasis). Brand orange is for progress,
    // selection (outlines, checkmarks, selected chips and icons) and brand moments (avatars,
    // illustrations, the welcome hero, the unread dot).
    /// Action accent: #1F1B24 (16.9:1 on white), flipping to white in dark mode.
    /// Works as text, icon and fill alike.
    static var ink: Color { adaptive(light: (31, 27, 36), dark: (255, 255, 255)) }
    /// Text and icons placed on an `ink` fill.
    static var onInk: Color { adaptive(light: (255, 255, 255), dark: (31, 27, 36)) }
    /// Toggles stay system green: an ink track would vanish behind the white knob in dark mode.
    static var toggleTint: Color { Color(.systemGreen) }
    /// Dark brand orange for text and icons on a light orange fill, like a selected tag.
    /// 5.6:1 on white; a lighter orange in dark mode.
    static var boubaOrangeText: Color { adaptive(light: (179, 66, 0), dark: (255, 150, 85)) }
    /// Green for text and small icons.
    static var boubaGreenText: Color { adaptive(light: (27, 131, 69), dark: (48, 209, 88)) }
    /// Text on a pale green banner or capsule: 6:1 on the 10% green tint, where `boubaGreenText` only reaches 4.3:1.
    static var onGreenTint: Color { adaptive(light: (20, 105, 55), dark: (110, 220, 140)) }
    /// Red for errors and warnings.
    static var dangerText: Color { adaptive(light: (200, 30, 30), dark: (255, 105, 97)) }
    // Gray text steps evenly between ink and the background, so secondary and tertiary
    // read as two distinct levels rather than "gray" and "barely there".
    /// Secondary gray text: 5.5:1 on white, 8.3:1 on black.
    static var textSecondary: Color { adaptive(light: (104, 104, 110), dark: (162, 162, 168)) }

    /// Tertiary gray for low-priority metadata such as timestamps: 3.3:1 on white, 4.7:1 on black, so
    /// keep it to short, supporting text that never carries meaning on its own.
    static var textTertiary: Color { adaptive(light: (140, 140, 146), dark: (118, 118, 124)) }

    private static func adaptive(light: (Int, Int, Int), dark: (Int, Int, Int)) -> Color {
        func ui(_ c: (Int, Int, Int)) -> UIColor {
            UIColor(red: CGFloat(c.0)/255, green: CGFloat(c.1)/255, blue: CGFloat(c.2)/255, alpha: 1)
        }
        return Color(UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }
    /// Gray fill for inputs: text fields, photo pickers, the date calendar.
    static var fieldFill: Color { Color(.systemGray6) }
}

// MARK: - Dates

extension Date {
    var timeString: String { formatted(date: .omitted, time: .shortened) }

    var relativeDay: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return "Today" }
        if cal.isDateInYesterday(self) { return "Yesterday" }
        if cal.isDateInTomorrow(self) { return "Tomorrow" }
        return formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    var shortDay: String { formatted(.dateTime.month(.abbreviated).day()) }

    /// Compact age for feeds: "now", "35m", "18h", "3d", "2w", "4mo", "1y".
    var shortAgo: String {
        let seconds = max(0, Date().timeIntervalSince(self))
        let minutes = Int(seconds / 60), hours = minutes / 60, days = hours / 24
        if minutes < 1 { return "now" }
        if hours < 1 { return "\(minutes)m" }
        if days < 1 { return "\(hours)h" }
        if days < 7 { return "\(days)d" }
        if days < 30 { return "\(days / 7)w" }
        if days < 365 { return "\(days / 30)mo" }
        return "\(days / 365)y"
    }

    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    func at(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: self) ?? self
    }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    func adding(minutes: Int) -> Date { addingTimeInterval(TimeInterval(minutes * 60)) }
}
