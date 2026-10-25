//
//  OAuthCallback.swift
//  Shared between the app, the widget extension and the tests.
//

import Foundation

nonisolated enum OAuthCallback {
    /// The query items from the request line of an HTTP request, for example
    /// `GET /?code=abc&state=xyz HTTP/1.1`. Anything that isn't a GET with a path returns no items.
    static func queryItems(fromRequest request: String) -> [URLQueryItem] {
        let firstLine = request.prefix(while: { !$0.isNewline })
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else { return [] }
        return URLComponents(string: "http://127.0.0.1" + parts[1])?.queryItems ?? []
    }

    /// Whether the request is the redirect from Google, as opposed to a stray request such as a favicon fetch.
    static func isRedirect(_ items: [URLQueryItem]) -> Bool {
        items.contains { $0.name == "code" || $0.name == "error" }
    }
}
