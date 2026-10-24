//
//  CalendarsPane.swift
//  googleCalendarWidget
//

import SwiftUI

struct CalendarsPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if !model.isSignedIn {
                ContentUnavailableView {
                    Label("Sign in to choose calendars", systemImage: "calendar.badge.exclamationmark")
                } description: {
                    Text("Pick which of your Google calendars appear in the widget.")
                } actions: {
                    SignInButton()
                }
            } else if model.calendars.isEmpty {
                ContentUnavailableView {
                    Label("No calendars yet", systemImage: "calendar")
                } description: {
                    Text("Refresh to load your calendars from Google.")
                } actions: {
                    Button("Refresh") { Task { await model.refreshAll() } }
                }
            } else {
                Form {
                    Section("Show in widget") {
                        ForEach(model.calendars) { calendar in
                            Toggle(isOn: Binding(get: { model.selectedIDs.contains(calendar.id) },
                                                 set: { model.setCalendar(calendar, enabled: $0) })) {
                                Label {
                                    Text(calendar.name)
                                } icon: {
                                    Circle().fill(calendar.color.color).frame(width: 10, height: 10)
                                }
                            }
                        }
                    }
                }
                .formStyle(.grouped)
            }
        }
        .navigationTitle("Calendars")
    }
}
