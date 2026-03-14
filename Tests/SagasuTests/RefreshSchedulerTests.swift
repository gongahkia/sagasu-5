import XCTest
@testable import SagasuHelper

final class RefreshSchedulerTests: XCTestCase {
    func testNextRefreshDelayTargetsSameDayBeforeCutoff() {
        let scheduler = RefreshScheduler(
            timeZone: TimeZone(identifier: "Asia/Singapore") ?? .current,
            refreshHour: 8,
            refreshMinute: 15
        )

        let delay = scheduler.nextRefreshDelay(from: makeDate("2026-03-14T00:00:00Z"))

        XCTAssertEqual(delay, 15 * 60, accuracy: 1)
    }

    func testNextRefreshDelayRollsToNextDayAfterCutoff() {
        let scheduler = RefreshScheduler(
            timeZone: TimeZone(identifier: "Asia/Singapore") ?? .current,
            refreshHour: 8,
            refreshMinute: 15
        )

        let delay = scheduler.nextRefreshDelay(from: makeDate("2026-03-14T01:00:00Z"))

        XCTAssertEqual(delay, (23 * 60 + 15) * 60, accuracy: 1)
    }

    func testNextRefreshDelayHonorsMinimumDelay() {
        let scheduler = RefreshScheduler(
            timeZone: TimeZone(identifier: "Asia/Singapore") ?? .current,
            refreshHour: 8,
            refreshMinute: 15,
            minimumDelay: 60
        )

        let delay = scheduler.nextRefreshDelay(from: makeDate("2026-03-14T00:14:30Z"))

        XCTAssertEqual(delay, 60, accuracy: 1)
    }

    private func makeDate(_ rawValue: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: rawValue) ?? Date(timeIntervalSince1970: 0)
    }
}
