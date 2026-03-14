import Foundation

public enum SnapshotStoreError: LocalizedError {
    case unavailableBaseDirectory

    public var errorDescription: String? {
        switch self {
        case .unavailableBaseDirectory:
            return "Application support directory is unavailable."
        }
    }
}

public struct AppSupportPaths {
    public static let bundleIdentifier = "com.gongahkia.sagasu"

    public static func baseDirectory(fileManager: FileManager = .default) throws -> URL {
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return appSupport.appendingPathComponent(bundleIdentifier, isDirectory: true)
        }

        return fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".sagasu", isDirectory: true)
    }
}

public actor SnapshotStore {
    private let fileManager: FileManager
    private let baseDirectory: URL

    public init(
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil
    ) throws {
        self.fileManager = fileManager
        self.baseDirectory = try baseDirectory ?? AppSupportPaths.baseDirectory(fileManager: fileManager)
        try createDirectories()
    }

    public func snapshotURL() -> URL {
        baseDirectory.appendingPathComponent("snapshot.json")
    }

    public func consoleURL() -> URL {
        baseDirectory.appendingPathComponent("helper.log")
    }

    public func loadSnapshot() throws -> ServiceSnapshot {
        let url = snapshotURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return ServiceSnapshot()
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(ServiceSnapshot.self, from: data)
    }

    public func saveSnapshot(_ snapshot: ServiceSnapshot) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: snapshotURL(), options: .atomic)
    }

    public func appendConsole(_ line: String) throws {
        let data = Data((line + "\n").utf8)
        let url = consoleURL()

        if !fileManager.fileExists(atPath: url.path) {
            try data.write(to: url, options: .atomic)
            return
        }

        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    public func loadConsole() -> String {
        let url = consoleURL()
        guard let data = try? Data(contentsOf: url) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    public func bootstrapSnapshotIfNeeded() throws -> ServiceSnapshot {
        let existing = try loadSnapshot()
        if existing.rooms != nil || existing.bookings != nil || existing.tasks != nil {
            return existing
        }

        let bootstrapped = try ArchivedSnapshotBootstrapper().load()
        try saveSnapshot(bootstrapped)
        return bootstrapped
    }

    private func createDirectories() throws {
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true, attributes: nil)
    }
}
