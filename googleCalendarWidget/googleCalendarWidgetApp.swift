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
    @State private var model = AppModel()
    @State private var updater = SoftwareUpdater()

    var body: some Scene {
        // A single window: a widget tap that launches the app must never open a second one.
        Window("CalWidget", id: "main") {
            ContentView()
                .environment(model)
                .environment(updater)
                .frame(minWidth: 980, minHeight: 600)
                .onOpenURL { url in
                    // The widget's + button hands its web link to the app. Pass it on to the browser.
                    guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return }
                    NSWorkspace.shared.open(url)
                }
        }
        .defaultSize(width: 1040, height: 680)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            }
        }
    }
}
