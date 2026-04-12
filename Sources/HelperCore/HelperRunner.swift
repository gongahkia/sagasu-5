import Darwin
import Foundation
import OSLog
import SagasuShared

public enum SagasuHelperCommand: Equatable, Sendable {
    case refresh(reason: String)
    case service
    case xpcService
    case bootstrap
    case usage // unknown command -> print usage
}

public enum SagasuHelperArgumentParser {
    public static func parse(_ arguments: [String]) -> SagasuHelperCommand {
        let command = arguments.first ?? "refresh"
        switch command {
        case "refresh":
            let reason = arguments.dropFirst().first ?? "manual"
            return .refresh(reason: reason)
        case "service":
            return .service
        case "xpc-service":
            return .xpcService
        case "bootstrap":
            return .bootstrap
        default:
            return .usage
        }
    }
}

public enum SagasuHelperRunner {
    private static let logger = Logger.sagasu(category: "helper-service")

    public static func run(
        arguments: [String],
        service: SagasuHelperService,
        store: SnapshotStore
    ) async throws {
        let command = SagasuHelperArgumentParser.parse(arguments)
        switch command {
        case let .refresh(reason):
            let snapshot = try await service.refresh(reason: reason)
            logger.notice("helper refreshed at \(snapshot.generated_at, privacy: .public)")
        case .service:
            try await service.runServiceLoop()
        case .xpcService:
            let xpcService = SagasuHelperXPCService(service: service)
            xpcService.run()
        case .bootstrap:
            let snapshot = try await store.bootstrapSnapshotIfNeeded()
            logger.notice("helper bootstrapped local snapshot at \(snapshot.generated_at, privacy: .public)")
        case .usage:
            fputs("usage: sagasu-helper [refresh|service|xpc-service|bootstrap]\n", stderr)
            exit(1)
        }
    }
}
