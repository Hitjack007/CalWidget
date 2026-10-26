//
//  AboutPane.swift
//  googleCalendarWidget
//

import SwiftUI
import AppKit

struct AboutPane: View {
    var body: some View {
        Form {
            AppInfoSection()
            UpdatesSection()
            LinksSection()
            LegalSection()
        }
        .formStyle(.grouped)
        .navigationTitle("About")
    }
}

private struct AppInfoSection: View {
    @State private var showBuildNumber = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var body: some View {
        Section {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("CalWidget")
                        .font(.headline)

                    Text("Your Google Calendar, as a macOS widget")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Click the version to show the build number.
                    HStack(spacing: 4) {
                        Text("Version \(version)")
                            .foregroundStyle(.secondary)
                        if showBuildNumber {
                            Text("(\(build))")
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                        }
                    }
                    .onTapGesture {
                        withAnimation { showBuildNumber.toggle() }
                    }
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}

private struct UpdatesSection: View {
    @Environment(AppModel.self) private var model
    @Environment(SoftwareUpdater.self) private var updater
    @AppStorage(LaunchState.showWhatsNewKey) private var showWhatsNew = true

    var body: some View {
        @Bindable var updater = updater

        Section("Updates") {
            Toggle("Automatically check for updates", isOn: $updater.automaticallyChecksForUpdates)
            Toggle("Automatically download updates", isOn: $updater.automaticallyDownloadsUpdates)
                .disabled(!updater.automaticallyChecksForUpdates)
            Toggle("Show what's new after updating", isOn: $showWhatsNew)

            HStack {
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)

                let highlights = LaunchState.currentHighlights()
                if !highlights.isEmpty {
                    Button("Show What's New") {
                        AppWindows.shared.showWhatsNew(pages: highlights, model: model)
                    }
                }
            }
        }
    }
}

private struct LinksSection: View {
    var body: some View {
        Section("Links") {
            link("Privacy Policy", "https://github.com/Hitjack007/googleCalendarWidget/blob/main/docs/privacy.md")
            link("Support", "https://github.com/Hitjack007/googleCalendarWidget/blob/main/docs/support.md")
            link("Source code on GitHub", "https://github.com/Hitjack007/googleCalendarWidget")
        }
    }

    @ViewBuilder
    private func link(_ title: String, _ address: String) -> some View {
        if let url = URL(string: address) {
            Link(title, destination: url)
        }
    }
}

private struct LegalSection: View {
    var body: some View {
        Section {
            Text("CalWidget is free and open source. It isn't affiliated with or endorsed by Google. Google Calendar is a trademark of Google LLC.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    AboutPane()
        .environment(AppModel())
        .environment(SoftwareUpdater())
        .frame(width: 500, height: 600)
}
