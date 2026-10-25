//
//  GeneralPane.swift
//  googleCalendarWidget
//

import SwiftUI
import ServiceManagement

struct GeneralPane: View {
    @Environment(AppModel.self) private var model
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?
    @State private var confirmReset = false

    var body: some View {
        @Bindable var model = model

        Form {
            Section {
                Picker("Check for new events", selection: $model.refreshMinutes) {
                    Text("Every 15 minutes").tag(15)
                    Text("Every 30 minutes").tag(30)
                    Text("Every hour").tag(60)
                    Text("Every 2 hours").tag(120)
                }
            } header: {
                Text("Widget")
            } footer: {
                Text("macOS decides when widgets actually refresh, so updates can arrive a little later than this.")
            }

            Section("App") {
                Toggle("Open at login", isOn: $launchAtLogin)
                if let launchError {
                    Text(launchError)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            #if DEBUG
            Section {
                Toggle("Serve dummy data in the widget", isOn: $model.useDummyData)
                    .onChange(of: model.useDummyData) { model.dummyDataDidChange() }
            } header: {
                Text("Debug")
            } footer: {
                Text("Debug builds only. The widget shows sample events even when you're not signed in. This section doesn't exist in release builds.")
            }
            #endif

            Section {
                Button("Reset appearance to defaults") { model.resetAppearance() }
                Button("Reset all settings…", role: .destructive) { confirmReset = true }
            } header: {
                Text("Reset")
            } footer: {
                Text("Resetting doesn't sign you out or change which calendars are shown.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .onChange(of: model.refreshMinutes) { model.refreshIntervalDidChange() }
        .onChange(of: launchAtLogin) { _, enabled in
            updateLaunchAtLogin(enabled)
        }
        .confirmationDialog("Reset all settings?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { model.resetAllSettings() }
        } message: {
            Text("The widget's look and refresh interval go back to their defaults.")
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        // Skip when the toggle was only reset to match the real state after a failure.
        guard enabled != (SMAppService.mainApp.status == .enabled) else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchError = nil
        } catch {
            launchError = "Couldn't change this setting: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
