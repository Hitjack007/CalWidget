//
//  CalWidgetTests.swift
//  CalWidgetTests
//
//  Created by Mark Greene on 25/10/2026.
//
//  Tests for the logic shared by the app and the widget. The Shared folder is compiled
//  straight into this test bundle, so no host app is needed.
//

import Testing
import Foundation
import SwiftUI

// MARK: - Helpers

/// A fixed calendar, so results don't depend on the machine's locale or time zone.
private func makeCalendar(firstWeekday: Int) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    calendar.firstWeekday = firstWeekday
    return calendar
}

private let monday = makeCalendar(firstWeekday: 2)
private let sunday = makeCalendar(firstWeekday: 1)

private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, in calendar: Calendar = monday) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date.distantPast
}

private let pink = RGBAColor(red: 0.9, green: 0.4, blue: 0.5)

private func event(_ id: String, from start: Date, to end: Date, allDay: Bool = true) -> CalendarEvent {
    CalendarEvent(id: id, title: id, start: start, end: end, isAllDay: allDay, color: pink)
}

// MARK: - Month layout

struct MonthLayoutTests {
    @Test func mondayStartGridCoversTheMonthInWholeWeeks() {
        // October 2026 runs Thursday 1st to Saturday 31st.
        let weeks = MonthLayout.weeks(for: date(2026, 10, 1), calendar: monday)
        #expect(weeks.count == 5)
        #expect(weeks.allSatisfy { $0.count == 7 })
        #expect(weeks.first?.first == date(2026, 9, 28))
        #expect(weeks.last?.last == date(2026, 11, 1))
    }

    @Test func sundayStartGridShiftsTheWeeks() {
        let weeks = MonthLayout.weeks(for: date(2026, 10, 1, in: sunday), calendar: sunday)
        #expect(weeks.count == 5)
        #expect(weeks.first?.first == date(2026, 9, 27, in: sunday))
        #expect(weeks.last?.last == date(2026, 10, 31, in: sunday))
    }

    @Test func monthThatSpillsIntoASixthWeek() {
        // March 2025 starts on a Saturday and ends on a Monday.
        let weeks = MonthLayout.weeks(for: date(2025, 3, 1), calendar: monday)
        #expect(weeks.count == 6)
        #expect(weeks.first?.first == date(2025, 2, 24))
        #expect(weeks.last?.last == date(2025, 4, 6))
    }

    @Test func gridRangeRunsToTheEndOfTheLastVisibleDay() {
        let range = MonthLayout.gridRange(for: date(2026, 10, 1), calendar: monday)
        #expect(range.start == date(2026, 9, 28))
        #expect(range.end == date(2026, 11, 2))
    }

    @Test func monthOffsetsMoveByWholeMonthsAcrossYears() {
        let now = date(2026, 10, 25)
        #expect(MonthLayout.month(offset: 0, calendar: monday, now: now) == date(2026, 10, 1))
        #expect(MonthLayout.month(offset: -1, calendar: monday, now: now) == date(2026, 9, 1))
        #expect(MonthLayout.month(offset: 3, calendar: monday, now: now) == date(2027, 1, 1))
    }
}

// MARK: - Event segments

struct WeekSegmentTests {
    private let week2 = MonthLayout.weeks(for: date(2026, 10, 1), calendar: monday)[1]  // Mon 5 Oct ... Sun 11 Oct
    private let week3 = MonthLayout.weeks(for: date(2026, 10, 1), calendar: monday)[2]  // Mon 12 Oct ... Sun 18 Oct

    @Test func singleAllDayEventOccupiesOneColumn() {
        // All-day end dates are exclusive: 8th to 9th is just the 8th.
        let segments = MonthLayout.segments(for: week2, events: [event("a", from: date(2026, 10, 8), to: date(2026, 10, 9))], calendar: monday)
        #expect(segments.count == 1)
        #expect(segments.first?.startColumn == 3)
        #expect(segments.first?.endColumn == 3)
        #expect(segments.first?.continuesBefore == false)
        #expect(segments.first?.continuesAfter == false)
    }

    @Test func timedEventEndingAtMidnightDoesNotSpillIntoTheNextDay() {
        let late = event("late", from: date(2026, 10, 8, hour: 22), to: date(2026, 10, 9), allDay: false)
        let segment = MonthLayout.segments(for: week2, events: [late], calendar: monday).first
        #expect(segment?.startColumn == 3)
        #expect(segment?.endColumn == 3)
    }

    @Test func multiDayEventIsSplitAcrossWeeks() {
        // Wednesday 7th through Tuesday 13th.
        let trip = event("trip", from: date(2026, 10, 7), to: date(2026, 10, 14))

        let first = MonthLayout.segments(for: week2, events: [trip], calendar: monday).first
        #expect(first?.startColumn == 2)
        #expect(first?.endColumn == 6)
        #expect(first?.continuesBefore == false)
        #expect(first?.continuesAfter == true)

        let second = MonthLayout.segments(for: week3, events: [trip], calendar: monday).first
        #expect(second?.startColumn == 0)
        #expect(second?.endColumn == 1)
        #expect(second?.continuesBefore == true)
        #expect(second?.continuesAfter == false)
    }

    @Test func eventsOutsideTheWeekAreIgnored() {
        let elsewhere = event("x", from: date(2026, 10, 20), to: date(2026, 10, 21))
        #expect(MonthLayout.segments(for: week2, events: [elsewhere], calendar: monday).isEmpty)
    }

    @Test func overlappingEventsStackInSeparateLanes() {
        let a = event("a", from: date(2026, 10, 6), to: date(2026, 10, 9))
        let b = event("b", from: date(2026, 10, 7), to: date(2026, 10, 8))
        let lanes = MonthLayout.segments(for: week2, events: [a, b], calendar: monday).map(\.lane)
        #expect(Set(lanes).count == 2)
    }

    @Test func eventsThatDoNotOverlapShareALane() {
        let a = event("a", from: date(2026, 10, 5), to: date(2026, 10, 6))
        let b = event("b", from: date(2026, 10, 6), to: date(2026, 10, 7))
        let lanes = MonthLayout.segments(for: week2, events: [a, b], calendar: monday).map(\.lane)
        #expect(lanes == [0, 0])
    }

    @Test func longerEventsClaimTheTopLane() {
        let short = event("short", from: date(2026, 10, 6), to: date(2026, 10, 7))
        let long = event("long", from: date(2026, 10, 6), to: date(2026, 10, 10))
        let segments = MonthLayout.segments(for: week2, events: [short, long], calendar: monday)
        #expect(segments.first(where: { $0.event.id == "long" })?.lane == 0)
        #expect(segments.first(where: { $0.event.id == "short" })?.lane == 1)
    }
}

// MARK: - Colors

struct ColorTests {
    @Test func parsesGoogleHexColors() throws {
        let color = try #require(RGBAColor(hex: "#E67C73"))
        #expect(abs(color.red - 230.0 / 255) < 0.001)
        #expect(abs(color.green - 124.0 / 255) < 0.001)
        #expect(abs(color.blue - 115.0 / 255) < 0.001)
        #expect(color.alpha == 1)
    }

    @Test func rejectsMalformedHex() {
        #expect(RGBAColor(hex: "#12") == nil)
        #expect(RGBAColor(hex: "zzzzzz") == nil)
        #expect(RGBAColor(hex: "") == nil)
    }

    @Test func mixingWithWhite() {
        #expect(pink.mixedWithWhite(0) == pink)
        let white = pink.mixedWithWhite(1)
        #expect(white.red == 1 && white.green == 1 && white.blue == 1)
        // Out-of-range amounts are clamped, and transparency is kept.
        #expect(pink.mixedWithWhite(5) == white)
        #expect(RGBAColor(red: 0, green: 0, blue: 0, alpha: 0.4).mixedWithWhite(0.5).alpha == 0.4)
    }
}

// MARK: - Themes

struct ThemeTests {
    @Test func presetsKeepTheUsersWeekStartAndPlusButton() {
        var mine = WidgetTheme.standard
        mine.weekStart = 2
        mine.showPlusButton = false

        let light = mine.applying(.light)
        #expect(light.weekStart == 2)
        #expect(light.showPlusButton == false)
        #expect(light.background == WidgetTheme.light.background)
    }

    @Test func accentedRenderingUsesTranslucentWhiteAndNoOpaqueColors() {
        let accented = WidgetTheme.light.forAccentedRendering
        let white = RGBAColor(red: 1, green: 1, blue: 1)
        #expect(accented.text == white)
        #expect(accented.chipText == white)
        #expect(accented.useCalendarColors == false)
        #expect(accented.customChip.alpha < 1)
        #expect(accented.chipSoftness == 0)
        #expect(accented.accent.alpha < 1)
    }

    @Test func stylesLookDifferent() {
        #expect(WidgetTheme.standard != WidgetTheme.light)
        #expect(WidgetTheme.standard.background != WidgetTheme.light.background)
    }

    @Test func themeSurvivesEncodingAndDecoding() throws {
        var theme = WidgetTheme.light
        theme.weekStart = 7
        theme.chipSoftness = 0.6
        let decoded = try JSONDecoder().decode(WidgetTheme.self, from: JSONEncoder().encode(theme))
        #expect(decoded == theme)
    }

    @Test func weekStartOverridesTheCalendarOnlyWhenSet() {
        var theme = WidgetTheme.standard
        theme.weekStart = 0
        #expect(theme.calendar.firstWeekday == Calendar.current.firstWeekday)
        theme.weekStart = 7
        #expect(theme.calendar.firstWeekday == 7)
    }
}

// MARK: - Shared storage

/// These use the process's own defaults (there's no app group in a test bundle), and clean up after themselves.
@Suite(.serialized)
struct SharedStoreTests {
    @Test func monthOffsetAccumulatesAndReturnsToZero() {
        SharedStore.clearAccountData()
        defer { SharedStore.clearAccountData() }

        #expect(SharedStore.monthOffset == 0)
        SharedStore.shiftMonthOffset(by: 1)
        SharedStore.shiftMonthOffset(by: 1)
        #expect(SharedStore.monthOffset == 2)
        SharedStore.shiftMonthOffset(by: -2)
        #expect(SharedStore.monthOffset == 0)
    }

    @Test func eventCacheIsSeparatedByScope() {
        SharedStore.clearAccountData()
        defer { SharedStore.clearAccountData() }

        let month = date(2026, 10, 1)
        let mine = [event("mine", from: date(2026, 10, 8), to: date(2026, 10, 9))]
        let other = [event("other", from: date(2026, 10, 9), to: date(2026, 10, 10))]

        SharedStore.cache(mine, for: month)
        SharedStore.cache(other, for: month, scope: "work")

        #expect(SharedStore.cachedEvents(for: month)?.map(\.id) == ["mine"])
        #expect(SharedStore.cachedEvents(for: month, scope: "work")?.map(\.id) == ["other"])
        #expect(SharedStore.cachedEvents(for: month, scope: "unknown") == nil)
        #expect(SharedStore.cachedEvents(for: date(2026, 11, 1)) == nil)
    }

    @Test func clearingAccountDataRemovesTheCache() {
        let month = date(2026, 10, 1)
        SharedStore.cache([event("a", from: date(2026, 10, 8), to: date(2026, 10, 9))], for: month)
        SharedStore.clearAccountData()
        #expect(SharedStore.cachedEvents(for: month) == nil)
    }
}

// MARK: - OAuth redirect parsing

struct OAuthCallbackTests {
    @Test func readsTheCodeAndStateFromGoogleRedirect() {
        let request = "GET /?code=4%2F0AbC&state=xyz&scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fcalendar.readonly HTTP/1.1\r\nHost: 127.0.0.1:5000\r\n\r\n"
        let items = OAuthCallback.queryItems(fromRequest: request)
        #expect(items.first(where: { $0.name == "code" })?.value == "4/0AbC")
        #expect(items.first(where: { $0.name == "state" })?.value == "xyz")
        #expect(OAuthCallback.isRedirect(items))
    }

    @Test func readsAnErrorRedirect() {
        let items = OAuthCallback.queryItems(fromRequest: "GET /?error=access_denied&state=xyz HTTP/1.1\r\n\r\n")
        #expect(items.first(where: { $0.name == "error" })?.value == "access_denied")
        #expect(OAuthCallback.isRedirect(items))
    }

    @Test func ignoresStrayRequests() {
        let favicon = OAuthCallback.queryItems(fromRequest: "GET /favicon.ico HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n")
        #expect(OAuthCallback.isRedirect(favicon) == false)

        #expect(OAuthCallback.queryItems(fromRequest: "POST /?code=abc HTTP/1.1\r\n\r\n").isEmpty)
        #expect(OAuthCallback.queryItems(fromRequest: "").isEmpty)
        #expect(OAuthCallback.queryItems(fromRequest: "garbage").isEmpty)
    }
}

// MARK: - Loopback server

/// Starts the real listener on 127.0.0.1 and talks to it over HTTP, the way a browser does after Google redirects.
struct LoopbackServerTests {
    private func get(_ port: UInt16, _ path: String) async throws -> (status: Int, body: String) {
        let url = try #require(URL(string: "http://127.0.0.1:\(port)\(path)"))
        let (data, response) = try await URLSession.shared.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (status, String(decoding: data, as: UTF8.self))
    }

    @Test func deliversTheRedirectAndAnswersTheBrowser() async throws {
        let server = LoopbackServer()
        defer { server.stop() }
        let port = try await server.start()
        #expect(port > 0)

        async let waiting = server.waitForRedirect()
        let reply = try await get(port, "/?code=abc123&state=xyz")
        let items = try await waiting

        #expect(reply.status == 200)
        #expect(reply.body.contains("close this tab"))
        #expect(items.first(where: { $0.name == "code" })?.value == "abc123")
        #expect(items.first(where: { $0.name == "state" })?.value == "xyz")
    }

    @Test func ignoresStrayRequestsUntilTheRealRedirectArrives() async throws {
        let server = LoopbackServer()
        defer { server.stop() }
        let port = try await server.start()

        async let waiting = server.waitForRedirect()
        let favicon = try await get(port, "/favicon.ico")
        #expect(favicon.status == 404)

        _ = try await get(port, "/?error=access_denied&state=xyz")
        let items = try await waiting
        #expect(items.first(where: { $0.name == "error" })?.value == "access_denied")
    }

    @Test func stoppingEndsTheWait() async throws {
        let server = LoopbackServer()
        _ = try await server.start()

        let waiting = Task { try await server.waitForRedirect() }
        server.stop()
        await #expect(throws: CancellationError.self) { _ = try await waiting.value }
    }

    @Test func listensOnLoopbackOnly() async throws {
        let server = LoopbackServer()
        defer { server.stop() }
        let port = try await server.start()
        // It answers on 127.0.0.1, which is where Google's redirect goes.
        let reply = try await get(port, "/anything")
        #expect(reply.status == 404)
    }
}
