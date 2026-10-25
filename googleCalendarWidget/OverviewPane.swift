//
//  OverviewPane.swift
//  googleCalendarWidget
//

import SwiftUI

struct OverviewPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            // Side by side when the window is wide enough, stacked when it isn't.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 32) {
                    WidgetPreview()
                    details
                }
                VStack(alignment: .leading, spacing: 24) {
                    WidgetPreview()
                    details
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle("Overview")
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your widget")
                .font(.title2.bold())

            if !model.isSignedIn {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sign in to see your own events")
                        .font(.headline)
                    Text("The preview shows sample events. Sign in with Google to load your calendars. The app only reads your calendar.")
                        .foregroundStyle(.secondary)
                    SignInButton()
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Add it to your Mac")
                    .font(.headline)
                Label("Right-click your desktop, or open Notification Center", systemImage: "1.circle")
                Label("Choose Edit Widgets and search for “CalWidget”", systemImage: "2.circle")
                Label("Add it, then right-click the widget and choose Edit Widget to change its style or calendars", systemImage: "3.circle")
            }
            .foregroundStyle(.secondary)

            if model.isSignedIn {
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

                if let lastSync = model.lastSync {
                    Text("Last updated \(lastSync, format: .relative(presentation: .named))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if model.isSignedIn, let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .frame(minWidth: 260, maxWidth: 340, alignment: .leading)
    }
}
