import XCTest
@testable import SagasuHelperCore
@testable import SagasuShared

final class NativeFBSLiveScraperTests: XCTestCase {
    func testRetryDelayScalesLinearly() {
        XCTAssertEqual(NativeFBSLiveScraperHelpers.retryDelayMilliseconds(for: 1), 1500)
        XCTAssertEqual(NativeFBSLiveScraperHelpers.retryDelayMilliseconds(for: 2), 3000)
        XCTAssertEqual(NativeFBSLiveScraperHelpers.retryDelayMilliseconds(for: 3), 4500)
    }

    func testRetryDelayClampsLowAttemptToOne() {
        XCTAssertEqual(NativeFBSLiveScraperHelpers.retryDelayMilliseconds(for: 0), 1500)
        XCTAssertEqual(NativeFBSLiveScraperHelpers.retryDelayMilliseconds(for: -5), 1500)
    }

    func testScrapeAttemptErrorDescriptionIncludesDatasetStageAndDiagnostics() {
        let url = URL(fileURLWithPath: "/tmp/diag.html")
        let err = ScrapeAttemptError(
            dataset: .rooms,
            stage: "rooms",
            attempt: 2,
            diagnosticsURL: url,
            underlyingError: NativeAutomationError.actionFailed("boom")
        )
        let desc = err.errorDescription ?? ""
        XCTAssertTrue(desc.contains("rooms"))
        XCTAssertTrue(desc.contains("attempt 2"))
        XCTAssertTrue(desc.contains("boom"))
        XCTAssertTrue(desc.contains("/tmp/diag.html"))
    }

    func testScrapeAttemptErrorWithoutDatasetOrDiagnostics() {
        let err = ScrapeAttemptError(
            dataset: nil,
            stage: "authenticate",
            attempt: 1,
            diagnosticsURL: nil,
            underlyingError: NativeAutomationError.actionFailed("x")
        )
        let desc = err.errorDescription ?? ""
        XCTAssertTrue(desc.contains("authenticate"))
        XCTAssertFalse(desc.contains("Diagnostics"))
    }
}
