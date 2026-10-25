//
//  GoogleConfig.swift
//  Shared between the app and the widget extension.
//

import Foundation

/// The app's Google OAuth client, which is a **Desktop app** client in the Google Cloud Console.
///
/// The client ID identifies the app to Google and is safe to commit. The client secret is kept in
/// `GoogleSecrets.swift`, which git ignores (see `Config/GoogleSecrets.swift.example`). Google says a
/// desktop app's secret can't be kept confidential, because it ships inside the app, and protects
/// sign-in with PKCE instead. Neither value gives access to anyone's data.
nonisolated enum GoogleConfig {
    static let clientID = "430577335186-29tvc8deq0ceg1ie94p6ggppc1q4mru8.apps.googleusercontent.com"
    static var clientSecret: String { GoogleSecrets.clientSecret }

    static var isConfigured: Bool {
        !clientID.hasPrefix("YOUR_CLIENT_ID") && clientID.hasSuffix(".apps.googleusercontent.com")
    }
}
