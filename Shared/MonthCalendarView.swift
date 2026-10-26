//
//  MonthCalendarView.swift
//  Shared between the app and the widget extension.
//
//  The month grid is drawn by one view so the app's live preview and the widget look the same.
//

import SwiftUI
import WidgetKit

// MARK: - Layout

/// An event clipped to one week row, assigned to a lane so overlapping bars stack.
nonisolated struct WeekSegment: Identifiable {
    let event: CalendarEvent
    let startColumn: Int
    let endColumn: Int
    var lane: Int
    let continuesBefore: Bool
    let continuesAfter: Bool

    var id: String { "\(event.id)-\(startColumn)" }
}

nonisolated enum MonthLayout {
    /// First day of the month that is `offset` months from today's.
    static func month(offset: Int, calendar: Calendar, now: Date = Date()) -> Date {
        let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
        return calendar.date(byAdding: .month, value: offset, to: start) ?? start
    }

    /// Weeks covering the month, including leading and trailing days from adjacent months.
    static func weeks(for month: Date, calendar: Calendar) -> [[Date]] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: interval.start),
              let lastWeek = calendar.dateInterval(of: .weekOfYear, for: lastDay) else { return [] }
        var weeks: [[Date]] = []
        var weekStart = firstWeek.start
        while weekStart < lastWeek.end {
            weeks.append((0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) })
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { break }
            weekStart = next
        }
        return weeks
    }

    /// The full span of days drawn for `month`.
    static func gridRange(for month: Date, calendar: Calendar) -> DateInterval {
        let weeks = weeks(for: month, calendar: calendar)
        guard let first = weeks.first?.first, let last = weeks.last?.last,
              let end = calendar.date(byAdding: .day, value: 1, to: last) else {
            return DateInterval(start: month, duration: 86_400 * 42)
        }
        return DateInterval(start: first, end: end)
    }

    static func segments(for week: [Date], events: [CalendarEvent], calendar: Calendar) -> [WeekSegment] {
        guard let firstDay = week.first, let lastDay = week.last else { return [] }
        var segments: [WeekSegment] = []

        for event in events {
            let eventFirst = calendar.startOfDay(for: event.start)
            // `end` is exclusive, so the last day shown is the one before it (unless the event has no length).
            let eventLast = max(eventFirst, calendar.startOfDay(for: event.end.addingTimeInterval(-1)))
            guard eventLast >= firstDay, eventFirst <= lastDay else { continue }

            let startColumn = eventFirst <= firstDay ? 0 : (calendar.dateComponents([.day], from: firstDay, to: eventFirst).day ?? 0)
            let endColumn = eventLast >= lastDay ? 6 : (calendar.dateComponents([.day], from: firstDay, to: eventLast).day ?? 6)
            segments.append(WeekSegment(event: event, startColumn: startColumn, endColumn: endColumn, lane: 0,
                                        continuesBefore: eventFirst < firstDay, continuesAfter: eventLast > lastDay))
        }

        // Earliest column first, longest first, all-day before timed, then by start time.
        segments.sort { a, b in
            if a.startColumn != b.startColumn { return a.startColumn < b.startColumn }
            let aSpan = a.endColumn - a.startColumn
            let bSpan = b.endColumn - b.startColumn
            if aSpan != bSpan { return aSpan > bSpan }
            if a.event.isAllDay != b.event.isAllDay { return a.event.isAllDay }
            return a.event.start < b.event.start
        }

        // Place each segment in the first lane that is free for its columns.
        var laneEnds: [Int] = []
        for index in segments.indices {
            let start = segments[index].startColumn
            if let lane = laneEnds.firstIndex(where: { $0 < start }) {
                segments[index].lane = lane
                laneEnds[lane] = segments[index].endColumn
            } else {
                segments[index].lane = laneEnds.count
                laneEnds.append(segments[index].endColumn)
            }
        }
        return segments
    }
}

// MARK: - Views

struct MonthCalendarView<Navigation: View>: View {
    let month: Date
    let today: Date
    let events: [CalendarEvent]
    let theme: WidgetTheme
    let isLarge: Bool
    let message: String?
    /// True when macOS renders the widget in its Clear or Tinted style, which tints everything white.
    let isAccented: Bool
    let navigation: Navigation

    init(month: Date,
         today: Date = Date(),
         events: [CalendarEvent],
         theme: WidgetTheme,
         isLarge: Bool = true,
         message: String? = nil,
         isAccented: Bool = false,
         @ViewBuilder navigation: () -> Navigation) {
        self.month = month
        self.today = today
        self.events = events
        self.theme = isAccented ? theme.forAccentedRendering : theme
        self.isLarge = isLarge
        self.message = message
        self.isAccented = isAccented
        self.navigation = navigation()
    }

    var body: some View {
        let calendar = theme.calendar
        let weeks = MonthLayout.weeks(for: month, calendar: calendar)

        VStack(spacing: 4) {
            header

            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols(calendar).enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.text.color)
                        .frame(maxWidth: .infinity)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    WeekRow(week: week,
                            month: month,
                            today: today,
                            segments: MonthLayout.segments(for: week, events: events, calendar: calendar),
                            theme: theme,
                            calendar: calendar,
                            chipHeight: isLarge ? 13 : 10,
                            isAccented: isAccented)
                }
            }
            // Shows the grid as pending while a month-change button's intent runs.
            .invalidatableContent()
        }
        .overlay(alignment: .bottom) {
            if let message {
                Text(message)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.accentText.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(theme.accent.color))
                    .padding(.bottom, 4)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(month, format: .dateTime.month(.wide).year())
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.text.color)
                .invalidatableContent()

            Spacer()

            navigation
                .foregroundStyle(theme.text.color)

            if theme.showPlusButton, let url = theme.newEventURL {
                Link(destination: url) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.accentText.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(theme.accent.color))
                        .accessibilityLabel("New event")
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func weekdaySymbols(_ calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }
}

private struct WeekRow: View {
    let week: [Date]
    let month: Date
    let today: Date
    let segments: [WeekSegment]
    let theme: WidgetTheme
    let calendar: Calendar
    let chipHeight: CGFloat
    let isAccented: Bool

    private let dayNumberHeight: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let columnWidth = geo.size.width / 7
            let maxLanes = max(0, Int((geo.size.height - dayNumberHeight) / (chipHeight + 1)))

            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { day in
                        dayNumber(day)
                            .frame(width: columnWidth, height: dayNumberHeight)
                    }
                }

                // Bars span columns for multi-day events; lanes that don't fit are left out.
                ForEach(segments.filter { $0.lane < maxLanes }) { segment in
                    bar(segment)
                        .frame(width: columnWidth * CGFloat(segment.endColumn - segment.startColumn + 1) - 3,
                               height: chipHeight)
                        .offset(x: columnWidth * CGFloat(segment.startColumn) + 1.5,
                                y: dayNumberHeight + CGFloat(segment.lane) * (chipHeight + 1))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped()
        }
        .background(alignment: .topLeading) {
            if theme.showGrid { gridLines }
        }
    }

    private func dayNumber(_ day: Date) -> some View {
        let inMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let normal = theme.text.color

        return Text(day, format: .dateTime.day())
            .font(.system(size: 11, weight: isToday ? .bold : .regular))
            .foregroundStyle(isToday ? theme.accentText.color : (inMonth ? normal : normal.opacity(theme.dimmedTextOpacity)))
            .frame(width: 18, height: 15)
            .background(Capsule().fill(isToday ? theme.accent.color : Color.clear))
    }

    @ViewBuilder
    private func bar(_ segment: WeekSegment) -> some View {
        if let link = segment.event.link {
            Link(destination: link) { barContent(segment) }
                .buttonStyle(.plain)
        } else {
            barContent(segment)
        }
    }

    private func barContent(_ segment: WeekSegment) -> some View {
        let radius: CGFloat = 3
        let base = theme.useCalendarColors ? segment.event.color : theme.customChip
        return Text(segment.event.title)
            .font(.system(size: chipHeight > 11 ? 9 : 8, weight: .medium))
            .foregroundStyle(theme.chipText.color)
            .lineLimit(1)
            .padding(.horizontal, 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: segment.continuesBefore ? 0 : radius,
                                       bottomLeadingRadius: segment.continuesBefore ? 0 : radius,
                                       bottomTrailingRadius: segment.continuesAfter ? 0 : radius,
                                       topTrailingRadius: segment.continuesAfter ? 0 : radius)
                    .fill(base.mixedWithWhite(theme.chipSoftness).color)
                    .widgetAccentable(isAccented)
            )
    }

    /// Thin separators: a line along the top of the row and between columns.
    private var gridLines: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                for column in 1..<7 {
                    let x = geo.size.width / 7 * CGFloat(column)
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                }
            }
            .stroke(theme.grid.color, lineWidth: 0.5)
        }
    }
}

/// The widget card behind the month grid, drawn the same way in the widget and in the app's preview.
/// In the system's Clear and Tinted styles macOS removes it and draws its own glass instead.
struct WidgetBackground: View {
    let theme: WidgetTheme

    var body: some View {
        theme.background.color.opacity(theme.backgroundOpacity)
    }
}

// MARK: - Sample data

/// Placeholder events for the widget gallery and for previews before the user signs in.
nonisolated enum SampleData {
    static func events(in month: Date, calendar: Calendar = .current) -> [CalendarEvent] {
        let pink = RGBAColor(red: 0.85, green: 0.45, blue: 0.55)
        let teal = RGBAColor(red: 0.30, green: 0.65, blue: 0.55)
        let gray = RGBAColor(red: 0.55, green: 0.52, blue: 0.52)

        func event(_ id: String, _ title: String, day: Int, length: Int = 1, _ color: RGBAColor) -> CalendarEvent? {
            guard let start = calendar.date(byAdding: .day, value: day - 1, to: month),
                  let end = calendar.date(byAdding: .day, value: length, to: start) else { return nil }
            return CalendarEvent(id: id, title: title, start: start, end: end, isAllDay: true, color: color)
        }

        // A few events just ahead of today, so the Medium layout's "coming up" list has content.
        let startOfToday = calendar.startOfDay(for: Date())
        func upcoming(_ id: String, _ title: String, days: Int, hour: Int, allDay: Bool = false, _ color: RGBAColor) -> CalendarEvent? {
            guard let day = calendar.date(byAdding: .day, value: days, to: startOfToday) else { return nil }
            if allDay {
                guard let end = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
                return CalendarEvent(id: id, title: title, start: day, end: end, isAllDay: true, color: color)
            }
            guard let start = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: day) else { return nil }
            return CalendarEvent(id: id, title: title, start: start, end: start.addingTimeInterval(3600), isAllDay: false, color: color)
        }

        return [
            upcoming("u1", "Team standup", days: 0, hour: 9, pink),
            upcoming("u2", "Lunch with Sam", days: 0, hour: 12, teal),
            upcoming("u3", "Dentist", days: 1, hour: 15, pink),
            upcoming("u4", "Mum's birthday", days: 3, hour: 0, allDay: true, teal),
            event("1", "Standup", day: 2, pink),
            event("2", "New Year's", day: 3, teal),
            event("3", "Twelfth Night", day: 5, teal),
            event("4", "Physio", day: 5, pink),
            event("5", "AL", day: 6, length: 9, pink),
            event("6", "Meter reading", day: 7, pink),
            event("7", "Car service", day: 15, pink),
            event("8", "Car service", day: 16, pink),
            event("9", "Mita", day: 14, pink),
            event("10", "Shining Tools", day: 18, pink),
            event("11", "Mita", day: 28, pink),
            event("12", "Change", day: 3, gray)
        ].compactMap { $0 }
    }
}

#Preview {
    let month = MonthLayout.month(offset: 0, calendar: .current)
    MonthCalendarView(month: month, events: SampleData.events(in: month), theme: .standard) {
        EmptyView()
    }
    .padding(14)
    .frame(width: 364, height: 382)
    .background { WidgetBackground(theme: .standard) }
}

#Preview("Styles") {
    let month = MonthLayout.month(offset: 0, calendar: .current)
    // The last card imitates the system's Clear style: no background, translucent white shapes.
    let styles: [(String, WidgetTheme, Bool)] = [("Dark", .standard, false), ("Light", .light, false), ("System Clear / Tinted", .standard, true)]
    return HStack(spacing: 16) {
        ForEach(styles, id: \.0) { name, theme, accented in
            VStack(spacing: 6) {
                MonthCalendarView(month: month, events: SampleData.events(in: month), theme: theme, isAccented: accented) { EmptyView() }
                    .padding(12)
                    .frame(width: 300, height: 320)
                    .background { if !accented { WidgetBackground(theme: theme) } else { Rectangle().fill(.ultraThinMaterial) } }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                Text(name).font(.caption).foregroundStyle(.white)
            }
        }
    }
    .padding(20)
    .background {
        LinearGradient(colors: [Color(red: 0.95, green: 0.55, blue: 0.35), Color(red: 0.55, green: 0.30, blue: 0.70), Color(red: 0.20, green: 0.35, blue: 0.75)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

#Preview("Extra Large") {
    let month = MonthLayout.month(offset: 0, calendar: .current)
    MonthCalendarView(month: month, events: SampleData.events(in: month), theme: .standard) {
        HStack(spacing: 10) {
            Image(systemName: "chevron.left")
            Image(systemName: "chevron.right")
        }
    }
    .padding(16)
    .frame(width: 726, height: 344)
    .background { WidgetBackground(theme: .standard) }
    .clipShape(RoundedRectangle(cornerRadius: 22))
    .padding(20)
}
