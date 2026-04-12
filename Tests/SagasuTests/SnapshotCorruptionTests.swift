import Foundation
import XCTest
@testable import SagasuShared

final class SnapshotCorruptionTests: XCTestCase {
    func testLoadSnapshotThrowsCorruptionOnGarbageJSON() async throws {
        let baseDirectory = temporaryDirectory()
        let store = try SnapshotStore(baseDirectory: baseDirectory)
        try writeRawBytes("not json at all {{{", to: await store.snapshotURL())

        do {
            _ = try await store.loadSnapshot()
            XCTFail("expected SnapshotCorruption.decodeFailed")
        } catch let corruption as SnapshotCorruption {
            if case .decodeFailed = corruption { return }
            XCTFail("wrong corruption case: \(corruption)")
        }
    }

    func testLoadSnapshotResilientFallsBackOnGarbageJSON() async throws {
        let baseDirectory = temporaryDirectory()
        let store = try SnapshotStore(baseDirectory: baseDirectory)
        try writeRawBytes("{\"broken\":", to: await store.snapshotURL())

        let snapshot = await store.loadSnapshotResilient()
        // bundled fixtures should populate at least one dataset
        XCTAssertTrue(snapshot.rooms != nil || snapshot.bookings != nil || snapshot.tasks != nil)
    }

    func testLoadSnapshotResilientFallsBackOnTruncatedJSON() async throws {
        let baseDirectory = temporaryDirectory()
        let store = try SnapshotStore(baseDirectory: baseDirectory)

        var snapshot = ServiceSnapshot()
        snapshot.generated_at = "2026-03-14T08:15:00Z"
        snapshot.auth_state = .init(has_credentials: true, storage_mode: .keychain, runtime: "test")
        let encoder = JSONEncoder()
        let fullData = try encoder.encode(snapshot)
        let half = fullData.prefix(fullData.count / 2)
        try half.write(to: await store.snapshotURL())

        let loaded = await store.loadSnapshotResilient()
        // truncated valid JSON -> corruption -> fixture fallback or empty; must not crash
        XCTAssertNotNil(loaded.auth_state.runtime)
    }

    func testLoadSnapshotTreatsAllNilDatasetsAsCorruption() async throws {
        let baseDirectory = temporaryDirectory()
        let store = try SnapshotStore(baseDirectory: baseDirectory)

        // valid JSON but rooms/bookings/tasks all nil -> corruption signal
        let emptySnapshot = ServiceSnapshot()
        let data = try JSONEncoder().encode(emptySnapshot)
        try data.write(to: await store.snapshotURL())

        do {
            _ = try await store.loadSnapshot()
            XCTFail("expected SnapshotCorruption.allDatasetsNil")
        } catch let corruption as SnapshotCorruption {
            if case .allDatasetsNil = corruption { return }
            XCTFail("wrong corruption case: \(corruption)")
        }
    }

    func testBootstrapRecoversFromCorruptedSnapshot() async throws {
        let baseDirectory = temporaryDirectory()
        let store = try SnapshotStore(baseDirectory: baseDirectory)
        try writeRawBytes("garbage!!!", to: await store.snapshotURL())

        let bootstrapped = try await store.bootstrapSnapshotIfNeeded()
        XCTAssertNotNil(bootstrapped.rooms)
        XCTAssertNotNil(bootstrapped.bookings)
        XCTAssertNotNil(bootstrapped.tasks)
    }

    func testSaveSnapshotIsAtomicViaTmpFile() async throws {
        let baseDirectory = temporaryDirectory()
        let store = try SnapshotStore(baseDirectory: baseDirectory)

        var snapshot = ServiceSnapshot()
        snapshot.generated_at = "2026-03-14T08:15:00Z"
        try await store.saveSnapshot(snapshot)

        let finalURL = await store.snapshotURL()
        let tmpURL = finalURL.appendingPathExtension("tmp")
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmpURL.path)) // .tmp must not linger
    }

    private func temporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        return directory
    }

    private func writeRawBytes(_ string: String, to url: URL) throws {
        try Data(string.utf8).write(to: url)
    }
}
