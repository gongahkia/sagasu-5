import Foundation

struct ScrapeConfiguration: Sendable {
    struct Filters: Sendable {
        var buildings: [String]
        var floors: [String]
        var facilityTypes: [String]
        var equipment: [String]
        var capacity: String
    }

    var date: String
    var startTime: String
    var endTime: String
    var filters: Filters

    static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        now: Date = Date()
    ) -> ScrapeConfiguration {
        let date = resolvedDate(environment: environment, now: now)
        return ScrapeConfiguration(
            date: date,
            startTime: environment["SCRAPE_START_TIME"] ?? "08:00",
            endTime: environment["SCRAPE_END_TIME"] ?? "22:00",
            filters: .init(
                buildings: split(environment["SCRAPE_BUILDING_NAMES"]),
                floors: split(environment["SCRAPE_FLOOR_NAMES"]),
                facilityTypes: split(environment["SCRAPE_FACILITY_TYPES"]),
                equipment: split(environment["SCRAPE_EQUIPMENT"]),
                capacity: environment["SCRAPE_ROOM_CAPACITY"] ?? ""
            )
        )
    }

    private static func split(_ value: String?) -> [String] {
        guard let value, !value.isEmpty else { return [] }
        return value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func resolvedDate(environment: [String: String], now: Date) -> String {
        if let rawDate = environment["SCRAPE_DATE"], !rawDate.isEmpty, rawDate != "TODAY" {
            return rawDate
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd-MMM-yyyy"
        return formatter.string(from: now)
    }
}
