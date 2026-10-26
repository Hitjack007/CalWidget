//
//  WhatsNewCatalog.swift
//  googleCalendarWidget
//

import Foundation

struct WhatsNewHighlight: Identifiable {
    /// A stable slug, e.g. "openEvents".
    let id: String
    /// An SF Symbol name.
    let icon: String
    let title: LocalizedStringResource
    let body: LocalizedStringResource
    var action: WhatsNewAction?
}

enum WhatsNewAction {
    /// Opens one of the app's sidebar panes, by its title (for example "General").
    case openPane(String, label: LocalizedStringResource)
}

struct WhatsNewRelease {
    let version: String
    let highlights: [WhatsNewHighlight]
}

struct WhatsNewPage: Identifiable {
    let version: String
    let highlight: WhatsNewHighlight
    var id: String { "\(version)-\(highlight.id)" }
}

enum WhatsNewCatalog {
    /// Newest last. Add an entry here before running `release.sh` for a release that ships something new.
    static let releases: [WhatsNewRelease] = [
        WhatsNewRelease(
            version: "1.1",
            highlights: [
                WhatsNewHighlight(
                    id: "openEvents",
                    icon: "arrow.up.forward.app",
                    title: "Click an Event to Open It",
                    body: "Click any event in the widget to open it in Google Calendar."
                ),
            ]
        ),
    ]

    /// Compares two version strings numerically, so "1.9" < "1.10" and "1.2" < "1.2.1".
    static func isVersion(_ a: String, newerThan b: String) -> Bool {
        a.compare(b, options: .numeric) == .orderedDescending
    }

    /// Pages to show on the first launch after an update, oldest version first.
    ///
    /// An empty `lastSeenVersion` means an existing user is upgrading into this feature with nothing
    /// recorded yet, so only the release matching `currentVersion` is shown, not the whole backlog.
    static func pages(lastSeenVersion: String,
                      currentVersion: String,
                      releases: [WhatsNewRelease] = WhatsNewCatalog.releases) -> [WhatsNewPage] {
        let eligible: [WhatsNewRelease]
        if lastSeenVersion.isEmpty {
            eligible = releases.filter { $0.version == currentVersion }
        } else {
            eligible = releases.filter {
                isVersion($0.version, newerThan: lastSeenVersion) && !isVersion($0.version, newerThan: currentVersion)
            }
        }
        return eligible
            .sorted { isVersion($1.version, newerThan: $0.version) }
            .flatMap { release in release.highlights.map { WhatsNewPage(version: release.version, highlight: $0) } }
    }
}

/// What to show at launch: the first-launch tour or the What's New pages.
enum LaunchAction {
    case onboarding
    case whatsNew([WhatsNewPage])
}

/// What the app remembers about onboarding and What's New. These are the app's own settings,
/// so they live in standard defaults, not the store shared with the widget.
enum LaunchState {
    private static let onboardingKey = "hasCompletedOnboarding"
    private static let lastSeenKey = "lastWhatsNewVersionSeen"
    static let showWhatsNewKey = "showWhatsNewOnUpdate"

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingKey) }
    }

    static var lastWhatsNewVersionSeen: String {
        get { UserDefaults.standard.string(forKey: lastSeenKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: lastSeenKey) }
    }

    static var showsWhatsNewOnUpdate: Bool {
        UserDefaults.standard.object(forKey: showWhatsNewKey) as? Bool ?? true
    }

    /// What to show at launch, if anything. A first launch gets onboarding and skips What's New,
    /// since there's nothing to introduce a new user to.
    static func launchAction() -> LaunchAction? {
        if !hasCompletedOnboarding && lastWhatsNewVersionSeen.isEmpty {
            return .onboarding
        }
        guard showsWhatsNewOnUpdate else { return nil }
        let pages = WhatsNewCatalog.pages(lastSeenVersion: lastWhatsNewVersionSeen, currentVersion: currentVersion)
        return pages.isEmpty ? nil : .whatsNew(pages)
    }

    /// Pages for the running version, whatever has been seen. Used by the About pane's button.
    static func currentHighlights() -> [WhatsNewPage] {
        WhatsNewCatalog.pages(lastSeenVersion: "", currentVersion: currentVersion)
    }

    #if DEBUG
    /// The newest catalog entry's pages, even if the running version hasn't been bumped to match yet.
    static func latestHighlights() -> [WhatsNewPage] {
        guard let latest = WhatsNewCatalog.releases.last else { return [] }
        return latest.highlights.map { WhatsNewPage(version: latest.version, highlight: $0) }
    }

    /// Forgets onboarding and What's New, so the next launch behaves like a fresh install.
    static func reset() {
        UserDefaults.standard.removeObject(forKey: onboardingKey)
        UserDefaults.standard.removeObject(forKey: lastSeenKey)
    }
    #endif

    static func finishOnboarding() {
        hasCompletedOnboarding = true
        lastWhatsNewVersionSeen = currentVersion
    }

    static func finishWhatsNew() {
        lastWhatsNewVersionSeen = currentVersion
    }
}
