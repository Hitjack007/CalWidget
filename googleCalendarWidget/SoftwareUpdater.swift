//
//  SoftwareUpdater.swift
//  googleCalendarWidget
//

import SwiftUI
import Sparkle

/// Wraps Sparkle so SwiftUI can observe whether a check is possible and edit the automatic update settings.
@MainActor
@Observable
final class SoftwareUpdater {
    private let controller = SPUStandardUpdaterController(startingUpdater: true,
                                                          updaterDelegate: nil,
                                                          userDriverDelegate: nil)
    private var observation: NSKeyValueObservation?

    private(set) var canCheckForUpdates = false

    var automaticallyChecksForUpdates: Bool {
        didSet { controller.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates }
    }

    var automaticallyDownloadsUpdates: Bool {
        didSet { controller.updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates }
    }

    init() {
        let updater = controller.updater
        canCheckForUpdates = updater.canCheckForUpdates
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
        observation = updater.observe(\.canCheckForUpdates) { [weak self] updater, _ in
            let canCheck = updater.canCheckForUpdates
            Task { @MainActor in self?.canCheckForUpdates = canCheck }
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
