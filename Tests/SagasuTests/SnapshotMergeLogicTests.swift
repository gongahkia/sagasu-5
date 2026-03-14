import XCTest
@testable import SagasuCore
@testable import SagasuShared

final class SnapshotMergeLogicTests: XCTestCase {
    func testMergeRoomsKeepsCurrentPayloadWhenLiveScrapeFails() {
        let current = makeRoomsResponse(scrapedAt: "2026-03-13T08:00:00Z", source: "current-cache")
        let fallback = makeRoomsResponse(scrapedAt: "2026-03-12T08:00:00Z", source: "fixture-cache")

        let merged = SnapshotMergeLogic.mergeRooms(
            .failure(DummyMergeError(message: "rooms broke")),
            current: current,
            fallback: fallback,
            attemptAt: "2026-03-14T08:15:00Z"
        )

        XCTAssertEqual(merged.payload?.metadata.source, "current-cache")
        XCTAssertEqual(merged.status.state, .stale)
        XCTAssertEqual(merged.status.last_success_at, "2026-03-13T08:00:00Z")
        XCTAssertEqual(merged.status.message, "rooms broke")
    }

    func testMergeBookingsFallsBackToFixturesWhenCacheIsMissing() {
        let fallback = makeBookingsResponse(scrapedAt: "2026-03-12T08:00:00Z", source: "fixture-cache")

        let merged = SnapshotMergeLogic.mergeBookings(
            .failure(DummyMergeError(message: "bookings broke")),
            current: nil,
            fallback: fallback,
            attemptAt: "2026-03-14T08:15:00Z"
        )

        XCTAssertEqual(merged.payload?.metadata.source, "fixture-cache")
        XCTAssertEqual(merged.status.state, .stale)
        XCTAssertEqual(merged.status.last_success_at, "2026-03-12T08:00:00Z")
        XCTAssertEqual(merged.status.message, "bookings broke")
    }

    func testMergeTasksFailsWhenNoPayloadExists() {
        let merged = SnapshotMergeLogic.mergeTasks(
            .failure(DummyMergeError(message: "tasks broke")),
            current: nil,
            fallback: nil,
            attemptAt: "2026-03-14T08:15:00Z"
        )

        XCTAssertNil(merged.payload)
        XCTAssertEqual(merged.status.state, .failed)
        XCTAssertNil(merged.status.last_success_at)
        XCTAssertEqual(merged.status.message, "tasks broke")
    }

    private func makeRoomsResponse(scrapedAt: String, source: String) -> ScrapedRoomsResponse {
        ScrapedRoomsResponse(
            metadata: .init(
                version: "5.0.0",
                scraped_at: scrapedAt,
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

    private func makeBookingsResponse(scrapedAt: String, source: String) -> ScrapedBookingsResponse {
        ScrapedBookingsResponse(
            metadata: .init(
                version: "5.0.0",
                scraped_at: scrapedAt,
                scrape_duration_ms: 1000,
                success: true,
                error: nil,
                scraper_version: "test",
                source: source
            ),
            statistics: .init(total_bookings: 1, confirmed_bookings: 1, pending_bookings: 0, total_price: 0),
            bookings: [
                .init(
                    reference_number: "BR-1",
                    date: "14-Mar-2026",
                    day_of_week: "Sat",
                    start_time: "08:00",
                    end_time: "09:00",
                    duration_hours: 1,
                    building: "Building",
                    room_name: "Room 1",
                    booked_by: "User",
                    booking_type: "Internal",
                    price: 0,
                    status: "Confirmed"
                )
            ]
        )
    }
}

private struct DummyMergeError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}
