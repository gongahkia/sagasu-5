import Foundation
import XCTest
@testable import SagasuShared

final class ModelsTests: XCTestCase {
    // MARK: - ScrapeDataset
    func testScrapeDatasetAllCasesContainsExpectedValues() {
        XCTAssertEqual(ScrapeDataset.allCases, [.rooms, .bookings, .tasks])
    }

    func testScrapeDatasetRawValues() {
        XCTAssertEqual(ScrapeDataset.rooms.rawValue, "rooms")
        XCTAssertEqual(ScrapeDataset.bookings.rawValue, "bookings")
        XCTAssertEqual(ScrapeDataset.tasks.rawValue, "tasks")
    }

    func testScrapeDatasetCodableRoundTrip() throws {
        for dataset in ScrapeDataset.allCases {
            let data = try JSONEncoder().encode(dataset)
            let decoded = try JSONDecoder().decode(ScrapeDataset.self, from: data)
            XCTAssertEqual(decoded, dataset)
        }
    }

    // MARK: - DatasetState
    func testDatasetStateAllCasesContainsExpectedValues() {
        XCTAssertEqual(DatasetState.allCases, [.idle, .loading, .success, .stale, .failed])
    }

    func testDatasetStateCodableRoundTrip() throws {
        for state in DatasetState.allCases {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(DatasetState.self, from: data)
            XCTAssertEqual(decoded, state)
        }
    }

    // MARK: - DatasetStatus
    func testDatasetStatusDefaultsToIdle() {
        let status = DatasetStatus(dataset: .rooms)
        XCTAssertEqual(status.state, .idle)
        XCTAssertNil(status.last_attempt_at)
        XCTAssertNil(status.last_success_at)
        XCTAssertNil(status.message)
    }

    func testDatasetStatusIdUsesDatasetRawValue() {
        let status = DatasetStatus(dataset: .bookings)
        XCTAssertEqual(status.id, "bookings")
    }

    func testDatasetStatusCodableRoundTrip() throws {
        let status = DatasetStatus(
            dataset: .tasks,
            state: .success,
            last_attempt_at: "2026-03-14T08:15:00Z",
            last_success_at: "2026-03-14T08:15:00Z",
            message: "ok"
        )
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(DatasetStatus.self, from: data)
        XCTAssertEqual(decoded.dataset, .tasks)
        XCTAssertEqual(decoded.state, .success)
        XCTAssertEqual(decoded.last_attempt_at, "2026-03-14T08:15:00Z")
        XCTAssertEqual(decoded.last_success_at, "2026-03-14T08:15:00Z")
        XCTAssertEqual(decoded.message, "ok")
    }

    // MARK: - AuthState
    func testAuthStateDefaults() {
        let state = AuthState()
        XCTAssertFalse(state.has_credentials)
        XCTAssertEqual(state.storage_mode, .none)
        XCTAssertEqual(state.runtime, "Unavailable")
        XCTAssertNil(state.last_error)
    }

    func testAuthStateStorageModeRawValues() {
        XCTAssertEqual(AuthState.StorageMode.none.rawValue, "none")
        XCTAssertEqual(AuthState.StorageMode.environment.rawValue, "environment")
        XCTAssertEqual(AuthState.StorageMode.keychain.rawValue, "keychain")
    }

    func testAuthStateCodableRoundTrip() throws {
        let state = AuthState(
            has_credentials: true,
            storage_mode: .keychain,
            runtime: "native-webkit",
            last_error: "timeout"
        )
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(AuthState.self, from: data)
        XCTAssertTrue(decoded.has_credentials)
        XCTAssertEqual(decoded.storage_mode, .keychain)
        XCTAssertEqual(decoded.runtime, "native-webkit")
        XCTAssertEqual(decoded.last_error, "timeout")
    }

    // MARK: - ScrapeRequest
    func testScrapeRequestDefaultsIncludeAllDatasets() {
        let request = ScrapeRequest()
        XCTAssertEqual(request.datasets, ScrapeDataset.allCases)
        XCTAssertEqual(request.reason, "manual-refresh")
        XCTAssertTrue(request.manual)
    }

    func testScrapeRequestCodableRoundTrip() throws {
        let request = ScrapeRequest(datasets: [.rooms], reason: "test", manual: false)
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(ScrapeRequest.self, from: data)
        XCTAssertEqual(decoded.datasets, [.rooms])
        XCTAssertEqual(decoded.reason, "test")
        XCTAssertFalse(decoded.manual)
    }

    // MARK: - ServiceSnapshot
    func testServiceSnapshotDefaultStatusesMatchAllDatasets() {
        let snapshot = ServiceSnapshot()
        XCTAssertEqual(snapshot.statuses.count, ScrapeDataset.allCases.count)
        for dataset in ScrapeDataset.allCases {
            XCTAssertEqual(snapshot.status(for: dataset).state, .idle)
        }
    }

    func testServiceSnapshotStatusForReturnsIdleWhenMissing() {
        let snapshot = ServiceSnapshot(statuses: [])
        let status = snapshot.status(for: .rooms)
        XCTAssertEqual(status.dataset, .rooms)
        XCTAssertEqual(status.state, .idle)
    }

    func testServiceSnapshotSetStatusUpdatesExisting() {
        var snapshot = ServiceSnapshot()
        let updated = DatasetStatus(dataset: .rooms, state: .success, last_attempt_at: "2026-03-14T08:15:00Z")
        snapshot.setStatus(updated)
        XCTAssertEqual(snapshot.status(for: .rooms).state, .success)
        XCTAssertEqual(snapshot.statuses.count, ScrapeDataset.allCases.count) // no duplicates
    }

    func testServiceSnapshotSetStatusAppendsWhenMissing() {
        var snapshot = ServiceSnapshot(statuses: [])
        let status = DatasetStatus(dataset: .bookings, state: .failed, message: "err")
        snapshot.setStatus(status)
        XCTAssertEqual(snapshot.statuses.count, 1)
        XCTAssertEqual(snapshot.status(for: .bookings).state, .failed)
    }

    func testServiceSnapshotCodableRoundTrip() throws {
        var snapshot = ServiceSnapshot(generated_at: "2026-03-14T08:15:00Z")
        snapshot.auth_state = AuthState(has_credentials: true, storage_mode: .environment, runtime: "test")
        snapshot.setStatus(DatasetStatus(dataset: .rooms, state: .success))
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ServiceSnapshot.self, from: data)
        XCTAssertEqual(decoded.generated_at, "2026-03-14T08:15:00Z")
        XCTAssertTrue(decoded.auth_state.has_credentials)
        XCTAssertEqual(decoded.status(for: .rooms).state, .success)
    }

    func testServiceSnapshotNilPayloads() {
        let snapshot = ServiceSnapshot()
        XCTAssertNil(snapshot.rooms)
        XCTAssertNil(snapshot.bookings)
        XCTAssertNil(snapshot.tasks)
    }

    // MARK: - ScrapedRoomsResponse
    func testScrapedRoomsResponseCodableRoundTrip() throws {
        let room = ScrapedRoomsResponse.Room(
            id: "r1",
            name: "Room 1",
            building: "Bldg",
            building_code: "B",
            floor: "2",
            facility_type: "Pod",
            equipment: ["Whiteboard"],
            timeslots: [
                .init(start: "08:00", end: "09:00", status: "free"),
                .init(start: "09:00", end: "10:00", status: "booked", booking: .init(reference: "REF1", status: "Confirmed"))
            ],
            availability_summary: .init(is_available_now: true, next_available_at: nil, free_slots_count: 1, free_duration_minutes: 60)
        )
        let response = ScrapedRoomsResponse(
            metadata: .init(version: "5.0.0", scraped_at: "2026-03-14T08:15:00Z", scrape_duration_ms: 500, success: true, error: nil, scraper_version: "test", source: "unit-test"),
            config: .init(date: "14-Mar-2026", start_time: "08:00", end_time: "22:00", filters: .init(buildings: ["B"], capacity: "4")),
            statistics: .init(total_rooms: 1, available_rooms: 1, booked_rooms: 0, partially_available_rooms: 0),
            rooms: [room]
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(ScrapedRoomsResponse.self, from: data)
        XCTAssertEqual(decoded.rooms?.count, 1)
        XCTAssertEqual(decoded.rooms?.first?.id, "r1")
        XCTAssertEqual(decoded.rooms?.first?.timeslots.count, 2)
        XCTAssertEqual(decoded.rooms?.first?.timeslots[1].booking?.reference, "REF1")
        XCTAssertEqual(decoded.config.filters?.buildings, ["B"])
        XCTAssertEqual(decoded.config.filters?.capacity, "4")
    }

    func testScrapedRoomsResponseNilRooms() throws {
        let response = ScrapedRoomsResponse(
            metadata: .init(version: "5.0.0", scraped_at: "2026-03-14T08:15:00Z", scrape_duration_ms: 0, success: false, error: "fail", scraper_version: "test"),
            config: .init(date: "14-Mar-2026", start_time: "08:00", end_time: "22:00"),
            statistics: .init(total_rooms: 0, available_rooms: 0, booked_rooms: 0, partially_available_rooms: 0),
            rooms: nil
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(ScrapedRoomsResponse.self, from: data)
        XCTAssertNil(decoded.rooms)
        XCTAssertEqual(decoded.metadata.error, "fail")
    }

    // MARK: - ScrapedBookingsResponse
    func testScrapedBookingsResponseCodableRoundTrip() throws {
        let booking = ScrapedBookingsResponse.Booking(
            reference_number: "BR-001",
            date: "14-Mar-2026",
            day_of_week: "Sat",
            start_time: "08:00",
            end_time: "10:00",
            duration_hours: 2,
            building: "SMUC",
            room_name: "Pod 1",
            booked_by: "Test",
            booking_type: "Internal",
            price: 12.5,
            status: "Confirmed",
            raw_datetime: "14-Mar-2026 08:00-10:00"
        )
        let response = ScrapedBookingsResponse(
            metadata: .init(version: "5.0.0", scraped_at: "2026-03-14T08:15:00Z", scrape_duration_ms: 100, success: true, error: nil, scraper_version: "test"),
            statistics: .init(total_bookings: 1, confirmed_bookings: 1, pending_bookings: 0, total_price: 12.5),
            bookings: [booking]
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(ScrapedBookingsResponse.self, from: data)
        XCTAssertEqual(decoded.bookings.count, 1)
        XCTAssertEqual(decoded.bookings.first?.id, "BR-001")
        XCTAssertEqual(decoded.bookings.first?.price, 12.5)
        XCTAssertEqual(decoded.bookings.first?.raw_datetime, "14-Mar-2026 08:00-10:00")
    }

    // MARK: - ScrapedTasksResponse
    func testScrapedTasksResponseCodableRoundTrip() throws {
        let task = ScrapedTasksResponse.Task(
            reference_number: "TK-001",
            date: "14-Mar-2026",
            start_time: "16:00",
            end_time: "19:00",
            duration_hours: 3,
            building: "SMUC",
            room_name: "Pod 1",
            task_type: "Approval",
            requested_by: "User",
            status: "Pending Confirmation",
            raw_datetime: "14-Mar-2026 16:00-19:00"
        )
        let response = ScrapedTasksResponse(
            metadata: .init(version: "5.0.0", scraped_at: "2026-03-14T08:15:00Z", scrape_duration_ms: 100, success: true, error: nil, scraper_version: "test"),
            statistics: .init(total_tasks: 1, pending_tasks: 1, approved_tasks: 0, rejected_tasks: 0),
            tasks: [task]
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(ScrapedTasksResponse.self, from: data)
        XCTAssertEqual(decoded.tasks.count, 1)
        XCTAssertEqual(decoded.tasks.first?.id, "TK-001")
        XCTAssertEqual(decoded.tasks.first?.duration_hours, 3)
        XCTAssertEqual(decoded.tasks.first?.raw_datetime, "14-Mar-2026 16:00-19:00")
    }

    // MARK: - Date extension
    func testDateISO8601StringProducesExpectedFormat() {
        let date = Date(timeIntervalSince1970: 0)
        let result = date.iso8601String
        XCTAssertTrue(result.hasPrefix("1970-01-01T00:00:00"))
    }

    // MARK: - Booking ID
    func testBookingIdentifiableUsesReferenceNumber() {
        let booking = ScrapedBookingsResponse.Booking(
            reference_number: "BR-999",
            date: "14-Mar-2026",
            start_time: "08:00",
            end_time: "09:00",
            duration_hours: 1,
            building: "B",
            room_name: "R",
            booked_by: "U",
            booking_type: "Internal",
            price: 0,
            status: "Confirmed"
        )
        XCTAssertEqual(booking.id, "BR-999")
    }

    // MARK: - Task ID
    func testTaskIdentifiableUsesReferenceNumber() {
        let task = ScrapedTasksResponse.Task(
            reference_number: "TK-999",
            date: "14-Mar-2026",
            start_time: "08:00",
            end_time: "09:00",
            duration_hours: 1,
            building: "B",
            room_name: "R",
            task_type: "Approval",
            requested_by: "U",
            status: "Pending"
        )
        XCTAssertEqual(task.id, "TK-999")
    }

    // MARK: - Room ID
    func testRoomIdentifiableUsesId() {
        let room = ScrapedRoomsResponse.Room(
            id: "room-42",
            name: "Room 42",
            building: "B",
            building_code: "BC",
            floor: "1",
            facility_type: "Pod",
            equipment: [],
            timeslots: [],
            availability_summary: .init(is_available_now: false, next_available_at: "10:00", free_slots_count: 0, free_duration_minutes: 0)
        )
        XCTAssertEqual(room.id, "room-42")
    }

    // MARK: - Empty bookings/tasks arrays
    func testEmptyBookingsResponseCodable() throws {
        let response = ScrapedBookingsResponse(
            metadata: .init(version: "5.0.0", scraped_at: "2026-03-14T08:15:00Z", scrape_duration_ms: 0, success: true, error: nil, scraper_version: "test"),
            statistics: .init(total_bookings: 0, confirmed_bookings: 0, pending_bookings: 0, total_price: 0),
            bookings: []
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(ScrapedBookingsResponse.self, from: data)
        XCTAssertTrue(decoded.bookings.isEmpty)
    }

    func testEmptyTasksResponseCodable() throws {
        let response = ScrapedTasksResponse(
            metadata: .init(version: "5.0.0", scraped_at: "2026-03-14T08:15:00Z", scrape_duration_ms: 0, success: true, error: nil, scraper_version: "test"),
            statistics: .init(total_tasks: 0, pending_tasks: 0, approved_tasks: 0, rejected_tasks: 0),
            tasks: []
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(ScrapedTasksResponse.self, from: data)
        XCTAssertTrue(decoded.tasks.isEmpty)
    }
}
