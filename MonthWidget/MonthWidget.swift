//
//  MonthWidget.swift
//  MonthWidget
//
//  Created by Mark Greene on 25/10/2026.
//

import WidgetKit
import SwiftUI
import AppIntents

struct MonthEntry: TimelineEntry {
    let date: Date
    /// First day of the month being displayed.
    let month: Date
    let events: [CalendarEvent]
    let theme: WidgetTheme
    /// A short status shown over the grid, e.g. when the user hasn't signed in.
    let message: String?
    /// The Automatic style: pick the Light or Dark look to match macOS when drawing.
    var followsSystemAppearance = false
}

/// Moves the displayed month when the header arrows are tapped.
struct ShiftMonthIntent: AppIntent {
    static let title: LocalizedStringResource = "Shift Month"

    /// Only the widget's arrows run this intent, so keep it out of Shortcuts and Spotlight.
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Months")
    var delta: Int

    init() {}

    init(delta: Int) {
        self.delta = delta
    }

    func perform() async throws -> some IntentResult {
        SharedStore.shiftMonthOffset(by: delta)
        return .result()
    }
}

// MARK: - Per-widget settings

/// The widget's look. A few clearly different styles, so there's nothing to fine-tune per widget.
/// "Custom" uses whatever is set in the app's Appearance pane. For a see-through glass look, use the
/// Clear widget style in macOS settings: the system then draws real Liquid Glass behind any of these.
enum WidgetStyle: String, AppEnum {
    case custom, dark, light, automatic

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Style"

    static let caseDisplayRepresentations: [WidgetStyle: DisplayRepresentation] = [
        .custom: "Custom (from app)",
        .dark: "Dark",
        .light: "Light",
        .automatic: "Automatic (Light or Dark)"
    ]

    /// The theme this widget should draw with, given the app-wide theme.
    func theme(appTheme: WidgetTheme) -> WidgetTheme {
        switch self {
        case .custom: appTheme
        case .dark, .automatic: appTheme.applying(.standard)
        case .light: appTheme.applying(.light)
        }
    }
}

/// A Google calendar the user can pick in a widget's settings.
struct CalendarEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Calendar"
    static let defaultQuery = CalendarQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct CalendarQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CalendarEntity] {
        SharedStore.calendars
            .filter { identifiers.contains($0.id) }
            .map { CalendarEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [CalendarEntity] {
        SharedStore.calendars.map { CalendarEntity(id: $0.id, name: $0.name) }
    }
}

/// The settings shown when a widget is edited (right-click, Edit Widget).
struct MonthConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Month Calendar"
    static let description = IntentDescription("Choose this widget's style and which calendars it shows.")

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$style
            \.$calendars
        }
    }

    @Parameter(title: "Style", default: .custom)
    var style: WidgetStyle

    @Parameter(title: "Calendars", description: "Leave empty to use the calendars selected in the app.")
    var calendars: [CalendarEntity]?

    /// The calendars picked for this widget, or nil to use the app's selection.
    var chosenCalendarIDs: Set<String>? {
        guard let calendars, !calendars.isEmpty else { return nil }
        return Set(calendars.map(\.id))
    }

    /// Identifies what this widget fetches, so its cached events don't mix with the app's.
    var cacheScope: String {
        chosenCalendarIDs?.sorted().joined(separator: ",") ?? ""
    }
}

// MARK: - Provider

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MonthEntry {
        sampleEntry(for: MonthConfigurationIntent())
    }

    func snapshot(for configuration: MonthConfigurationIntent, in context: Context) async -> MonthEntry {
        // The widget gallery shows sample data so it never waits on the network.
        if context.isPreview {
            return marked(sampleEntry(for: configuration), for: configuration)
        }
        return marked(await liveEntry(for: configuration).entry, for: configuration)
    }

    func timeline(for configuration: MonthConfigurationIntent, in context: Context) async -> Timeline<MonthEntry> {
        let (entry, refreshAfter) = await liveEntry(for: configuration)
        return Timeline(entries: [marked(entry, for: configuration)], policy: .after(refreshAfter))
    }

    private func marked(_ entry: MonthEntry, for configuration: MonthConfigurationIntent) -> MonthEntry {
        var entry = entry
        entry.followsSystemAppearance = configuration.style == .automatic
        return entry
    }

    private func sampleEntry(for configuration: MonthConfigurationIntent) -> MonthEntry {
        let theme = configuration.style.theme(appTheme: SharedStore.theme)
        let month = MonthLayout.month(offset: 0, calendar: theme.calendar)
        return MonthEntry(date: Date(), month: month, events: SampleData.events(in: month, calendar: theme.calendar), theme: theme, message: nil)
    }

    /// Builds the entry from Google, falling back to cached events when offline.
    /// Also returns when the widget should next refresh.
    private func liveEntry(for configuration: MonthConfigurationIntent) async -> (entry: MonthEntry, refreshAfter: Date) {
        let now = Date()
        let appTheme = SharedStore.theme
        let theme = configuration.style.theme(appTheme: appTheme)
        let offset = SharedStore.monthOffset
        let month = MonthLayout.month(offset: offset, calendar: theme.calendar, now: now)

        // A widget can show its own calendars; no choice means "use the app's selection".
        let calendarIDs = configuration.chosenCalendarIDs
        let scope = configuration.cacheScope

        // Refresh soon after midnight so "today" moves on, and sooner while browsing another month so it snaps back.
        let nextMidnight = theme.calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 5), matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)
        let interval: TimeInterval = offset == 0 ? TimeInterval(SharedStore.refreshMinutes * 60) : 10 * 60
        let refreshAfter = min(nextMidnight, now.addingTimeInterval(interval))

        // Debug builds can force dummy data, so the widget is usable without a Google sign-in.
        if SharedStore.useDummyData {
            let entry = MonthEntry(date: now, month: month, events: SampleData.events(in: month, calendar: theme.calendar), theme: theme, message: nil)
            return (entry, refreshAfter)
        }

        guard TokenStore.load() != nil else {
            let entry = MonthEntry(date: now, month: month, events: SampleData.events(in: month, calendar: theme.calendar), theme: theme,
                                   message: "Open CalWidget to sign in")
            return (entry, refreshAfter)
        }

        do {
            let events = try await CalendarService.fetchEvents(for: month, calendarIDs: calendarIDs, calendar: theme.calendar)
            SharedStore.cache(events, for: month, scope: scope)
            return (MonthEntry(date: now, month: month, events: events, theme: theme, message: nil), refreshAfter)
        } catch {
            let cached = SharedStore.cachedEvents(for: month, scope: scope) ?? []
            let message: String? = switch error {
            case GoogleAPIError.signInExpired, GoogleAPIError.notSignedIn: "Sign in again in CalWidget"
            default: cached.isEmpty ? "Couldn't load events" : nil
            }
            return (MonthEntry(date: now, month: month, events: cached, theme: theme, message: message), refreshAfter)
        }
    }
}

struct MonthWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme
    let entry: MonthEntry

    /// The Automatic style follows macOS: the Light look in light mode, the Dark look in dark mode.
    private var theme: WidgetTheme {
        guard entry.followsSystemAppearance else { return entry.theme }
        return entry.theme.applying(colorScheme == .dark ? .standard : .light)
    }

    var body: some View {
        Group {
            if family == .systemMedium {
                CompactMonthView(month: entry.month,
                                 today: entry.date,
                                 events: entry.events,
                                 theme: theme,
                                 message: entry.message,
                                 isAccented: renderingMode == .accented) {
                    monthButtons
                }
            } else {
                MonthCalendarView(month: entry.month,
                                  today: entry.date,
                                  events: entry.events,
                                  theme: theme,
                                  isLarge: true,
                                  message: entry.message,
                                  isAccented: renderingMode == .accented) {
                    monthButtons
                }
            }
        }
        // macOS removes this in its Clear and Tinted widget styles and draws Liquid Glass instead.
        .containerBackground(for: .widget) {
            WidgetBackground(theme: theme)
        }
    }

    /// The previous and next month buttons.
    private var monthButtons: some View {
        HStack(spacing: 10) {
            Button(intent: ShiftMonthIntent(delta: -1)) {
                Image(systemName: "chevron.left")
                    .accessibilityLabel("Previous month")
            }
            Button(intent: ShiftMonthIntent(delta: 1)) {
                Image(systemName: "chevron.right")
                    .accessibilityLabel("Next month")
            }
        }
    }
}

struct MonthWidget: Widget {
    let kind: String = "gCalWidget.month"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: MonthConfigurationIntent.self, provider: Provider()) { entry in
            MonthWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("CalWidget")
        .description("A month view of your Google Calendar. Edit the widget to change its look or calendars.")
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
    }
}

#Preview(as: .systemLarge) {
    MonthWidget()
} timeline: {
    let month = MonthLayout.month(offset: 0, calendar: .current)
    MonthEntry(date: .now, month: month, events: SampleData.events(in: month), theme: .standard, message: nil)
}
