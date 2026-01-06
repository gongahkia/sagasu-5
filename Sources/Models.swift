import Foundation

struct ScrapedRoomsResponse: Codable {
    struct Metadata: Codable {
        let version: String
        let scraped_at: String
        let scrape_duration_ms: Int
        let success: Bool
        let error: String?
        let scraper_version: String
    }

    struct Config: Codable {
        let date: String
        let start_time: String
        let end_time: String
    }

    struct Statistics: Codable {
        let total_rooms: Int
        let available_rooms: Int
        let booked_rooms: Int
        let partially_available_rooms: Int
    }

    struct Room: Codable, Identifiable {
        let id: String
        let name: String
        let building: String
        let building_code: String
        let floor: String
        let facility_type: String
        let equipment: [String]
        let availability_summary: AvailabilitySummary
    }

    struct AvailabilitySummary: Codable {
        let is_available_now: Bool
        let next_available_at: String?
        let free_slots_count: Int
        let free_duration_minutes: Int
    }

    let metadata: Metadata
    let config: Config
    let statistics: Statistics
    let rooms: [Room]?
}

struct ScrapedBookingsResponse: Codable {
    struct Metadata: Codable {
        let version: String
        let scraped_at: String
        let scrape_duration_ms: Int
        let success: Bool
        let error: String?
        let scraper_version: String
    }

    struct Statistics: Codable {
        let total_bookings: Int
        let confirmed_bookings: Int
        let pending_bookings: Int
        let total_price: Int
    }

    let metadata: Metadata
    let statistics: Statistics
}

struct ScrapedTasksResponse: Codable {
    struct Metadata: Codable {
        let version: String
        let scraped_at: String
        let scrape_duration_ms: Int
        let success: Bool
        let error: String?
        let scraper_version: String
    }

    struct Statistics: Codable {
        let total_tasks: Int
        let pending_tasks: Int
        let approved_tasks: Int
        let rejected_tasks: Int
    }

    let metadata: Metadata
    let statistics: Statistics
}
