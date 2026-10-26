//
//  OverviewPane.swift
//  googleCalendarWidget
//

import SwiftUI

struct OverviewPane: View {
    var body: some View {
        Form {
            PreviewSection()
            CalendarStatusSection()
            AddWidgetSection()
        }
        .formStyle(.grouped)
        .navigationTitle("Overview")
    }
}

/// The widget as it looks right now, drawn with the same view the widget uses.
private struct PreviewSection: View {
    var body: some View {
        Section {
            WidgetPreview()
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }
}

/// Whether CalWidget is connected to Google, and when it last loaded events.
private struct CalendarStatusSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.isSignedIn {
            Section("Your calendar") {
                LabeledContent("Signed in as", value: model.accountName ?? "Your Google account")

                LabeledContent("Last updated") {
                    if let lastSync = model.lastSync {
                        Text(lastSync, format: .relative(presentation: .named))
                    } else {
                        Text("Never")
                    }
                }

                HStack {
                    Button {
                        Task { await model.refreshAll() }
                    } label: {
                        Label("Refresh now", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.isWorking)

                    if model.isWorking {
                        ProgressView().controlSize(.small)
                    }
                }

                if let error = model.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        } else {
            Section {
                Text("The preview shows sample events. Sign in with Google to load your own calendars. CalWidget only reads your calendar.")
                    .foregroundStyle(.secondary)
                SignInButton()
            } header: {
                Text("Sign in to see your own events")
            }
        }
    }
}

private struct AddWidgetSection: View {
    var body: some View {
        Section("Add it to your Mac") {
            Label("Right-click your desktop, or open Notification Center", systemImage: "1.circle")
            Label("Choose Edit Widgets and search for “CalWidget”", systemImage: "2.circle")
            Label("Add it, then right-click the widget and choose Edit Widget to change its style or calendars", systemImage: "3.circle")
        }
    }
}

#Preview {
    OverviewPane()
        .environment(AppModel())
        .frame(width: 500, height: 600)
}
