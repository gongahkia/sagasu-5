import Darwin
import Foundation
import SagasuShared

@main
enum SagasuHelperMain {
    static func main() async {
        do {
            let store = try SnapshotStore()
            let service = SagasuHelperService(store: store)

            let arguments = Array(CommandLine.arguments.dropFirst())
            let command = arguments.first ?? "refresh"

            switch command {
            case "refresh":
                let reason = arguments.dropFirst().first ?? "manual"
                let snapshot = try await service.refresh(reason: reason)
                print("helper refreshed at \(snapshot.generated_at)")

            case "service":
                try await service.runServiceLoop()

            case "bootstrap":
                let snapshot = try await store.bootstrapSnapshotIfNeeded()
                print("helper bootstrapped local snapshot at \(snapshot.generated_at)")

            default:
                fputs("usage: sagasu-helper [refresh|service|bootstrap]\n", stderr)
                exit(1)
            }
        } catch {
            let message = "sagasu-helper error: \(error.localizedDescription)\n"
            if let data = message.data(using: .utf8) {
                FileHandle.standardError.write(data)
            }
            exit(1)
        }
    }
}
