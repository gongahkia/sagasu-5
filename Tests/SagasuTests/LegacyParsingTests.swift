import XCTest
@testable import SagasuCore
@testable import SagasuShared

final class LegacyParsingTests: XCTestCase {
    func testGenerateTimeslotsBuildsFreeAndBookedSegments() {
        let raw = [
            "(00:00-08:30) (not available)",
            "Booking Time: 10:00-11:00\nBooking Reference Number: ABC123\nBooking Status: Confirmed",
            "Booking Time: 13:00-14:00\nBooking Reference Number: DEF456\nBooking Status: Pending Confirmation"
        ]

        let slots = LegacyScraperLogic.generateTimeslots(from: raw)

        XCTAssertEqual(slots.first?.status, "unavailable")
        XCTAssertTrue(slots.contains(where: { $0.status == "free" && $0.start == "08:30" && $0.end == "10:00" }))
        XCTAssertTrue(slots.contains(where: { $0.status == "booked" && $0.booking?.reference == "ABC123" }))
    }

    func testParseBookingRowParsesDateAndDuration() {
        let row = [
            "",
            "BR-001",
            "15-Nov-2025 (Sat)\n13:00 - 16:00 (3hrs)",
            "SMU Connexion",
            "SMUC Meeting Pod 4-1",
            "Jane Doe",
            "Internal",
            "12.5",
            "Confirmed"
        ]

        let booking = LegacyScraperLogic.parseBookingRow(row)

        XCTAssertEqual(booking?.reference_number, "BR-001")
        XCTAssertEqual(booking?.day_of_week, "Sat")
        XCTAssertEqual(booking?.duration_hours, 3)
        XCTAssertEqual(booking?.price, 12.5)
    }

    func testParseTaskRowParsesTimes() {
        let row = [
            "",
            "TK-001",
            "15-Nov-2025\n16:00 - 19:00 (3hrs)",
            "SMU Connexion",
            "SMUC Meeting Pod 4-1",
            "Approval",
            "Jane Doe",
            "Pending Confirmation"
        ]

        let task = LegacyScraperLogic.parseTaskRow(row)

        XCTAssertEqual(task?.reference_number, "TK-001")
        XCTAssertEqual(task?.start_time, "16:00")
        XCTAssertEqual(task?.end_time, "19:00")
        XCTAssertEqual(task?.duration_hours, 3)
    }

    func testBootstrapFixturesLoadFromLocalFixturesDirectory() throws {
        let snapshot = try ArchivedSnapshotBootstrapper().load()

        XCTAssertNotNil(snapshot.rooms)
        XCTAssertNotNil(snapshot.bookings)
        XCTAssertNotNil(snapshot.tasks)
        XCTAssertEqual(snapshot.rooms?.metadata.source, "Fixtures/bootstrap/rooms.json")
    }
}
