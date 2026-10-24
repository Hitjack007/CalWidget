//
//  GoogleSignIn.swift
//  googleCalendarWidget
//
//  Interactive Google sign-in: OAuth 2.0 authorization code flow with PKCE, run in the system web
//  authentication sheet. Uses an iOS-type client ID, which needs no client secret.
//

import AuthenticationServices
import AppKit
import CryptoKit

enum GoogleSignIn {
    private static let clientIDSuffix = ".apps.googleusercontent.com"

    static func isValid(clientID: String) -> Bool {
        clientID.hasSuffix(clientIDSuffix) && clientID.count > clientIDSuffix.count
    }

    /// Google's iOS-type clients redirect to the reversed client ID.
    static func redirectScheme(for clientID: String) -> String {
        "com.googleusercontent.apps." + clientID.replacingOccurrences(of: clientIDSuffix, with: "")
    }

    @MainActor
    static func signIn(clientID: String) async throws -> TokenSet {
        let scheme = redirectScheme(for: clientID)
        let redirectURI = "\(scheme):/oauth2redirect"
        let verifier = randomURLSafeString(byteCount: 48)
        let state = randomURLSafeString(byteCount: 16)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded

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
        guard let authURL = components?.url else { throw GoogleAPIError.invalidResponse }

        let callback = try await WebAuthenticator().authenticate(url: authURL, callbackScheme: scheme)
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []

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
    case keychainFailed

    var errorDescription: String? {
        switch self {
        case .denied(let reason): "Google didn't allow sign-in (\(reason))."
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

/// Wraps `ASWebAuthenticationSession` in async/await and supplies the window it presents from.
@MainActor
private final class WebAuthenticator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callback: .customScheme(callbackScheme)) { @Sendable callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: error ?? GoogleAPIError.invalidResponse)
                }
            }
            session.presentationContextProvider = self
            self.session = session
            if !session.start() {
                continuation.resume(throwing: GoogleAPIError.invalidResponse)
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
    }
}
