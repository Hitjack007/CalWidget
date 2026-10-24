//
//  Models.swift
//  Shared between the app and the widget extension.
//

import SwiftUI
import AppKit

/// A Codable sRGB color, so colors can be stored in shared defaults and edited with `ColorPicker`.
nonisolated struct RGBAColor: Codable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Parses "#RRGGBB", the format Google uses for calendar colors.
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }
        self.init(red: Double((number >> 16) & 0xFF) / 255,
                  green: Double((number >> 8) & 0xFF) / 255,
                  blue: Double(number & 0xFF) / 255)
    }

    init(_ color: Color) {
        let resolved = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(red: Double(resolved.redComponent),
                  green: Double(resolved.greenComponent),
                  blue: Double(resolved.blueComponent),
                  alpha: Double(resolved.alphaComponent))
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    /// Blends toward white; 0 keeps the color, 1 is white. Gives Google's saturated colors a pastel look.
    func mixedWithWhite(_ amount: Double) -> RGBAColor {
        let t = min(max(amount, 0), 1)
        return RGBAColor(red: red + (1 - red) * t,
                         green: green + (1 - green) * t,
                         blue: blue + (1 - blue) * t,
                         alpha: alpha)
    }
}

/// An event ready to draw. For all-day events `end` is exclusive, matching Google Calendar.
nonisolated struct CalendarEvent: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: RGBAColor
}

nonisolated struct GoogleCalendarInfo: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let color: RGBAColor
    let isPrimary: Bool
}

/// How the widget's card is drawn.
nonisolated enum BackgroundStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    /// A flat color.
    case solid
    /// A blurred, see-through material with the color mixed in.
    case glass
    /// No card at all, so the wallpaper shows through.
    case clear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .solid: "Solid"
        case .glass: "Glass"
        case .clear: "Clear"
        }
    }
}

/// Everything the user can change about how the widget looks.
nonisolated struct WidgetTheme: Codable, Equatable, Sendable {
    var background = RGBAColor(red: 0.24, green: 0.21, blue: 0.21)
    var backgroundStyle = BackgroundStyle.solid
    /// How strongly the background color shows. Solid fades toward see-through, glass lets the color tint the blur.
    var backgroundOpacity = 1.0
    var text = RGBAColor(red: 1, green: 1, blue: 1)
    /// Opacity of day numbers that belong to the previous or next month.
    var dimmedTextOpacity = 0.5
    var showGrid = true
    var grid = RGBAColor(red: 1, green: 1, blue: 1, alpha: 0.18)
    var chipText = RGBAColor(red: 0.22, green: 0.12, blue: 0.15)
    /// Use each Google calendar's own color for chips, instead of `customChip`.
    var useCalendarColors = true
    var customChip = RGBAColor(red: 0.89, green: 0.62, blue: 0.70)
    /// 0 is the calendar's full color, 1 is white.
    var chipSoftness = 0.45
    /// Today's highlight and the "+" button.
    var accent = RGBAColor(red: 0.96, green: 0.88, blue: 0.88)
    var accentText = RGBAColor(red: 0.22, green: 0.12, blue: 0.15)
    /// 0 follows the system setting, otherwise 1 (Sunday) through 7 (Saturday).
    var weekStart = 0
    var showPlusButton = true

    static let standard = WidgetTheme()

    static let light = WidgetTheme(background: RGBAColor(red: 0.98, green: 0.97, blue: 0.96),
                                   text: RGBAColor(red: 0.12, green: 0.12, blue: 0.14),
                                   grid: RGBAColor(red: 0, green: 0, blue: 0, alpha: 0.12),
                                   chipSoftness: 0.25,
                                   accent: RGBAColor(red: 0.20, green: 0.40, blue: 0.85),
                                   accentText: RGBAColor(red: 1, green: 1, blue: 1))

    static let glass = WidgetTheme(background: RGBAColor(red: 0.08, green: 0.09, blue: 0.12),
                                   backgroundStyle: .glass,
                                   backgroundOpacity: 0.35,
                                   grid: RGBAColor(red: 1, green: 1, blue: 1, alpha: 0.22),
                                   chipSoftness: 0.3)

    static let clear = WidgetTheme(backgroundStyle: .clear,
                                   grid: RGBAColor(red: 1, green: 1, blue: 1, alpha: 0.3),
                                   chipSoftness: 0.2)

    static let midnight = WidgetTheme(background: RGBAColor(red: 0.07, green: 0.09, blue: 0.16),
                                      grid: RGBAColor(red: 0.6, green: 0.7, blue: 1, alpha: 0.18),
                                      accent: RGBAColor(red: 0.62, green: 0.76, blue: 1),
                                      accentText: RGBAColor(red: 0.05, green: 0.10, blue: 0.25))

    /// A preset's colors with this theme's week start and + button choices kept.
    func applying(_ preset: WidgetTheme) -> WidgetTheme {
        var theme = preset
        theme.weekStart = weekStart
        theme.showPlusButton = showPlusButton
        return theme
    }

    var calendar: Calendar {
        var calendar = Calendar.current
        if (1...7).contains(weekStart) { calendar.firstWeekday = weekStart }
        return calendar
    }
}
