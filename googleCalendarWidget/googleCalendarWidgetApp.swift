//
//  googleCalendarWidgetApp.swift
//  googleCalendarWidget
//
//  Created by Mark Greene on 25/10/2026.
//

import SwiftUI

@main
struct googleCalendarWidgetApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("gCalWidget") {
            ContentView()
                .environment(model)
                .frame(minWidth: 980, minHeight: 600)
        }
        .defaultSize(width: 1040, height: 680)
    }
}
