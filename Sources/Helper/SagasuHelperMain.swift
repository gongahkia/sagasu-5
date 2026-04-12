import Darwin
import Foundation
import SagasuHelperCore
import SagasuShared

@main
enum SagasuHelperMain {
    static func main() async {
        do {
            let store = try SnapshotStore()
            let service = SagasuHelperService(store: store)
            let arguments = Array(CommandLine.arguments.dropFirst())
            try await SagasuHelperRunner.run(arguments: arguments, service: service, store: store)
        } catch {
            let message = "sagasu-helper error: \(error.localizedDescription)\n"
            if let data = message.data(using: .utf8) {
                FileHandle.standardError.write(data)
            }
            exit(1)
        }
    }
}
