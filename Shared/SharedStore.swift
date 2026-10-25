//
//  SharedStore.swift
//  Shared between the app and the widget extension.
//

import Foundation
import Security

/// Identifiers injected into each target's Info.plist from the team prefix, so the project works under any developer team.
nonisolated enum AppGroup {
    static var identifier: String? {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
    }

    static var keychainGroup: String? {
        Bundle.main.object(forInfoDictionaryKey: "KeychainAccessGroup") as? String
    }

    static var defaults: UserDefaults {
        identifier.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }
}

/// Settings and cached data shared by the app and the widget through the App Group.
nonisolated enum SharedStore {
    private static var defaults: UserDefaults { AppGroup.defaults }

    private static func read<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    private static func write<T: Encodable>(_ value: T?, key: String) {
        guard let value else {
            defaults.removeObject(forKey: key)
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try? encoder.encode(value), forKey: key)
    }

    // MARK: Settings

    static var theme: WidgetTheme {
        get { read(WidgetTheme.self, key: "theme") ?? .standard }
        set { write(newValue, key: "theme") }
    }

    /// How often the widget asks Google for fresh events, in minutes.
    static var refreshMinutes: Int {
        get {
            let stored = defaults.integer(forKey: "refreshMinutes")
            return stored == 0 ? 30 : stored
        }
        set { defaults.set(newValue, forKey: "refreshMinutes") }
    }

    static var calendars: [GoogleCalendarInfo] {
        get { read([GoogleCalendarInfo].self, key: "calendars") ?? [] }
        set { write(newValue, key: "calendars") }
    }

    /// IDs of the calendars shown in the widget. nil means the user hasn't chosen yet.
    static var selectedCalendarIDs: Set<String>? {
        get { read([String].self, key: "selectedCalendarIDs").map(Set.init) }
        set { write(newValue.map { Array($0) }, key: "selectedCalendarIDs") }
    }

    static var lastSync: Date? {
        get { defaults.object(forKey: "lastSync") as? Date }
        set { defaults.set(newValue, forKey: "lastSync") }
    }

    // MARK: Debugging

    #if DEBUG
    /// Debug builds only: makes the widget show dummy data whether or not you're signed in.
    static var useDummyData: Bool {
        get { defaults.bool(forKey: "debugUseDummyData") }
        set { defaults.set(newValue, forKey: "debugUseDummyData") }
    }
    #else
    static var useDummyData: Bool { false }
    #endif

    // MARK: Month navigation

    /// How many months the widget's arrows have moved away from the current month.
    /// Expires after ten minutes so the widget returns to the current month by itself.
    static var monthOffset: Int {
        let offset = defaults.integer(forKey: "monthOffset")
        guard offset != 0,
              let changed = defaults.object(forKey: "monthOffsetDate") as? Date,
              Date().timeIntervalSince(changed) < 600 else { return 0 }
        return offset
    }

    static func shiftMonthOffset(by delta: Int) {
        defaults.set(monthOffset + delta, forKey: "monthOffset")
        defaults.set(Date(), forKey: "monthOffsetDate")
    }

    // MARK: Event cache

    private static func monthKey(_ month: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month], from: month)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    /// Cache keys combine the month with a scope. A widget that overrides the calendars or week start
    /// gets its own scope, because it fetches a different set of events. An empty scope is the app's own.
    private static func cacheKey(_ month: Date, scope: String) -> String {
        scope.isEmpty ? monthKey(month) : monthKey(month) + "|" + scope
    }

    static func cachedEvents(for month: Date, scope: String = "") -> [CalendarEvent]? {
        read([String: [CalendarEvent]].self, key: "eventCache")?[cacheKey(month, scope: scope)]
    }

    static func cache(_ events: [CalendarEvent], for month: Date, scope: String = "") {
        var all = read([String: [CalendarEvent]].self, key: "eventCache") ?? [:]
        all[cacheKey(month, scope: scope)] = events
        // Keep the cache small: drop the oldest entries beyond a dozen.
        for key in all.keys.sorted().dropLast(12) { all[key] = nil }
        write(all, key: "eventCache")
        lastSync = Date()
    }

    /// Removes everything tied to the signed-in account. The widget's look is kept.
    static func clearAccountData() {
        for key in ["calendars", "selectedCalendarIDs", "eventCache", "lastSync", "monthOffset", "monthOffsetDate"] {
            defaults.removeObject(forKey: key)
        }
    }
}

/// Thin wrapper over the data-protection keychain, shared by the app and widget through a keychain access group.
nonisolated enum KeychainStore {
    private static let service = "com.hitjack007.calwidget"

    private static func baseQuery(account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true
        ]
        if let group = AppGroup.keychainGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        return query
    }

    @discardableResult
    static func save(_ data: Data, account: String) -> Bool {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load(account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }
}
