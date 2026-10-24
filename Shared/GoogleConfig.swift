//
//  GoogleConfig.swift
//  Shared between the app and the widget extension.
//

import Foundation

/// The app's Google OAuth client.
///
/// Create an **iOS**-type OAuth client in the Google Cloud Console, using the app's bundle ID,
/// then paste its client ID below. The client ID identifies the app to Google. It isn't a secret,
/// and iOS-type clients have no client secret.
nonisolated enum GoogleConfig {
    static let clientID = "YOUR_CLIENT_ID.apps.googleusercontent.com"

    static var isConfigured: Bool {
        !clientID.hasPrefix("YOUR_CLIENT_ID") && clientID.hasSuffix(".apps.googleusercontent.com")
    }
}
