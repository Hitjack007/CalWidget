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
}

/// Moves the displayed month when the header arrows are tapped.
struct ShiftMonthIntent: AppIntent {
    static let title: LocalizedStringResource = "Shift Month"

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

/// Which look a widget uses. "App default" follows whatever is set in the app.
enum WidgetLook: String, AppEnum {
    case appDefault, dark, light, midnight, glass, clear

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Look"

    static let caseDisplayRepresentations: [WidgetLook: DisplayRepresentation] = [
        .appDefault: "App default",
        .dark: "Dark",
        .light: "Light",
        .midnight: "Midnight",
        .glass: "Glass",
        .clear: "Clear"
    ]

    /// The theme this widget should draw with, given the app-wide theme.
    func theme(appTheme: WidgetTheme) -> WidgetTheme {
        switch self {
        case .appDefault: appTheme
        case .dark: appTheme.applying(.standard)
        case .light: appTheme.applying(.light)
        case .midnight: appTheme.applying(.midnight)
        case .glass: appTheme.applying(.glass)
        case .clear: appTheme.applying(.clear)
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
    static let description = IntentDescription("Choose how this widget looks and which calendars it shows.")

    @Parameter(title: "Look", default: .appDefault)
    var look: WidgetLook

    @Parameter(title: "Calendars", description: "Leave empty to use the calendars selected in the app.")
    var calendars: [CalendarEntity]?
}

// MARK: - Provider

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MonthEntry {
        sampleEntry(look: .appDefault)
    }

    func snapshot(for configuration: MonthConfigurationIntent, in context: Context) async -> MonthEntry {
        // The widget gallery shows sample data so it never waits on the network.
        if context.isPreview {
            return sampleEntry(look: configuration.look)
        }
        return await liveEntry(for: configuration).entry
    }

    func timeline(for configuration: MonthConfigurationIntent, in context: Context) async -> Timeline<MonthEntry> {
        let (entry, refreshAfter) = await liveEntry(for: configuration)
        return Timeline(entries: [entry], policy: .after(refreshAfter))
    }

    private func sampleEntry(look: WidgetLook) -> MonthEntry {
        let theme = look.theme(appTheme: SharedStore.theme)
        let month = MonthLayout.month(offset: 0, calendar: theme.calendar)
        return MonthEntry(date: Date(), month: month, events: SampleData.events(in: month, calendar: theme.calendar), theme: theme, message: nil)
    }

    /// Builds the entry from Google, falling back to cached events when offline.
    /// Also returns when the widget should next refresh.
    private func liveEntry(for configuration: MonthConfigurationIntent) async -> (entry: MonthEntry, refreshAfter: Date) {
        let now = Date()
        let theme = configuration.look.theme(appTheme: SharedStore.theme)
        let offset = SharedStore.monthOffset
        let month = MonthLayout.month(offset: offset, calendar: theme.calendar, now: now)

        // A widget can show its own calendars; an empty choice means "use the app's selection".
        let chosen = configuration.calendars.map { Set($0.map(\.id)) }
        let calendarIDs = (chosen?.isEmpty == false) ? chosen : nil

        // Refresh soon after midnight so "today" moves on, and sooner while browsing another month so it snaps back.
        let nextMidnight = theme.calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 5), matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)
        let interval: TimeInterval = offset == 0 ? TimeInterval(SharedStore.refreshMinutes * 60) : 10 * 60
        let refreshAfter = min(nextMidnight, now.addingTimeInterval(interval))

        guard TokenStore.load() != nil else {
            let entry = MonthEntry(date: now, month: month, events: SampleData.events(in: month, calendar: theme.calendar), theme: theme,
                                   message: "Open gCalWidget to sign in")
            return (entry, refreshAfter)
        }

        do {
            let events = try await CalendarService.fetchEvents(for: month, calendarIDs: calendarIDs)
            SharedStore.cache(events, for: month, calendarIDs: calendarIDs)
            return (MonthEntry(date: now, month: month, events: events, theme: theme, message: nil), refreshAfter)
        } catch {
            let cached = SharedStore.cachedEvents(for: month, calendarIDs: calendarIDs) ?? []
            let message: String? = switch error {
            case GoogleAPIError.signInExpired, GoogleAPIError.notSignedIn: "Sign in again in gCalWidget"
            default: cached.isEmpty ? "Couldn't load events" : nil
            }
            return (MonthEntry(date: now, month: month, events: cached, theme: theme, message: message), refreshAfter)
        }
    }
}

struct MonthWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: MonthEntry

    var body: some View {
        MonthCalendarView(month: entry.month,
                          today: entry.date,
                          events: entry.events,
                          theme: entry.theme,
                          isLarge: family != .systemMedium,
                          message: entry.message,
                          accentableChips: renderingMode == .accented) {
            HStack(spacing: 10) {
                Button(intent: ShiftMonthIntent(delta: -1)) {
                    Image(systemName: "chevron.left")
                }
                Button(intent: ShiftMonthIntent(delta: 1)) {
                    Image(systemName: "chevron.right")
                }
            }
        }
    }
}

struct MonthWidget: Widget {
    let kind: String = "MonthWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: MonthConfigurationIntent.self, provider: Provider()) { entry in
            MonthWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground(theme: entry.theme)
                }
        }
        .configurationDisplayName("gCalWidget")
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
