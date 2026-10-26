//
//  GeneralPane.swift
//  googleCalendarWidget
//

import SwiftUI
import ServiceManagement

struct GeneralPane: View {
    var body: some View {
        Form {
            SystemSection()
            WidgetSection()
            ResetSection()
            #if DEBUG
            DebugSection()
            #endif
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }
}

private struct SystemSection: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?

    var body: some View {
        Section("System") {
            Toggle("Open at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    updateLaunchAtLogin(enabled)
                }
            if let launchError {
                Text(launchError)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
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

private struct WidgetSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        Section {
            Picker("Check for new events", selection: $model.refreshMinutes) {
                Text("Every 15 minutes").tag(15)
                Text("Every 30 minutes").tag(30)
                Text("Every hour").tag(60)
                Text("Every 2 hours").tag(120)
            }
            .onChange(of: model.refreshMinutes) { model.refreshIntervalDidChange() }

            Picker("Week starts on", selection: $model.theme.weekStart) {
                Text("System default").tag(0)
                Text("Sunday").tag(1)
                Text("Monday").tag(2)
                Text("Saturday").tag(7)
            }

            Toggle("Show + button", isOn: $model.theme.showPlusButton)
        } header: {
            Text("Widget")
        } footer: {
            Text("macOS decides when widgets actually refresh, so updates can arrive a little later than this. To change a widget's style (Automatic, Light or Dark) or its calendars, right-click it and choose Edit Widget.")
        }
    }
}

private struct ResetSection: View {
    @Environment(AppModel.self) private var model
    @State private var confirmReset = false

    var body: some View {
        Section {
            Button("Reset all settings…", role: .destructive) { confirmReset = true }
        } header: {
            Text("Reset")
        } footer: {
            Text("Resetting doesn't sign you out or change which calendars are shown.")
        }
        .confirmationDialog("Reset all settings?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { model.resetAllSettings() }
        } message: {
            Text("The refresh interval, week start, + button and how events open go back to their defaults.")
        }
    }
}

#if DEBUG
private struct DebugSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        Section {
            Toggle("Serve dummy data in the widget", isOn: $model.useDummyData)
                .onChange(of: model.useDummyData) { model.dummyDataDidChange() }
        } header: {
            Text("Debug")
        } footer: {
            Text("Debug builds only. The widget shows sample events even when you're not signed in. This section doesn't exist in release builds.")
        }
    }
}
#endif

#Preview {
    GeneralPane()
        .environment(AppModel())
        .frame(width: 500, height: 600)
}
