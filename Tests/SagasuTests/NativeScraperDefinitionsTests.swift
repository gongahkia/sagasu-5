import XCTest
@testable import SagasuHelperCore

final class NativeScraperDefinitionsTests: XCTestCase {
    func testLandingAndHomeURLs() {
        XCTAssertEqual(NativeScraperDefinitions.landingURL, "https://www.smubondue.com/facility-booking-system-fbs")
        XCTAssertEqual(NativeScraperDefinitions.homeURL, "https://fbs.intranet.smu.edu.sg/home")
    }

    func testLoginPatternsAreRegex() {
        XCTAssertTrue(NativeScraperDefinitions.microsoftLoginPattern.contains("login"))
        XCTAssertTrue(NativeScraperDefinitions.smuLoginPattern.contains("smu"))
        XCTAssertTrue(NativeScraperDefinitions.dashboardPattern.contains("fbs"))
    }

    func testSelectorsExposeKeyFormFields() {
        XCTAssertTrue(NativeScraperDefinitions.Selectors.dateInput.contains("DateBookingFrom"))
        XCTAssertTrue(NativeScraperDefinitions.Selectors.timeFrom.contains("TimeFrom"))
        XCTAssertTrue(NativeScraperDefinitions.Selectors.timeTo.contains("TimeTo"))
        XCTAssertTrue(NativeScraperDefinitions.Selectors.capacity.contains("DropCapacity"))
        XCTAssertTrue(NativeScraperDefinitions.Selectors.buildingPicker.contains("DropMultiBuildingList"))
        XCTAssertTrue(NativeScraperDefinitions.Selectors.floorPicker.contains("DropMultiFloorList"))
        XCTAssertTrue(NativeScraperDefinitions.Selectors.facilityPicker.contains("DropMultiFacilityTypeList"))
        XCTAssertTrue(NativeScraperDefinitions.Selectors.equipmentPicker.contains("DropMultiEquipmentList"))
    }

    func testQuerySelectorExistsProducesBooleanExpression() {
        let script = NativeScraperDefinitions.JavaScript.querySelectorExists("#a")
        XCTAssertTrue(script.hasPrefix("Boolean(document.querySelector"))
        XCTAssertTrue(script.contains("\"#a\""))
    }

    func testFillEscapesValueAndBuildsExpression() {
        let script = NativeScraperDefinitions.JavaScript.fill("#x", value: "hello\"world")
        XCTAssertTrue(script.contains("document.querySelector(\"#x\")"))
        XCTAssertTrue(script.contains("\"hello\\\"world\""))
        XCTAssertTrue(script.contains("dispatchEvent"))
    }

    func testSelectEscapesBackslashes() {
        let script = NativeScraperDefinitions.JavaScript.select("#y", value: "a\\b")
        XCTAssertTrue(script.contains("\"a\\\\b\""))
    }

    func testClickTextBuildsMatcher() {
        let script = NativeScraperDefinitions.JavaScript.clickText("Book")
        XCTAssertTrue(script.contains("\"Book\""))
        XCTAssertTrue(script.contains("textContent"))
    }

    func testRowsMatrixQueriesSelector() {
        let script = NativeScraperDefinitions.JavaScript.rowsMatrix("table tr")
        XCTAssertTrue(script.contains("\"table tr\""))
        XCTAssertTrue(script.contains("querySelectorAll"))
    }

    func testNestedFrameExpressionWrapsBodyWithFrameLookup() {
        let script = NativeScraperDefinitions.JavaScript.nestedFrameExpression("return 1;")
        XCTAssertTrue(script.contains("iframe#frameBottom"))
        XCTAssertTrue(script.contains("iframe#frameContent"))
        XCTAssertTrue(script.contains("return 1;"))
    }

    func testQuerySelectorAttributeIncludesAttributeName() {
        let script = NativeScraperDefinitions.JavaScript.querySelectorAttribute("#a", attribute: "href")
        XCTAssertTrue(script.contains("\"#a\""))
        XCTAssertTrue(script.contains("\"href\""))
    }
}
