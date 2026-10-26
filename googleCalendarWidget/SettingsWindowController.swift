//
//  SettingsWindowController.swift
//  googleCalendarWidget
//

import AppKit
import SwiftUI

/// The main window. It's an AppKit window, not a SwiftUI scene, so its size and behavior are fixed here:
/// 700 x 600 to start, resizable in height, and a single instance that widget taps and the menu reuse.
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        configure(window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure(_ window: NSWindow) {
        window.title = "CalWidget"
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.toolbarStyle = .unified
        window.isMovableByWindowBackground = true

        // Behave like a regular app window, with proper Spaces support.
        window.collectionBehavior = [.managed, .participatesInCycle, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.isExcludedFromWindowsMenu = false
        window.isReleasedWhenClosed = false

        // Always open at the standard size, not wherever it was last dragged.
        window.isRestorable = false
        window.identifier = NSUserInterfaceItemIdentifier("CalWidgetSettingsWindow")
        window.delegate = self
    }

    /// Sets what the window shows. Called once at launch, before the window is first presented.
    func install(model: AppModel, updater: SoftwareUpdater) {
        window?.contentView = NSHostingView(rootView: ContentView()
            .environment(model)
            .environment(updater))
    }

    /// Shows the window, or brings it forward if it's already open.
    func present() {
        guard let window else { return }
        if !window.isVisible {
            window.setContentSize(NSSize(width: 700, height: 600))
            window.center()
        }
        NSApp.showInDock()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

extension NSApplication {
    /// CalWidget is a menu bar app (`LSUIElement`), so it has no Dock icon or app menu until a window opens.
    /// Call this before showing one.
    func showInDock() {
        setActivationPolicy(.regular)
    }

    /// Goes back to menu-bar-only once no titled window is open (the main window, onboarding, What's New,
    /// or an update window from Sparkle).
    func hideFromDockIfNoWindows() {
        guard !windows.contains(where: { ($0.isVisible || $0.isMiniaturized) && $0.styleMask.contains(.titled) }) else { return }
        setActivationPolicy(.accessory)
    }
}
