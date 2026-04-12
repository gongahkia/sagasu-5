import XCTest
@testable import SagasuHelperCore

final class NativeAutomationDriverTests: XCTestCase {
    struct SimulatedError: Error, Equatable {}

    func testRetrySucceedsOnFirstAttempt() throws {
        var calls = 0
        var sleeps: [Int] = []
        try retryWithBackoffImpl(
            maxAttempts: 3,
            baseDelay: 1.0,
            sleep: { sleeps.append($0) },
            logger: nil,
            operation: { calls += 1 }
        )
        XCTAssertEqual(calls, 1)
        XCTAssertTrue(sleeps.isEmpty)
    }

    func testRetrySucceedsOnSecondAttemptAfterOneFailure() throws {
        var calls = 0
        var sleeps: [Int] = []
        try retryWithBackoffImpl(
            maxAttempts: 3,
            baseDelay: 1.0,
            sleep: { sleeps.append($0) },
            logger: nil,
            operation: {
                calls += 1
                if calls < 2 { throw SimulatedError() }
            }
        )
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(sleeps, [1000]) // first backoff: 1s * 2^0 = 1000ms
    }

    func testRetryExhaustsAndThrowsLastError() {
        var calls = 0
        var sleeps: [Int] = []
        XCTAssertThrowsError(
            try retryWithBackoffImpl(
                maxAttempts: 3,
                baseDelay: 2.0,
                sleep: { sleeps.append($0) },
                logger: nil,
                operation: {
                    calls += 1
                    throw SimulatedError()
                }
            )
        ) { err in
            XCTAssertTrue(err is SimulatedError)
        }
        XCTAssertEqual(calls, 3)
        XCTAssertEqual(sleeps, [2000, 4000]) // 2s, then 4s
    }

    func testNativeAutomationErrorDescription() {
        let err = NativeAutomationError.actionFailed("boom")
        XCTAssertEqual(err.errorDescription, "boom")
    }
}
