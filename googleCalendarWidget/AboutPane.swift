//
//  AboutPane.swift
//  googleCalendarWidget
//

import SwiftUI
import AppKit

struct AboutPane: View {
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CalWidget")
                            .font(.title2.bold())
                        Text("Version \(version)")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Links") {
                link("Privacy Policy", "https://github.com/Hitjack007/googleCalendarWidget/blob/main/docs/privacy.md")
                link("Support", "https://github.com/Hitjack007/googleCalendarWidget/blob/main/docs/support.md")
                link("Source code on GitHub", "https://github.com/Hitjack007/googleCalendarWidget")
            }

            Section {
                Text("CalWidget is free and open source. It isn't affiliated with or endorsed by Google. Google Calendar is a trademark of Google LLC.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("About")
    }

    @ViewBuilder
    private func link(_ title: String, _ address: String) -> some View {
        if let url = URL(string: address) {
            Link(title, destination: url)
        }
    }
}
