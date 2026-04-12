import XCTest
@testable import SagasuHelperCore

final class HelperServiceTests: XCTestCase {
    func testParseDefaultsToRefreshWithManualReason() {
        XCTAssertEqual(SagasuHelperArgumentParser.parse([]), .refresh(reason: "manual"))
    }

    func testParseRefreshWithCustomReason() {
        XCTAssertEqual(SagasuHelperArgumentParser.parse(["refresh", "scheduled"]), .refresh(reason: "scheduled"))
    }

    func testParseRefreshWithoutReasonDefaults() {
        XCTAssertEqual(SagasuHelperArgumentParser.parse(["refresh"]), .refresh(reason: "manual"))
    }

    func testParseServiceCommand() {
        XCTAssertEqual(SagasuHelperArgumentParser.parse(["service"]), .service)
    }

    func testParseXPCServiceCommand() {
        XCTAssertEqual(SagasuHelperArgumentParser.parse(["xpc-service"]), .xpcService)
    }

    func testParseBootstrapCommand() {
        XCTAssertEqual(SagasuHelperArgumentParser.parse(["bootstrap"]), .bootstrap)
    }

    func testParseUnknownCommandYieldsUsage() {
        XCTAssertEqual(SagasuHelperArgumentParser.parse(["nonsense"]), .usage)
    }
}
