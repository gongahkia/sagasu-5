import Foundation
import OSLog

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

public enum SnapshotCorruption: LocalizedError {
    case allDatasetsNil
    case decodeFailed(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .allDatasetsNil:
            return "Snapshot decoded but all datasets (rooms, bookings, tasks) are nil."
        case let .decodeFailed(underlying):
            return "Snapshot decode failed: \(underlying.localizedDescription)"
        }
    }
}

public actor SnapshotStore {
    private let fileManager: FileManager
    private let baseDirectory: URL
    private let logger = Logger.sagasu(category: "snapshot")

    public init(
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil
    ) throws {
        self.fileManager = fileManager
        self.baseDirectory = try baseDirectory ?? AppSupportPaths.baseDirectory(fileManager: fileManager)
        try fileManager.createDirectory(at: self.baseDirectory, withIntermediateDirectories: true, attributes: nil)
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
        do {
            let decoded = try decoder.decode(ServiceSnapshot.self, from: data)
            // sanity: all-nil datasets + no real status/auth info means it's effectively empty garbage
            let allDatasetsNil = decoded.rooms == nil && decoded.bookings == nil && decoded.tasks == nil
            let noMeaningfulStatuses = decoded.statuses.allSatisfy { $0.state == .idle && $0.last_attempt_at == nil && $0.last_success_at == nil && $0.message == nil }
            let defaultAuth = !decoded.auth_state.has_credentials && decoded.auth_state.storage_mode == .none && decoded.auth_state.last_error == nil
            if allDatasetsNil && noMeaningfulStatuses && defaultAuth {
                logger.warning("snapshot at \(url.path, privacy: .public) decoded but is effectively empty (\(data.count, privacy: .public) bytes); treating as corruption")
                throw SnapshotCorruption.allDatasetsNil
            }
            return decoded
        } catch let corruption as SnapshotCorruption {
            throw corruption
        } catch {
            logger.error("snapshot decode failed at \(url.path, privacy: .public) (\(data.count, privacy: .public) bytes): \(String(describing: error), privacy: .public)")
            throw SnapshotCorruption.decodeFailed(underlying: error)
        }
    }

    // resilient load: on corruption falls back to bundled fixtures, then empty snapshot
    public func loadSnapshotResilient() -> ServiceSnapshot {
        do {
            return try loadSnapshot()
        } catch {
            logger.warning("loadSnapshot failed, falling back to bundled fixtures: \(String(describing: error), privacy: .public)")
            if let fixture = try? ArchivedSnapshotBootstrapper().load() {
                return fixture
            }
            logger.error("bundled fixtures unavailable; returning empty snapshot")
            return ServiceSnapshot()
        }
    }

    public func saveSnapshot(_ snapshot: ServiceSnapshot) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        let finalURL = snapshotURL()
        // atomic write: write to .tmp sibling first, then rename to avoid half-written files on crash
        let tmpURL = finalURL.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: .atomic)
        if fileManager.fileExists(atPath: finalURL.path) {
            _ = try fileManager.replaceItemAt(finalURL, withItemAt: tmpURL)
        } else {
            try fileManager.moveItem(at: tmpURL, to: finalURL)
        }
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
        let existing: ServiceSnapshot
        do {
            existing = try loadSnapshot()
        } catch is SnapshotCorruption {
            // corrupted snapshot: fall through to bootstrapping from fixtures
            existing = ServiceSnapshot()
        }
        if existing.rooms != nil || existing.bookings != nil || existing.tasks != nil {
            return existing
        }

        let bootstrapped = try ArchivedSnapshotBootstrapper().load()
        try saveSnapshot(bootstrapped)
        return bootstrapped
    }
}
