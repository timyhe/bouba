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
        if weight == .medium { return 500 }
        if weight == .light { return 300 }
        if weight == .thin { return 200 }
        if weight == .ultraLight { return 100 }
        return 400
    }

    /// Navigation bar titles in Allo.
    @MainActor
    static func applyAppearance() {
        let large = uiFont(size: 34, weight: 700)
        let inline = uiFont(size: 17, weight: 600)
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: large]
        UINavigationBar.appearance().titleTextAttributes = [.font: inline]
    }
}

extension Font {
    /// Allo at a given size and weight.
    static func allo(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font(AlloFont.uiFont(size: size, weight: AlloFont.value(for: weight)) as CTFont)
    }

    /// Text typed into inputs, a step heavier than body text. The name and phone fields go bigger.
    static var alloInput: Font { allo(17, .medium) }

    /// Gray secondary text: slightly heavier than regular (420) so it holds up at small sizes.
    static func alloSubtext(_ size: CGFloat) -> Font {
        Font(AlloFont.uiFont(size: size, weight: 420) as CTFont)
    }
}

// MARK: - Colors

extension ShapeStyle where Self == Color {
    /// The original orange, kept as the Food category color. Not the accent.
    static var petOrange: Color { Color(red: 1.0, green: 0.498, blue: 0.227) }
    /// Brand accent, #E86018: a slightly deeper take on the original orange.
    /// For borders, bands and other non-text marks; text and fills use the darker tokens below.
    static var boubaOrange: Color { Color(red: 232/255, green: 96/255, blue: 24/255) }
    static var boubaGreen: Color { Color(red: 0.13, green: 0.62, blue: 0.33) }

    // Text tokens: each reaches 4.5:1 on white (cards and pages) in light mode.
    // Dark mode uses a lighter tint so text still passes on dark backgrounds.
    /// Accent for text and small icons: #C44400 (5.03:1 on white), lighter in dark mode (6.76:1).
    static var boubaOrangeText: Color { adaptive(light: (196, 68, 0), dark: (255, 127, 58)) }
    /// Accent fill behind white text (buttons, selected chips): #D04900, 4.53:1 with white,
    /// the brightest orange that still passes. Text stays on the darker token above.
    static var boubaOrangeFill: Color { adaptive(light: (208, 73, 0), dark: (208, 73, 0)) }
    /// Green for text and small icons.
    static var boubaGreenText: Color { adaptive(light: (27, 131, 69), dark: (48, 209, 88)) }
    /// Red for errors and warnings.
    static var dangerText: Color { adaptive(light: (200, 30, 30), dark: (255, 105, 97)) }
    /// Secondary gray text: 4.85:1 on white, unlike the system's 60% gray.
    static var textSecondary: Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? .secondaryLabel
                                                       : UIColor(red: 113/255, green: 113/255, blue: 118/255, alpha: 1) })
    }

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

    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    func at(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: self) ?? self
    }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    func adding(minutes: Int) -> Date { addingTimeInterval(TimeInterval(minutes * 60)) }
}
