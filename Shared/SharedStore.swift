//
//  SharedStore.swift
//  Shared between the app and the widget extension.
//

import Foundation

/// A small property-list file in the user's real home folder, shared by the app and the widget.
///
/// An App Group would need a provisioning profile, and a profile is only valid on the Macs registered
/// to the developer account, so builds signed with a free Apple ID would refuse to launch anywhere else.
/// The app is unsandboxed and the widget reaches this folder through a
/// `files.home-relative-path.read-write` temporary exception, and neither needs a profile.
nonisolated final class SharedFile: @unchecked Sendable {
    /// The folder both processes use. Relative to the real home, which is not the widget's sandbox container.
    static let folderPath = "/Library/Application Support/CalWidget/"

    private let fileURL: URL
    private let lockPath: String
    private let lock = NSLock()

    init(name: String) {
        // NSHomeDirectory() is the container inside the widget's sandbox, so ask the user database instead.
        let home = getpwuid(getuid()).flatMap { String(validatingCString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        let folder = URL(fileURLWithPath: home + Self.folderPath, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        fileURL = folder.appendingPathComponent(name + ".plist")
        lockPath = folder.appendingPathComponent(name + ".lock").path
    }

    /// Runs `body` while holding a lock that spans both processes, so a write in one can't be lost to the other.
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        let descriptor = open(lockPath, O_CREAT | O_RDWR, 0o600)
        if descriptor >= 0 { flock(descriptor, LOCK_EX) }
        defer { if descriptor >= 0 { flock(descriptor, LOCK_UN); close(descriptor) } }
        return body()
    }

    private func load() -> [String: Any] {
        guard let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [:] }
        return plist
    }

    private func store(_ values: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0) else { return }
        try? data.write(to: fileURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    func object(forKey key: String) -> Any? { withLock { load()[key] } }
    func data(forKey key: String) -> Data? { object(forKey: key) as? Data }
    func bool(forKey key: String) -> Bool { object(forKey: key) as? Bool ?? false }
    func integer(forKey key: String) -> Int { object(forKey: key) as? Int ?? 0 }

    func set(_ value: Any?, forKey key: String) {
        withLock {
            var values = load()
            values[key] = value
            store(values)
        }
    }

    func removeObject(forKey key: String) { set(nil, forKey: key) }
}

/// Settings and cached data shared by the app and the widget through a file in the user's home folder.
nonisolated enum SharedStore {
    private static let defaults = SharedFile(name: "shared")

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

/// OAuth tokens shared by the app and the widget. They live in a file only the user can read, because a keychain
/// access group would need a provisioning profile, which a build signed with a free Apple ID can't carry to other Macs.
nonisolated enum CredentialStore {
    private static let file = SharedFile(name: "credentials")

    @discardableResult
    static func save(_ data: Data, account: String) -> Bool {
        file.set(data, forKey: account)
        return file.data(forKey: account) == data
    }

    static func load(account: String) -> Data? {
        file.data(forKey: account)
    }

    static func delete(account: String) {
        file.removeObject(forKey: account)
    }
}
