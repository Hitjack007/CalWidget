//
//  AppWindows.swift
//  googleCalendarWidget
//

import SwiftUI
import AppKit

/// Owns the small fixed-size windows: onboarding and What's New. Each is a plain 400 x 600 window
/// with a transparent title bar, centered on screen, and kept out of window restoration.
@MainActor
final class AppWindows {
    static let shared = AppWindows()

    private static let pageSize = NSSize(width: 400, height: 600)

    private var onboardingController: NSWindowController?
    private var whatsNewController: NSWindowController?

    private init() {}

    /// Shows what the launch state calls for. On first launch that's only onboarding, and the main window
    /// opens when it finishes. Otherwise the main window opens, with What's New over it after an update.
    ///
    /// `opensMainWindow` is false when the app was launched just to handle a link, such as a click on a
    /// widget event. Then it stays out of the way, unless onboarding or What's New is due.
    func presentLaunchWindows(model: AppModel, opensMainWindow: Bool = true) {
        switch LaunchState.launchAction() {
        case .onboarding:
            showOnboarding(model: model)
        case .whatsNew(let pages):
            if opensMainWindow { SettingsWindowController.shared.present() }
            showWhatsNew(pages: pages, model: model)
        case nil:
            if opensMainWindow { SettingsWindowController.shared.present() }
        }
    }

    /// Brings the onboarding window forward if it's open. Returns whether it was.
    func bringOnboardingForward() -> Bool {
        guard let window = onboardingController?.window else { return false }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return true
    }

    func showOnboarding(model: AppModel) {
        if onboardingController == nil {
            let window = makeWindow(title: "Onboarding", identifier: "OnboardingWindow")
            window.contentView = NSHostingView(rootView: OnboardingView(
                onFinish: { [weak self] in
                    LaunchState.finishOnboarding()
                    self?.closeOnboarding()
                    SettingsWindowController.shared.present()
                },
                onOpenPane: { [weak self] pane in
                    self?.showMainWindow(selecting: pane, model: model)
                })
                .environment(model))
            onboardingController = NSWindowController(window: window)
        }
        present(onboardingController)
    }

    func showWhatsNew(pages: [WhatsNewPage], model: AppModel) {
        guard !pages.isEmpty else { return }
        whatsNewController?.close()
        let window = makeWindow(title: "What's New", identifier: "WhatsNewWindow")
        window.contentView = NSHostingView(rootView: WhatsNewView(
            pages: pages,
            onFinish: { [weak self] in
                LaunchState.finishWhatsNew()
                self?.whatsNewController?.close()
                self?.whatsNewController = nil
            },
            onOpenPane: { [weak self] pane in
                self?.showMainWindow(selecting: pane, model: model)
            }))
        whatsNewController = NSWindowController(window: window)
        present(whatsNewController)
    }

    private func closeOnboarding() {
        onboardingController?.close()
        onboardingController = nil
    }

    /// Brings the main window forward and opens one of its panes.
    private func showMainWindow(selecting pane: String, model: AppModel) {
        model.requestedPane = pane
        SettingsWindowController.shared.present()
    }

    private func makeWindow(title: String, identifier: String) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: Self.pageSize),
                              styleMask: [.titled, .fullSizeContentView],
                              backing: .buffered,
                              defer: false)
        window.center()
        window.title = title
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier(identifier)
        return window
    }

    private func present(_ controller: NSWindowController?) {
        NSApp.showInDock()
        NSApp.activate(ignoringOtherApps: true)
        controller?.window?.makeKeyAndOrderFront(nil)
        controller?.window?.orderFrontRegardless()
    }
}
