import Foundation
import SagasuShared

protocol HelperClientProtocol {
    func loadSnapshot() async throws -> ServiceSnapshot
    func refresh(manual: Bool) async throws -> ServiceSnapshot
    func loadConsole() async -> String
    func storeCredentials(email: String, password: String) async throws
    func clearCredentials() async throws
}

struct HelperClientError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

final class CompositeHelperClient: HelperClientProtocol {
    private let store: SnapshotStore?
    private let xpcClient = XPCHelperClient()

    init() {
        self.store = try? SnapshotStore()
    }

    func loadSnapshot() async throws -> ServiceSnapshot {
        guard let store else {
            throw HelperClientError(message: "Snapshot store is unavailable.")
        }

        if let snapshot = try? await xpcClient.loadSnapshot() {
            return snapshot
        }

        return try await store.bootstrapSnapshotIfNeeded()
    }

    func refresh(manual: Bool) async throws -> ServiceSnapshot {
        guard let store else {
            throw HelperClientError(message: "Snapshot store is unavailable.")
        }

        if let snapshot = try? await xpcClient.refresh(manual: manual) {
            return snapshot
        }

        guard let helperURL = locateHelperExecutable() else {
            return try await store.bootstrapSnapshotIfNeeded()
        }

        _ = try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = helperURL
            process.arguments = ["refresh", manual ? "manual" : "scheduled"]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            try process.run()
            process.waitUntilExit()

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)

            if process.terminationStatus != 0 {
                throw HelperClientError(
                    message: output.isEmpty
                        ? "The local helper failed."
                        : output.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

            return output
        }.value

        return try await store.loadSnapshot()
    }

    func loadConsole() async -> String {
        guard let store else { return "" }
        return await store.loadConsole()
    }

    func storeCredentials(email: String, password: String) async throws {
        if (try? await xpcClient.storeCredentials(email: email, password: password)) != nil {
            return
        }

        try SharedCredentialsStore.save(.init(email: email, password: password))
    }

    func clearCredentials() async throws {
        if (try? await xpcClient.clearCredentials()) != nil {
            return
        }

        try SharedCredentialsStore.clear()
    }

    private func locateHelperExecutable() -> URL? {
        let fileManager = FileManager.default
        let current = URL(fileURLWithPath: fileManager.currentDirectoryPath)

        let bundleBinary = Bundle.main.bundleURL
            .appendingPathComponent("Contents/MacOS/sagasu-helper")
        let resourceBinary = Bundle.main.resourceURL?
            .appendingPathComponent("sagasu-helper")

        let candidates = [
            bundleBinary,
            resourceBinary,
            current.appendingPathComponent("build/sagasu-helper"),
            current.appendingPathComponent(".build/debug/sagasu-helper"),
            current.appendingPathComponent(".build/release/sagasu-helper")
        ].compactMap { $0 }

        return candidates.first(where: { fileManager.isExecutableFile(atPath: $0.path) })
    }
}
