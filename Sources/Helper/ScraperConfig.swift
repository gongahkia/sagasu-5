import Foundation
import SagasuShared

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
        let storedPreferences = (try? ScrapePreferencesStore().load()) ?? ScrapePreferences()
        let date = resolvedDate(preferences: storedPreferences, environment: environment, now: now)
        return ScrapeConfiguration(
            date: date,
            startTime: environment["SCRAPE_START_TIME"] ?? storedPreferences.start_time,
            endTime: environment["SCRAPE_END_TIME"] ?? storedPreferences.end_time,
            filters: .init(
                buildings: overrideOrStored(environment["SCRAPE_BUILDING_NAMES"], stored: storedPreferences.buildings),
                floors: overrideOrStored(environment["SCRAPE_FLOOR_NAMES"], stored: storedPreferences.floors),
                facilityTypes: overrideOrStored(environment["SCRAPE_FACILITY_TYPES"], stored: storedPreferences.facility_types),
                equipment: overrideOrStored(environment["SCRAPE_EQUIPMENT"], stored: storedPreferences.equipment),
                capacity: environment["SCRAPE_ROOM_CAPACITY"] ?? storedPreferences.capacity
            )
        )
    }

    private static func overrideOrStored(_ value: String?, stored: [String]) -> [String] {
        guard let value, !value.isEmpty else { return stored }
        return split(value)
    }

    private static func split(_ value: String?) -> [String] {
        guard let value, !value.isEmpty else { return [] }
        return value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func resolvedDate(preferences: ScrapePreferences, environment: [String: String], now: Date) -> String {
        if let rawDate = environment["SCRAPE_DATE"], !rawDate.isEmpty, rawDate != "TODAY" {
            return rawDate
        }

        if preferences.date != "TODAY", !preferences.date.isEmpty {
            return preferences.date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd-MMM-yyyy"
        return formatter.string(from: now)
    }
}
