import XCTest
@testable import SagasuHelper
@testable import SagasuShared

final class ScraperConfigTests: XCTestCase {
    func testLoadUsesInjectedPreferencesWhenEnvironmentIsEmpty() {
        let configuration = ScrapeConfiguration.load(
            environment: [:],
            now: makeDate("2026-03-14T00:00:00Z"),
            preferences: .init(
                date: "17-Mar-2026",
                start_time: "09:00",
                end_time: "18:00",
                buildings: ["SMU Connexion"],
                floors: ["4"],
                facility_types: ["Meeting Pod"],
                equipment: ["Whiteboard"],
                capacity: "4"
            )
        )

        XCTAssertEqual(configuration.date, "17-Mar-2026")
        XCTAssertEqual(configuration.startTime, "09:00")
        XCTAssertEqual(configuration.endTime, "18:00")
        XCTAssertEqual(configuration.filters.buildings, ["SMU Connexion"])
        XCTAssertEqual(configuration.filters.floors, ["4"])
        XCTAssertEqual(configuration.filters.facilityTypes, ["Meeting Pod"])
        XCTAssertEqual(configuration.filters.equipment, ["Whiteboard"])
        XCTAssertEqual(configuration.filters.capacity, "4")
    }

    func testEnvironmentOverridesInjectedPreferences() {
        let configuration = ScrapeConfiguration.load(
            environment: [
                "SCRAPE_DATE": "18-Mar-2026",
                "SCRAPE_START_TIME": "10:00",
                "SCRAPE_END_TIME": "20:00",
                "SCRAPE_BUILDING_NAMES": "School of Accountancy, Li Ka Shing Library",
                "SCRAPE_FLOOR_NAMES": "2, 3",
                "SCRAPE_FACILITY_TYPES": "Seminar Room",
                "SCRAPE_EQUIPMENT": "Projector, Whiteboard",
                "SCRAPE_ROOM_CAPACITY": "8"
            ],
            now: makeDate("2026-03-14T00:00:00Z"),
            preferences: .init(
                date: "17-Mar-2026",
                start_time: "09:00",
                end_time: "18:00",
                buildings: ["SMU Connexion"],
                floors: ["4"],
                facility_types: ["Meeting Pod"],
                equipment: ["Whiteboard"],
                capacity: "4"
            )
        )

        XCTAssertEqual(configuration.date, "18-Mar-2026")
        XCTAssertEqual(configuration.startTime, "10:00")
        XCTAssertEqual(configuration.endTime, "20:00")
        XCTAssertEqual(configuration.filters.buildings, ["School of Accountancy", "Li Ka Shing Library"])
        XCTAssertEqual(configuration.filters.floors, ["2", "3"])
        XCTAssertEqual(configuration.filters.facilityTypes, ["Seminar Room"])
        XCTAssertEqual(configuration.filters.equipment, ["Projector", "Whiteboard"])
        XCTAssertEqual(configuration.filters.capacity, "8")
    }

    func testTodayPreferenceResolvesUsingProvidedDate() {
        let configuration = ScrapeConfiguration.load(
            environment: [:],
            now: makeDate("2026-03-14T00:00:00Z"),
            preferences: .init(date: "TODAY")
        )

        XCTAssertEqual(configuration.date, "14-Mar-2026")
    }

    private func makeDate(_ rawValue: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: rawValue) ?? Date(timeIntervalSince1970: 0)
    }
}
