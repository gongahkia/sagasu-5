import Foundation
import XCTest
@testable import SagasuShared

final class PersistenceStoreTests: XCTestCase {
    func testSnapshotStoreRoundTripsSnapshotAndConsole() async throws {
        let baseDirectory = temporaryDirectory()
        let store = try SnapshotStore(baseDirectory: baseDirectory)

        var snapshot = ServiceSnapshot()
        snapshot.generated_at = "2026-03-14T08:15:00Z"
        snapshot.auth_state = .init(has_credentials: true, storage_mode: .keychain, runtime: "test-runtime")
        snapshot.setStatus(.init(dataset: .rooms, state: .success, last_attempt_at: "2026-03-14T08:15:00Z"))

        try await store.saveSnapshot(snapshot)
        try await store.appendConsole("[2026-03-14T08:15:00Z] helper refresh completed")

        let loadedSnapshot = try await store.loadSnapshot()
        let console = await store.loadConsole()

        XCTAssertEqual(loadedSnapshot.generated_at, "2026-03-14T08:15:00Z")
        XCTAssertTrue(loadedSnapshot.auth_state.has_credentials)
        XCTAssertEqual(loadedSnapshot.status(for: .rooms).state, .success)
        XCTAssertTrue(console.contains("helper refresh completed"))
    }

    func testScrapePreferencesStoreRoundTripsPreferences() async throws {
        let baseDirectory = temporaryDirectory()
        let store = try ScrapePreferencesStore(baseDirectory: baseDirectory)
        let preferences = ScrapePreferences(
            date: "17-Mar-2026",
            start_time: "09:00",
            end_time: "18:00",
            buildings: ["SMU Connexion"],
            floors: ["4"],
            facility_types: ["Meeting Pod"],
            equipment: ["Whiteboard"],
            capacity: "4"
        )

        try await store.save(preferences)
        let loaded = try await store.load()

        XCTAssertEqual(loaded, preferences)
    }

    private func temporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        return directory
    }
}
