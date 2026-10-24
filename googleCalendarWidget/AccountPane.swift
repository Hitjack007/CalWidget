//
//  AccountPane.swift
//  googleCalendarWidget
//

import SwiftUI

/// The Google sign-in button with progress and any error, used wherever the app asks the user to sign in.
struct SignInButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    Task { await model.signIn() }
                } label: {
                    Label("Sign in with Google", systemImage: "person.badge.key")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isWorking)

                if model.isWorking {
                    ProgressView().controlSize(.small)
                }
            }

            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }
}

struct AccountPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            if model.isSignedIn {
                Section("Google account") {
                    LabeledContent("Signed in as", value: model.accountName ?? "Your Google account")
                    Button("Sign out", role: .destructive) { model.signOut() }
                }
            } else {
                Section("Google account") {
                    Text("Sign in to show your own events in the widget.")
                    SignInButton()
                }
            }

            Section("Access") {
                Label("Read-only. gCalWidget can't create, edit, or delete events.", systemImage: "lock")
                Label("Your calendar data goes straight from Google to your Mac.", systemImage: "desktopcomputer")
                if let url = URL(string: "https://myaccount.google.com/permissions") {
                    Link("Manage access in your Google account", destination: url)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Account")
    }
}
