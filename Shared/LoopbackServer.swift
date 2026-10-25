//
//  LoopbackServer.swift
//  Shared between the app and the tests.
//

import Foundation
import Network

/// A tiny HTTP server, bound to the loopback interface only, that waits for Google's redirect.
/// It accepts one real redirect, answers it with a short "you can close this tab" page, and shuts down.
final class LoopbackServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.hitjack007.calwidget.loopback")

    // Everything below is only touched on `queue`.
    private var listener: NWListener?
    private var portContinuation: CheckedContinuation<UInt16, Error>?
    private var redirectContinuation: CheckedContinuation<[URLQueryItem], Error>?
    private var pendingResult: Result<[URLQueryItem], Error>?

    /// Starts listening on a free port of 127.0.0.1 and returns that port.
    func start() async throws -> UInt16 {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)

        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.listener = listener
                self.portContinuation = continuation
                listener.stateUpdateHandler = { [weak self] state in self?.stateChanged(state) }
                listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
                listener.start(queue: self.queue)
            }
        }
    }

    /// Waits for Google's redirect and returns its query items.
    func waitForRedirect() async throws -> [URLQueryItem] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if let pending = self.pendingResult {
                    self.pendingResult = nil
                    continuation.resume(with: pending)
                } else {
                    self.redirectContinuation = continuation
                }
            }
        }
    }

    func stop(with error: Error = CancellationError()) {
        queue.async {
            self.listener?.cancel()
            self.listener = nil
            self.deliver(.failure(error))
        }
    }

    // MARK: Queue-confined

    private func stateChanged(_ state: NWListener.State) {
        switch state {
        case .ready:
            if let port = listener?.port?.rawValue, let continuation = portContinuation {
                portContinuation = nil
                continuation.resume(returning: port)
            }
        case .failed(let error):
            if let continuation = portContinuation {
                portContinuation = nil
                continuation.resume(throwing: error)
            } else {
                deliver(.failure(error))
            }
        default:
            break
        }
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            let items = OAuthCallback.queryItems(fromRequest: request)
            let isRedirect = OAuthCallback.isRedirect(items)

            let body = isRedirect
                ? "<!doctype html><meta charset=\"utf-8\"><title>CalWidget</title><body style=\"font-family:-apple-system,sans-serif;text-align:center;margin-top:20vh\"><h2>You're signed in</h2><p>You can close this tab and return to CalWidget.</p></body>"
                : "Not found"
            let response = "HTTP/1.1 \(isRedirect ? "200 OK" : "404 Not Found")\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })

            // Stray requests (a favicon fetch, say) are answered and ignored.
            if isRedirect {
                self.listener?.cancel()
                self.listener = nil
                self.deliver(.success(items))
            }
        }
    }

    private func deliver(_ result: Result<[URLQueryItem], Error>) {
        if let continuation = redirectContinuation {
            redirectContinuation = nil
            continuation.resume(with: result)
        } else if pendingResult == nil {
            pendingResult = result
        }
    }
}
