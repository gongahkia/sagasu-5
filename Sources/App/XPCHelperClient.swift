import Foundation
import SagasuShared

final class XPCHelperClient {
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
}
