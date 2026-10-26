//
//  googleCalendarWidgetApp.swift
//  googleCalendarWidget
//
//  Created by Mark Greene on 25/10/2026.
//

import SwiftUI
import AppKit

@main
struct googleCalendarWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The window itself is AppKit (SettingsWindowController), so the only scene is a placeholder
        // that carries the menu commands. It must never appear: it would be a blank "CalWidget Settings" window.
        Settings { EmptyView() }
            .defaultLaunchBehavior(.suppressed)
            .restorationBehavior(.disabled)
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Settings…") { SettingsWindowController.shared.present() }
                        .keyboardShortcut(",", modifiers: .command)
                }
                CommandGroup(after: .appInfo) {
                    Button("Check for Updates…") { appDelegate.updater.checkForUpdates() }
                        .disabled(!appDelegate.updater.canCheckForUpdates)
                }
            }

        // CalWidget lives in the menu bar and only shows in the Dock while a window is open.
        MenuBarExtra("CalWidget", systemImage: "calendar") {
            Button("Settings…") {
                SettingsWindowController.shared.present()
            }
            .keyboardShortcut(",", modifiers: .command)
            Button("Check for Updates…") { appDelegate.updater.checkForUpdates() }
                .disabled(!appDelegate.updater.canCheckForUpdates)
            #if DEBUG
            // Debug builds only: shortcuts for trying out the first-launch flows.
            Divider()
            Button("Show Onboarding") {
                AppWindows.shared.showOnboarding(model: appDelegate.model)
            }
            Button("Show What's New") {
                AppWindows.shared.showWhatsNew(pages: LaunchState.latestHighlights(), model: appDelegate.model)
            }
            Button("Reset Onboarding and What's New") {
                LaunchState.reset()
            }
            #endif
            Divider()
            Button("Quit CalWidget") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    let updater = SoftwareUpdater()

    /// When the last widget link was handled. A link can make macOS ask the app to "reopen", which would
    /// otherwise open the main window.
    private var lastLinkHandled = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsWindowController.shared.install(model: model, updater: updater)
        // A widget click launches the app with a link to handle, not to show a window for.
        let isDefaultLaunch = notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool ?? true
        AppWindows.shared.presentLaunchWindows(model: model, opensMainWindow: isDefaultLaunch)

        // Once the last window closes, go back to being menu-bar-only. The check waits a turn because the
        // closing window still counts as visible while this fires.
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { _ in
            DispatchQueue.main.async { NSApp.hideFromDockIfNoWindows() }
        }
    }

    /// Opening the app again (from Finder or Spotlight) with no window open brings back the main window,
    /// or onboarding if it isn't done.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let handlingLink = Date().timeIntervalSince(lastLinkHandled) < 2
        if !flag, !handlingLink, !AppWindows.shared.bringOnboardingForward() {
            SettingsWindowController.shared.present()
        }
        // False, because true lets SwiftUI do its own reopen, which opens the placeholder scene above.
        return false
    }

    /// macOS delivers a widget's links to the app, not the browser, so the app passes them on. AppKit's own
    /// `application(_:open:)` isn't reliably called for web links, so ask for the raw URL event, and do it
    /// this early so it isn't missed when the click is what launches the app.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self,
                                                     andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
                                                     forEventClass: AEEventClass(kInternetEventClass),
                                                     andEventID: AEEventID(kAEGetURL))
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: string) else { return }
        openInBrowser([url])
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        openInBrowser(urls)
    }

    /// Passes web links on to the browser without opening the main window.
    private func openInBrowser(_ urls: [URL]) {
        lastLinkHandled = Date()
        for url in urls {
            guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else { continue }
            NSWorkspace.shared.open(url)
        }
    }
}
