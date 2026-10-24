//
//  AboutPane.swift
//  googleCalendarWidget
//

import SwiftUI

struct AboutPane: View {
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: version)
            }

            Section("Links") {
                link("Privacy Policy", "https://github.com/Hitjack007/googleCalendarWidget/blob/main/docs/privacy.md")
                link("Support", "https://github.com/Hitjack007/googleCalendarWidget/blob/main/docs/support.md")
                link("Source code on GitHub", "https://github.com/Hitjack007/googleCalendarWidget")
            }

            Section {
                Text("gCalWidget is free and open source. It isn't affiliated with or endorsed by Google. Google Calendar is a trademark of Google LLC.")
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
