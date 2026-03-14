import Foundation

public struct RefreshScheduler {
    public let timeZone: TimeZone
    public let refreshHour: Int
    public let refreshMinute: Int
    public let minimumDelay: TimeInterval
    public let fallbackDelay: TimeInterval

    public init(
        timeZone: TimeZone = TimeZone(identifier: "Asia/Singapore") ?? .current,
        refreshHour: Int = 8,
        refreshMinute: Int = 15,
        minimumDelay: TimeInterval = 60,
        fallbackDelay: TimeInterval = 60 * 60
    ) {
        self.timeZone = timeZone
        self.refreshHour = refreshHour
        self.refreshMinute = refreshMinute
        self.minimumDelay = minimumDelay
        self.fallbackDelay = fallbackDelay
    }

    public func nextRefreshDelay(from now: Date, calendar: Calendar = .current) -> TimeInterval {
        var calendar = calendar
        calendar.timeZone = timeZone

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = refreshHour
        components.minute = refreshMinute
        components.second = 0

        guard var next = calendar.date(from: components) else {
            return fallbackDelay
        }

        if next <= now {
            next = calendar.date(byAdding: .day, value: 1, to: next) ?? next
        }

        return max(minimumDelay, next.timeIntervalSince(now))
    }
}
