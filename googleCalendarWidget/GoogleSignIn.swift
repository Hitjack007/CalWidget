//
//  GoogleSignIn.swift
//  googleCalendarWidget
//
//  Interactive Google sign-in for a macOS desktop app, following Google's guidance for native apps:
//  the OAuth 2.0 authorization code flow with PKCE, opened in the user's default browser, with the
//  response delivered to a loopback address (http://127.0.0.1:<port>) that the app listens on briefly.
//  Custom URL schemes aren't used, because Google no longer supports them for this.
//

import AppKit
import Network
import CryptoKit

enum GoogleSignIn {
    private static let clientIDSuffix = ".apps.googleusercontent.com"
    private static let timeout: Duration = .seconds(300)

    static func isValid(clientID: String) -> Bool {
        clientID.hasSuffix(clientIDSuffix) && clientID.count > clientIDSuffix.count
    }

    @MainActor
    static func signIn(clientID: String) async throws -> TokenSet {
        let verifier = randomURLSafeString(byteCount: 48)
        let state = randomURLSafeString(byteCount: 16)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded

        let server = LoopbackServer()
        defer { server.stop() }
        let port = try await server.start()
        let redirectURI = "http://127.0.0.1:\(port)"

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GoogleAuth.scope),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            // Offline access plus a consent prompt makes Google return a refresh token every time.
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        guard let authURL = components?.url, NSWorkspace.shared.open(authURL) else {
            throw SignInError.couldNotOpenBrowser
        }

        // Give up if the user wanders off, so the app doesn't listen forever.
        let timeoutTask = Task {
            try await Task.sleep(for: timeout)
            server.stop(with: SignInError.timedOut)
        }
        defer { timeoutTask.cancel() }

        let items = try await withTaskCancellationHandler {
            try await server.waitForRedirect()
        } onCancel: {
            server.stop()
        }

        if let error = items.first(where: { $0.name == "error" })?.value {
            throw SignInError.denied(error)
        }
        guard items.first(where: { $0.name == "state" })?.value == state,
              let code = items.first(where: { $0.name == "code" })?.value else {
            throw GoogleAPIError.invalidResponse
        }
        return try await GoogleAuth.exchange(code: code, verifier: verifier, redirectURI: redirectURI, clientID: clientID)
    }

    private static func randomURLSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return Data(bytes).base64URLEncoded
    }
}

enum SignInError: LocalizedError {
    case denied(String)
    case couldNotOpenBrowser
    case timedOut
    case keychainFailed

    var errorDescription: String? {
        switch self {
        case .denied(let reason): "Google didn't allow sign-in (\(reason))."
        case .couldNotOpenBrowser: "Couldn't open your web browser to sign in."
        case .timedOut: "Sign-in took too long and was stopped. Try again."
        case .keychainFailed: "Signed in, but the sign-in couldn't be saved to the Keychain."
        }
    }
}

private extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
