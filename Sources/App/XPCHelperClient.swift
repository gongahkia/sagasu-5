import Foundation
import SagasuShared

final class XPCHelperClient: @unchecked Sendable {
    func loadSnapshot() async throws -> ServiceSnapshot {
        let data = try await call { proxy, reply in
            proxy.currentSnapshot(reply: reply)
        }

        return try JSONDecoder().decode(ServiceSnapshot.self, from: data)
    }

    func refresh(manual: Bool) async throws -> ServiceSnapshot {
        let request = ScrapeRequest(reason: manual ? "manual-refresh" : "scheduled-refresh", manual: manual)
        let payload = try JSONEncoder().encode(request)
        let data = try await call { proxy, reply in
            proxy.refresh(payload, reply: reply)
        }

        return try JSONDecoder().decode(ServiceSnapshot.self, from: data)
    }

    func storeCredentials(email: String, password: String) async throws {
        let payload = try JSONEncoder().encode(SharedCredentials(email: email, password: password))
        try await callVoid { proxy, reply in
            proxy.storeCredentials(payload, reply: reply)
        }
    }

    func clearCredentials() async throws {
        try await callVoid { proxy, reply in
            proxy.clearCredentials(reply: reply)
        }
    }

    private func call(
        _ invocation: @escaping (SagasuHelperXPCProtocol, @escaping (Data?, NSError?) -> Void) -> Void
    ) async throws -> Data {
        let connection = NSXPCConnection(machServiceName: HelperMachService.name, options: [])
        connection.remoteObjectInterface = NSXPCInterface(with: SagasuHelperXPCProtocol.self)
        connection.resume()

        defer {
            connection.invalidate()
        }

        return try await withCheckedThrowingContinuation { continuation in
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                continuation.resume(throwing: error)
            } as? SagasuHelperXPCProtocol

            guard let proxy else {
                continuation.resume(throwing: HelperClientError(message: "The helper XPC proxy is unavailable."))
                return
            }

            invocation(proxy) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data else {
                    continuation.resume(throwing: HelperClientError(message: "The helper XPC response was empty."))
                    return
                }

                continuation.resume(returning: data)
            }
        }
    }

    private func callVoid(
        _ invocation: @escaping (SagasuHelperXPCProtocol, @escaping (NSError?) -> Void) -> Void
    ) async throws {
        let connection = NSXPCConnection(machServiceName: HelperMachService.name, options: [])
        connection.remoteObjectInterface = NSXPCInterface(with: SagasuHelperXPCProtocol.self)
        connection.resume()

        defer {
            connection.invalidate()
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                continuation.resume(throwing: error)
            } as? SagasuHelperXPCProtocol

            guard let proxy else {
                continuation.resume(throwing: HelperClientError(message: "The helper XPC proxy is unavailable."))
                return
            }

            invocation(proxy) { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume()
            }
        }
    }
}
