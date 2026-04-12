import Foundation
import XCTest
@testable import SagasuShared

final class ScrapePreferencesTests: XCTestCase {
    func testDefaultValues() {
        let prefs = ScrapePreferences()
        XCTAssertEqual(prefs.date, "TODAY")
        XCTAssertEqual(prefs.start_time, "08:00")
        XCTAssertEqual(prefs.end_time, "22:00")
        XCTAssertTrue(prefs.buildings.isEmpty)
        XCTAssertTrue(prefs.floors.isEmpty)
        XCTAssertTrue(prefs.facility_types.isEmpty)
        XCTAssertTrue(prefs.equipment.isEmpty)
        XCTAssertEqual(prefs.capacity, "")
    }

    func testEquatableWithIdenticalValues() {
        let a = ScrapePreferences(date: "14-Mar-2026", start_time: "09:00", end_time: "18:00", buildings: ["A"], capacity: "4")
        let b = ScrapePreferences(date: "14-Mar-2026", start_time: "09:00", end_time: "18:00", buildings: ["A"], capacity: "4")
        XCTAssertEqual(a, b)
    }

    func testEquatableWithDifferentValues() {
        let a = ScrapePreferences(date: "14-Mar-2026")
        let b = ScrapePreferences(date: "15-Mar-2026")
        XCTAssertNotEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        let prefs = ScrapePreferences(
            date: "17-Mar-2026",
            start_time: "09:00",
            end_time: "18:00",
            buildings: ["SMU Connexion", "Li Ka Shing Library"],
            floors: ["2", "4"],
            facility_types: ["Meeting Pod", "Seminar Room"],
            equipment: ["Whiteboard", "Projector"],
            capacity: "8"
        )
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(ScrapePreferences.self, from: data)
        XCTAssertEqual(decoded, prefs)
    }

    func testCodableProducesExpectedJSONKeys() throws {
        let prefs = ScrapePreferences()
        let data = try JSONEncoder().encode(prefs)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json?["date"])
        XCTAssertNotNil(json?["start_time"])
        XCTAssertNotNil(json?["end_time"])
        XCTAssertNotNil(json?["buildings"])
        XCTAssertNotNil(json?["floors"])
        XCTAssertNotNil(json?["facility_types"])
        XCTAssertNotNil(json?["equipment"])
        XCTAssertNotNil(json?["capacity"])
    }

    func testDecodingFromPartialJSONUsesDefaults() throws {
        // ScrapePreferences requires all keys (no optional fields), so partial JSON should fail
        let partialJSON = #"{"date":"14-Mar-2026"}"#
        let data = Data(partialJSON.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(ScrapePreferences.self, from: data))
    }

    func testEmptyArraysRoundTrip() throws {
        let prefs = ScrapePreferences(buildings: [], floors: [], facility_types: [], equipment: [])
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(ScrapePreferences.self, from: data)
        XCTAssertTrue(decoded.buildings.isEmpty)
        XCTAssertTrue(decoded.floors.isEmpty)
        XCTAssertTrue(decoded.facility_types.isEmpty)
        XCTAssertTrue(decoded.equipment.isEmpty)
    }
}
