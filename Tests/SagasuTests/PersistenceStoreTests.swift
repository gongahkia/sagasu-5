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

    func testScrapePreferencesStoreReturnsDefaultsWhenFileIsMissing() async throws {
        let baseDirectory = temporaryDirectory()
        let store = try ScrapePreferencesStore(baseDirectory: baseDirectory)

        let loaded = try await store.load()

        XCTAssertEqual(loaded, ScrapePreferences())
    }

    func testSnapshotStoreBootstrapsFixturesWhenCacheIsMissing() async throws {
        let baseDirectory = temporaryDirectory()
        let store = try SnapshotStore(baseDirectory: baseDirectory)

        let bootstrapped = try await store.bootstrapSnapshotIfNeeded()

        XCTAssertNotNil(bootstrapped.rooms)
        XCTAssertNotNil(bootstrapped.bookings)
        XCTAssertNotNil(bootstrapped.tasks)
        XCTAssertEqual(bootstrapped.rooms?.metadata.source, "Fixtures/bootstrap/rooms.json")
    }

    func testSnapshotStoreBootstrapDoesNotOverwriteExistingSnapshot() async throws {
        let baseDirectory = temporaryDirectory()
        let store = try SnapshotStore(baseDirectory: baseDirectory)

        var snapshot = ServiceSnapshot()
        snapshot.generated_at = "2026-03-14T08:15:00Z"
        snapshot.rooms = makeRoomsResponse(source: "existing-cache")
        try await store.saveSnapshot(snapshot)

        let bootstrapped = try await store.bootstrapSnapshotIfNeeded()

        XCTAssertEqual(bootstrapped.rooms?.metadata.source, "existing-cache")
    }

    private func temporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        return directory
    }

    private func makeRoomsResponse(source: String) -> ScrapedRoomsResponse {
        ScrapedRoomsResponse(
            metadata: .init(
                version: "5.0.0",
                scraped_at: "2026-03-14T08:00:00Z",
                scrape_duration_ms: 1000,
                success: true,
                error: nil,
                scraper_version: "test",
                source: source
            ),
            config: .init(date: "14-Mar-2026", start_time: "08:00", end_time: "22:00"),
            statistics: .init(total_rooms: 1, available_rooms: 1, booked_rooms: 0, partially_available_rooms: 0),
            rooms: [
                .init(
                    id: "room-1",
                    name: "Room 1",
                    building: "Building",
                    building_code: "B",
                    floor: "1",
                    facility_type: "Meeting Pod",
                    equipment: [],
                    timeslots: [],
                    availability_summary: .init(is_available_now: true, next_available_at: nil, free_slots_count: 1, free_duration_minutes: 60)
                )
            ]
        )
    }
}
