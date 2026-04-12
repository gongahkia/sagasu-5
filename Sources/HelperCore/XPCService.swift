import Foundation
import SagasuShared

private struct DataReplyBox: @unchecked Sendable {
    let reply: (Data?, NSError?) -> Void

    func call(_ data: Data?, _ error: NSError?) {
        reply(data, error)
    }
}

public final class SagasuHelperXPCService: NSObject, NSXPCListenerDelegate, SagasuHelperXPCProtocol {
    private let service: SagasuHelperService
    private lazy var listener = NSXPCListener(machServiceName: HelperMachService.name)

    public init(service: SagasuHelperService) {
        self.service = service
        super.init()
    }

    public func run() {
        listener.delegate = self
        listener.resume()
        RunLoop.current.run()
    }

    public func currentSnapshot(reply: @escaping (Data?, NSError?) -> Void) {
        let service = self.service
        let replyBox = DataReplyBox(reply: reply)
        Task {
            do {
                let snapshot = try await service.currentSnapshot()
                replyBox.call(try JSONEncoder().encode(snapshot), nil)
            } catch {
                replyBox.call(nil, error as NSError)
            }
        }
    }

    public func refresh(_ request: Data, reply: @escaping (Data?, NSError?) -> Void) {
        let service = self.service
        let replyBox = DataReplyBox(reply: reply)
        Task {
            do {
                let decoded = try JSONDecoder().decode(ScrapeRequest.self, from: request)
                let snapshot = try await service.refresh(reason: decoded.reason)
                replyBox.call(try JSONEncoder().encode(snapshot), nil)
            } catch {
                replyBox.call(nil, error as NSError)
            }
        }
    }

    public func authState(reply: @escaping (Data?, NSError?) -> Void) {
        let service = self.service
        let replyBox = DataReplyBox(reply: reply)
        Task {
            do {
                let authState = try await service.currentAuthState()
                replyBox.call(try JSONEncoder().encode(authState), nil)
            } catch {
                replyBox.call(nil, error as NSError)
            }
        }
    }

    public func storeCredentials(_ credentials: Data, reply: @escaping (NSError?) -> Void) {
        do {
            let decoded = try JSONDecoder().decode(SharedCredentials.self, from: credentials)
            try SharedCredentialsStore.save(decoded)
            reply(nil)
        } catch {
            reply(error as NSError)
        }
    }

    public func clearCredentials(reply: @escaping (NSError?) -> Void) {
        do {
            try SharedCredentialsStore.clear()
            reply(nil)
        } catch {
            reply(error as NSError)
        }
    }

    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: SagasuHelperXPCProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
}
