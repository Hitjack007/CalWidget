//
//  CompactMonthView.swift
//  Shared between the app and the widget extension.
//
//  The Medium layout. Medium is too short for a month of event chips, so it shows a mini month with
//  event dots next to a short list of what's coming up.
//

import SwiftUI
import WidgetKit

struct CompactMonthView<Navigation: View>: View {
    let month: Date
    let today: Date
    let events: [CalendarEvent]
    let theme: WidgetTheme
    let message: String?
    let isAccented: Bool
    let navigation: Navigation

    init(month: Date,
         today: Date = Date(),
         events: [CalendarEvent],
         theme: WidgetTheme,
         message: String? = nil,
         isAccented: Bool = false,
         @ViewBuilder navigation: () -> Navigation) {
        self.month = month
        self.today = today
        self.events = events
        self.theme = isAccented ? theme.forAccentedRendering : theme
        self.message = message
        self.isAccented = isAccented
        self.navigation = navigation()
    }

    private var calendar: Calendar { theme.calendar }
    private let maxAgendaItems = 4

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            miniMonth
                .frame(width: 142)

            if theme.showGrid {
                Rectangle()
                    .fill(theme.grid.color)
                    .frame(width: 0.5)
            }

            agenda
        }
        .overlay(alignment: .bottom) {
            if let message {
                Text(message)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.accentText.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(theme.accent.color))
            }
        }
    }

    // MARK: Mini month

    private var miniMonth: some View {
        let weeks = MonthLayout.weeks(for: month, calendar: calendar)

        return VStack(spacing: 2) {
            HStack(spacing: 6) {
                Text(month, format: .dateTime.month(.wide))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.text.color)
                    .lineLimit(1)
                    .invalidatableContent()

                Spacer(minLength: 0)

                navigation
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.text.color)
                    .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(theme.text.color.opacity(0.7))
                        .frame(maxWidth: .infinity)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 0) {
                        ForEach(week, id: \.self) { day in
                            dayCell(day)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .invalidatableContent()
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let inMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let dots = dotColors(on: day)
        let normal = theme.text.color

        return ZStack {
            if isToday {
                Circle()
                    .fill(theme.accent.color)
                    .frame(width: 15, height: 15)
            }
            Text(day, format: .dateTime.day())
                .font(.system(size: 9, weight: isToday ? .bold : .regular))
                .foregroundStyle(isToday ? theme.accentText.color : (inMonth ? normal : normal.opacity(theme.dimmedTextOpacity)))
                .offset(y: dots.isEmpty ? 0 : -1)
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 1.5) {
                ForEach(Array(dots.enumerated()), id: \.offset) { _, color in
                    Circle().fill(color).frame(width: 3, height: 3)
                }
            }
            .offset(y: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    /// Events that touch `day`.
    private func events(on day: Date) -> [CalendarEvent] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return events.filter { $0.start < end && max($0.end, $0.start.addingTimeInterval(1)) > start }
    }

    /// Up to three distinct dot colors for a day.
    private func dotColors(on day: Date) -> [Color] {
        var seen: [RGBAColor] = []
        for event in events(on: day) where !seen.contains(event.color) {
            seen.append(event.color)
            if seen.count == 3 { break }
        }
        return seen.map { accentColor(for: $0) }
    }

    /// The solid color for a dot or agenda marker. In the system's Clear and Tinted styles it is plain white.
    private func accentColor(for color: RGBAColor) -> Color {
        if isAccented { return Color.white.opacity(0.9) }
        return (theme.useCalendarColors ? color : theme.customChip).color
    }

    // MARK: Agenda

    /// Events from today onward, or from the start of the month when browsing another month.
    private var upcoming: [CalendarEvent] {
        let from = calendar.isDate(today, equalTo: month, toGranularity: .month) ? calendar.startOfDay(for: today) : month
        return events
            .filter { $0.end > from }
            .sorted { ($0.start, $0.title) < ($1.start, $1.title) }
            .prefix(maxAgendaItems)
            .map { $0 }
    }

    private var agenda: some View {
        VStack(alignment: .leading, spacing: 5) {
            if upcoming.isEmpty {
                Spacer(minLength: 0)
                Text("Nothing coming up")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.text.color.opacity(0.7))
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            } else {
                ForEach(upcoming) { event in
                    agendaRow(event)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            if theme.showPlusButton, let url = URL(string: "https://calendar.google.com/calendar/r/eventedit") {
                Link(destination: url) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.accentText.color)
                        .frame(width: 24, height: 16)
                        .background(Capsule().fill(theme.accent.color))
                        .accessibilityLabel("New event")
                }
            }
        }
    }

    private func agendaRow(_ event: CalendarEvent) -> some View {
        HStack(alignment: .top, spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(accentColor(for: event.color))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.text.color)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(event.start, format: .dateTime.weekday(.abbreviated).day())
                    if event.isAllDay {
                        Text("All day")
                    } else {
                        Text(event.start, format: .dateTime.hour().minute())
                    }
                }
                .font(.system(size: 9))
                .foregroundStyle(theme.text.color.opacity(0.7))
                .lineLimit(1)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        // The "+" button overlaps the first row's trailing edge, so keep text clear of it.
        .padding(.trailing, event.id == upcoming.first?.id ? 28 : 0)
    }
}

#Preview("Medium") {
    let month = MonthLayout.month(offset: 0, calendar: .current)
    let variants: [(String, WidgetTheme, Bool)] = [("Dark", .standard, false), ("Light", .light, false), ("System Clear / Tinted", .standard, true)]
    return VStack(spacing: 14) {
        ForEach(variants, id: \.0) { name, theme, accented in
            VStack(spacing: 4) {
                CompactMonthView(month: month, events: SampleData.events(in: month), theme: theme, isAccented: accented) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Image(systemName: "chevron.right")
                    }
                }
                .padding(16)
                .frame(width: 329, height: 155)
                .background { if accented { Rectangle().fill(.ultraThinMaterial) } else { WidgetBackground(theme: theme) } }
                .clipShape(RoundedRectangle(cornerRadius: 22))
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
