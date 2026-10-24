//
//  GoogleServices.swift
//  Shared between the app and the widget extension.
//
//  OAuth token handling and read-only Google Calendar API access.
//

import Foundation

nonisolated enum GoogleAPIError: LocalizedError {
    case missingClientID
    case notSignedIn
    case signInExpired
    case http(Int, String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingClientID: "This build has no Google client ID. The developer needs to add one in GoogleConfig.swift."
        case .notSignedIn: "You're not signed in to Google."
        case .signInExpired: "Your Google sign-in has expired. Sign in again."
        case .http(let code, let message): "Google returned an error (\(code)): \(message)"
        case .invalidResponse: "Google sent a response the app couldn't read."
        }
    }
}

nonisolated struct TokenSet: Codable, Sendable {
    var accessToken: String
    var refreshToken: String
    var expiry: Date
}

nonisolated enum TokenStore {
    private static let account = "google-oauth-tokens"

    static func load() -> TokenSet? {
        guard let data = KeychainStore.load(account: account) else { return nil }
        return try? JSONDecoder().decode(TokenSet.self, from: data)
    }

    @discardableResult
    static func save(_ tokens: TokenSet) -> Bool {
        guard let data = try? JSONEncoder().encode(tokens) else { return false }
        return KeychainStore.save(data, account: account)
    }

    static func clear() {
        KeychainStore.delete(account: account)
    }
}

nonisolated enum GoogleAuth {
    static let scope = "https://www.googleapis.com/auth/calendar.readonly"

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: Double
    }

    private struct ErrorResponse: Decodable {
        let error: String?
        let error_description: String?
    }

    /// Exchanges an authorization code (with its PKCE verifier) for tokens.
    static func exchange(code: String, verifier: String, redirectURI: String, clientID: String) async throws -> TokenSet {
        let response = try await tokenRequest([
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ])
        guard let refresh = response.refresh_token else { throw GoogleAPIError.invalidResponse }
        return TokenSet(accessToken: response.access_token, refreshToken: refresh,
                        expiry: Date().addingTimeInterval(response.expires_in))
    }

    /// Returns a usable access token, refreshing it first if it is about to expire.
    static func validAccessToken() async throws -> String {
        let clientID = GoogleConfig.clientID
        guard GoogleConfig.isConfigured else { throw GoogleAPIError.missingClientID }
        guard let tokens = TokenStore.load() else { throw GoogleAPIError.notSignedIn }
        if tokens.expiry > Date().addingTimeInterval(60) { return tokens.accessToken }

        let response = try await tokenRequest([
            "client_id": clientID,
            "refresh_token": tokens.refreshToken,
            "grant_type": "refresh_token"
        ])
        let refreshed = TokenSet(accessToken: response.access_token,
                                 refreshToken: response.refresh_token ?? tokens.refreshToken,
                                 expiry: Date().addingTimeInterval(response.expires_in))
        TokenStore.save(refreshed)
        return refreshed.accessToken
    }

    private static func tokenRequest(_ parameters: [String: String]) async throws -> TokenResponse {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else { throw GoogleAPIError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = parameters
            .map { "\($0.key)=\(formEncode($0.value))" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleAPIError.invalidResponse }
        guard http.statusCode == 200 else {
            let details = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            if details?.error == "invalid_grant" {
                // The refresh token was revoked or expired; the user has to sign in again.
                TokenStore.clear()
                throw GoogleAPIError.signInExpired
            }
            throw GoogleAPIError.http(http.statusCode, details?.error_description ?? details?.error ?? "Token request failed")
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private static func formEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))) ?? value
    }
}

nonisolated enum CalendarAPI {
    private struct CalendarListResponse: Decodable {
        struct Item: Decodable {
            let id: String
            let summary: String?
            let summaryOverride: String?
            let backgroundColor: String?
            let primary: Bool?
            let selected: Bool?
        }
        let items: [Item]?
    }

    private struct EventsResponse: Decodable {
        struct When: Decodable {
            let date: String?
            let dateTime: String?
        }
        struct Item: Decodable {
            let id: String
            let status: String?
            let summary: String?
            let start: When?
            let end: When?
        }
        let items: [Item]?
        let nextPageToken: String?
    }

    private static func get<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        let token = try await GoogleAuth.validAccessToken()
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleAPIError.invalidResponse }
        guard http.statusCode == 200 else {
            throw GoogleAPIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// The user's calendars. `selectedInGoogle` mirrors the checkbox state in Google Calendar's sidebar.
    static func calendars() async throws -> [(info: GoogleCalendarInfo, selectedInGoogle: Bool)] {
        guard let url = URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList?minAccessRole=reader&maxResults=250") else {
            throw GoogleAPIError.invalidResponse
        }
        let response = try await get(url, as: CalendarListResponse.self)
        return (response.items ?? []).map { item in
            let info = GoogleCalendarInfo(id: item.id,
                                          name: item.summaryOverride ?? item.summary ?? item.id,
                                          color: item.backgroundColor.flatMap { RGBAColor(hex: $0) } ?? RGBAColor(red: 0.89, green: 0.62, blue: 0.70),
                                          isPrimary: item.primary ?? false)
            return (info, item.selected ?? false)
        }
    }

    /// Events from one calendar overlapping [from, to), with recurring events expanded.
    static func events(in calendar: GoogleCalendarInfo, from: Date, to: Date) async throws -> [CalendarEvent] {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        guard let encodedID = calendar.id.addingPercentEncoding(withAllowedCharacters: allowed) else { return [] }

        let utc = ISO8601DateFormatter()
        utc.formatOptions = [.withInternetDateTime]
        utc.timeZone = TimeZone(identifier: "UTC")

        var results: [CalendarEvent] = []
        var pageToken: String?
        repeat {
            guard var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(encodedID)/events") else { break }
            var query = [
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "orderBy", value: "startTime"),
                URLQueryItem(name: "maxResults", value: "250"),
                URLQueryItem(name: "timeMin", value: utc.string(from: from)),
                URLQueryItem(name: "timeMax", value: utc.string(from: to))
            ]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            components.queryItems = query
            guard let url = components.url else { break }

            let page = try await get(url, as: EventsResponse.self)
            for item in page.items ?? [] where item.status != "cancelled" {
                guard let start = parse(item.start), let end = parse(item.end) else { continue }
                results.append(CalendarEvent(id: "\(calendar.id)/\(item.id)",
                                             title: item.summary ?? "(No title)",
                                             start: start,
                                             end: max(end, start),
                                             isAllDay: item.start?.date != nil,
                                             color: calendar.color))
            }
            pageToken = page.nextPageToken
        } while pageToken != nil
        return results
    }

    private static func parse(_ when: EventsResponse.When?) -> Date? {
        if let dateTime = when?.dateTime {
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return plain.date(from: dateTime) ?? fractional.date(from: dateTime)
        }
        if let day = when?.date {
            // All-day events carry a plain date, which means that day in the user's own time zone.
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: day)
        }
        return nil
    }
}

/// High-level operations used by both the app and the widget.
nonisolated enum CalendarService {
    /// Refreshes the calendar list. On first run, selects the calendars ticked in Google Calendar.
    @discardableResult
    static func refreshCalendarList() async throws -> [GoogleCalendarInfo] {
        let fetched = try await CalendarAPI.calendars()
        let infos = fetched.map(\.info)
        SharedStore.calendars = infos

        if SharedStore.selectedCalendarIDs == nil {
            let defaults = fetched.filter { $0.selectedInGoogle || $0.info.isPrimary }.map(\.info.id)
            SharedStore.selectedCalendarIDs = Set(defaults)
        }
        return infos
    }

    /// Events for every visible day of `month`, including the adjacent-month days in the first and last week.
    /// `calendarIDs` overrides the app's selection, which lets a single widget show different calendars.
    static func fetchEvents(for month: Date, calendarIDs: Set<String>? = nil) async throws -> [CalendarEvent] {
        let selected = calendarIDs ?? SharedStore.selectedCalendarIDs ?? []
        let calendars = SharedStore.calendars.filter { selected.contains($0.id) }
        guard !calendars.isEmpty else { return [] }

        let range = MonthLayout.gridRange(for: month, calendar: SharedStore.theme.calendar)

        // One calendar failing (say, a subscribed calendar that went away) shouldn't blank the others.
        let outcomes = await withTaskGroup(of: Result<[CalendarEvent], Error>.self) { group in
            for calendar in calendars {
                group.addTask {
                    do {
                        return .success(try await CalendarAPI.events(in: calendar, from: range.start, to: range.end))
                    } catch {
                        return .failure(error)
                    }
                }
            }
            var all: [Result<[CalendarEvent], Error>] = []
            for await outcome in group { all.append(outcome) }
            return all
        }

        var events: [CalendarEvent] = []
        var firstError: Error?
        var succeeded = false
        for outcome in outcomes {
            switch outcome {
            case .success(let list):
                succeeded = true
                events += list
            case .failure(let error):
                firstError = firstError ?? error
            }
        }
        if !succeeded, let firstError { throw firstError }
        return events
    }
}
