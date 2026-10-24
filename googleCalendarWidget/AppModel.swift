//
//  AppModel.swift
//  googleCalendarWidget
//

import SwiftUI
import WidgetKit
import AuthenticationServices

/// App-wide state: sign-in, calendars, the widget's look, and the preview shown in the window.
@Observable
final class AppModel {
    var isSignedIn = TokenStore.load() != nil
    var calendars = SharedStore.calendars
    var selectedIDs = SharedStore.selectedCalendarIDs ?? []
    var theme = SharedStore.theme
    var refreshMinutes = SharedStore.refreshMinutes
    var events: [CalendarEvent] = []
    var previewOffset = 0
    var lastSync = SharedStore.lastSync
    var isWorking = false
    var errorMessage: String?

    private var themeSaveTask: Task<Void, Never>?

    var previewMonth: Date {
        MonthLayout.month(offset: previewOffset, calendar: theme.calendar)
    }

    /// The account's email, which Google uses as the ID of the primary calendar.
    var accountName: String? {
        calendars.first(where: \.isPrimary)?.id
    }

    // MARK: Lifecycle

    func start() async {
        guard isSignedIn else { return }
        await refreshAll()
    }

    // MARK: Sign-in

    func signIn() async {
        errorMessage = nil
        guard GoogleConfig.isConfigured else {
            errorMessage = GoogleAPIError.missingClientID.localizedDescription
            return
        }

        isWorking = true
        defer { isWorking = false }
        do {
            let tokens = try await GoogleSignIn.signIn(clientID: GoogleConfig.clientID)
            guard TokenStore.save(tokens) else { throw SignInError.keychainFailed }
            isSignedIn = true
            await refreshAll()
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // The user closed the sign-in window; nothing to report.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        TokenStore.clear()
        SharedStore.clearAccountData()
        isSignedIn = false
        calendars = []
        selectedIDs = []
        events = []
        lastSync = nil
        previewOffset = 0
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Data

    func refreshAll() async {
        isWorking = true
        defer { isWorking = false }
        do {
            calendars = try await CalendarService.refreshCalendarList()
            selectedIDs = SharedStore.selectedCalendarIDs ?? []
            try await loadEvents()
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    func refreshEvents() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await loadEvents()
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    private func loadEvents() async throws {
        let month = previewMonth
        events = try await CalendarService.fetchEvents(for: month)
        SharedStore.cache(events, for: month)
        lastSync = SharedStore.lastSync
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func handle(_ error: Error) {
        if case GoogleAPIError.signInExpired = error {
            isSignedIn = false
        }
        errorMessage = error.localizedDescription
    }

    func shiftPreview(by delta: Int) {
        previewOffset += delta
        Task { await refreshEvents() }
    }

    func setCalendar(_ calendar: GoogleCalendarInfo, enabled: Bool) {
        if enabled {
            selectedIDs.insert(calendar.id)
        } else {
            selectedIDs.remove(calendar.id)
        }
        SharedStore.selectedCalendarIDs = selectedIDs
        Task { await refreshEvents() }
    }

    // MARK: Settings

    func refreshIntervalDidChange() {
        SharedStore.refreshMinutes = refreshMinutes
        WidgetCenter.shared.reloadAllTimelines()
    }

    func resetAppearance() {
        theme = WidgetTheme.standard
        themeDidChange()
    }

    func resetAllSettings() {
        refreshMinutes = 30
        refreshIntervalDidChange()
        resetAppearance()
    }

    // MARK: Appearance

    /// Saves the theme and refreshes the widget. Waits briefly so dragging a color picker doesn't reload on every frame.
    func themeDidChange() {
        SharedStore.theme = theme
        themeSaveTask?.cancel()
        themeSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
