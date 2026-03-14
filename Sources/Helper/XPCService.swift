import Foundation
import SagasuShared

final class SagasuHelperXPCService: NSObject, NSXPCListenerDelegate, SagasuHelperXPCProtocol {
    private let service: SagasuHelperService
    private lazy var listener = NSXPCListener(machServiceName: HelperMachService.name)

    init(service: SagasuHelperService) {
        self.service = service
        super.init()
    }

    func run() {
        listener.delegate = self
        listener.resume()
        RunLoop.current.run()
    }

    func currentSnapshot(reply: @escaping (Data?, NSError?) -> Void) {
        Task {
            do {
                let snapshot = try await service.currentSnapshot()
                reply(try JSONEncoder().encode(snapshot), nil)
            } catch {
                reply(nil, error as NSError)
            }
        }
    }

    func refresh(_ request: Data, reply: @escaping (Data?, NSError?) -> Void) {
        Task {
            do {
                let decoded = try JSONDecoder().decode(ScrapeRequest.self, from: request)
                let snapshot = try await service.refresh(reason: decoded.reason)
                reply(try JSONEncoder().encode(snapshot), nil)
            } catch {
                reply(nil, error as NSError)
            }
        }
    }

    func authState(reply: @escaping (Data?, NSError?) -> Void) {
        Task {
            do {
                let authState = try await service.currentAuthState()
                reply(try JSONEncoder().encode(authState), nil)
            } catch {
                reply(nil, error as NSError)
            }
        }
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: SagasuHelperXPCProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
}
