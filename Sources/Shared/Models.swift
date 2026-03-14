import Foundation

public enum ScrapeDataset: String, Codable, CaseIterable, Sendable {
    case rooms
    case bookings
    case tasks
}

public enum DatasetState: String, Codable, CaseIterable, Sendable {
    case idle
    case loading
    case success
    case stale
    case failed
}

public struct DatasetStatus: Codable, Sendable, Identifiable {
    public var dataset: ScrapeDataset
    public var state: DatasetState
    public var last_attempt_at: String?
    public var last_success_at: String?
    public var message: String?

    public var id: String { dataset.rawValue }

    public init(
        dataset: ScrapeDataset,
        state: DatasetState = .idle,
        last_attempt_at: String? = nil,
        last_success_at: String? = nil,
        message: String? = nil
    ) {
        self.dataset = dataset
        self.state = state
        self.last_attempt_at = last_attempt_at
        self.last_success_at = last_success_at
        self.message = message
    }
}

public struct AuthState: Codable, Sendable {
    public enum StorageMode: String, Codable, Sendable {
        case none
        case environment
        case keychain
    }

    public var has_credentials: Bool
    public var storage_mode: StorageMode
    public var runtime: String
    public var last_error: String?

    public init(
        has_credentials: Bool = false,
        storage_mode: StorageMode = .none,
        runtime: String = "Unavailable",
        last_error: String? = nil
    ) {
        self.has_credentials = has_credentials
        self.storage_mode = storage_mode
        self.runtime = runtime
        self.last_error = last_error
    }
}

public struct ScrapeRequest: Codable, Sendable {
    public var datasets: [ScrapeDataset]
    public var reason: String
    public var manual: Bool

    public init(
        datasets: [ScrapeDataset] = ScrapeDataset.allCases,
        reason: String = "manual-refresh",
        manual: Bool = true
    ) {
        self.datasets = datasets
        self.reason = reason
        self.manual = manual
    }
}

public struct ServiceSnapshot: Codable, Sendable {
    public var generated_at: String
    public var statuses: [DatasetStatus]
    public var auth_state: AuthState
    public var rooms: ScrapedRoomsResponse?
    public var bookings: ScrapedBookingsResponse?
    public var tasks: ScrapedTasksResponse?

    public init(
        generated_at: String = Date().iso8601String,
        statuses: [DatasetStatus] = ScrapeDataset.allCases.map { DatasetStatus(dataset: $0) },
        auth_state: AuthState = AuthState(),
        rooms: ScrapedRoomsResponse? = nil,
        bookings: ScrapedBookingsResponse? = nil,
        tasks: ScrapedTasksResponse? = nil
    ) {
        self.generated_at = generated_at
        self.statuses = statuses
        self.auth_state = auth_state
        self.rooms = rooms
        self.bookings = bookings
        self.tasks = tasks
    }

    public func status(for dataset: ScrapeDataset) -> DatasetStatus {
        statuses.first(where: { $0.dataset == dataset }) ?? DatasetStatus(dataset: dataset)
    }

    public mutating func setStatus(_ status: DatasetStatus) {
        if let index = statuses.firstIndex(where: { $0.dataset == status.dataset }) {
            statuses[index] = status
        } else {
            statuses.append(status)
        }
    }
}

public struct ScrapedRoomsResponse: Codable, Sendable {
    public struct Metadata: Codable, Sendable {
        public var version: String
        public var scraped_at: String
        public var scrape_duration_ms: Int
        public var success: Bool
        public var error: String?
        public var scraper_version: String
        public var source: String?

        public init(
            version: String,
            scraped_at: String,
            scrape_duration_ms: Int,
            success: Bool,
            error: String?,
            scraper_version: String,
            source: String? = nil
        ) {
            self.version = version
            self.scraped_at = scraped_at
            self.scrape_duration_ms = scrape_duration_ms
            self.success = success
            self.error = error
            self.scraper_version = scraper_version
            self.source = source
        }
    }

    public struct Config: Codable, Sendable {
        public struct Filters: Codable, Sendable {
            public var buildings: [String]
            public var floors: [String]
            public var facility_types: [String]
            public var equipment: [String]
            public var capacity: String

            public init(
                buildings: [String] = [],
                floors: [String] = [],
                facility_types: [String] = [],
                equipment: [String] = [],
                capacity: String = ""
            ) {
                self.buildings = buildings
                self.floors = floors
                self.facility_types = facility_types
                self.equipment = equipment
                self.capacity = capacity
            }
        }

        public var date: String
        public var start_time: String
        public var end_time: String
        public var filters: Filters?

        public init(
            date: String,
            start_time: String,
            end_time: String,
            filters: Filters? = nil
        ) {
            self.date = date
            self.start_time = start_time
            self.end_time = end_time
            self.filters = filters
        }
    }

    public struct Statistics: Codable, Sendable {
        public var total_rooms: Int
        public var available_rooms: Int
        public var booked_rooms: Int
        public var partially_available_rooms: Int

        public init(
            total_rooms: Int,
            available_rooms: Int,
            booked_rooms: Int,
            partially_available_rooms: Int
        ) {
            self.total_rooms = total_rooms
            self.available_rooms = available_rooms
            self.booked_rooms = booked_rooms
            self.partially_available_rooms = partially_available_rooms
        }
    }

    public struct Room: Codable, Sendable, Identifiable {
        public struct TimeSlot: Codable, Sendable {
            public struct BookingDetails: Codable, Sendable {
                public var reference: String?
                public var status: String?
                public var booker_name: String?
                public var booker_email: String?
                public var booker_org: String?
                public var purpose: String?
                public var use_type: String?

                public init(
                    reference: String? = nil,
                    status: String? = nil,
                    booker_name: String? = nil,
                    booker_email: String? = nil,
                    booker_org: String? = nil,
                    purpose: String? = nil,
                    use_type: String? = nil
                ) {
                    self.reference = reference
                    self.status = status
                    self.booker_name = booker_name
                    self.booker_email = booker_email
                    self.booker_org = booker_org
                    self.purpose = purpose
                    self.use_type = use_type
                }
            }

            public var start: String
            public var end: String
            public var status: String
            public var reason: String?
            public var booking: BookingDetails?

            public init(
                start: String,
                end: String,
                status: String,
                reason: String? = nil,
                booking: BookingDetails? = nil
            ) {
                self.start = start
                self.end = end
                self.status = status
                self.reason = reason
                self.booking = booking
            }
        }

        public struct AvailabilitySummary: Codable, Sendable {
            public var is_available_now: Bool
            public var next_available_at: String?
            public var free_slots_count: Int
            public var free_duration_minutes: Int

            public init(
                is_available_now: Bool,
                next_available_at: String?,
                free_slots_count: Int,
                free_duration_minutes: Int
            ) {
                self.is_available_now = is_available_now
                self.next_available_at = next_available_at
                self.free_slots_count = free_slots_count
                self.free_duration_minutes = free_duration_minutes
            }
        }

        public var id: String
        public var name: String
        public var building: String
        public var building_code: String
        public var floor: String
        public var facility_type: String
        public var equipment: [String]
        public var timeslots: [TimeSlot]
        public var availability_summary: AvailabilitySummary

        public init(
            id: String,
            name: String,
            building: String,
            building_code: String,
            floor: String,
            facility_type: String,
            equipment: [String],
            timeslots: [TimeSlot],
            availability_summary: AvailabilitySummary
        ) {
            self.id = id
            self.name = name
            self.building = building
            self.building_code = building_code
            self.floor = floor
            self.facility_type = facility_type
            self.equipment = equipment
            self.timeslots = timeslots
            self.availability_summary = availability_summary
        }
    }

    public var metadata: Metadata
    public var config: Config
    public var statistics: Statistics
    public var rooms: [Room]?

    public init(
        metadata: Metadata,
        config: Config,
        statistics: Statistics,
        rooms: [Room]?
    ) {
        self.metadata = metadata
        self.config = config
        self.statistics = statistics
        self.rooms = rooms
    }
}

public struct ScrapedBookingsResponse: Codable, Sendable {
    public struct Metadata: Codable, Sendable {
        public var version: String
        public var scraped_at: String
        public var scrape_duration_ms: Int
        public var success: Bool
        public var error: String?
        public var scraper_version: String
        public var source: String?

        public init(
            version: String,
            scraped_at: String,
            scrape_duration_ms: Int,
            success: Bool,
            error: String?,
            scraper_version: String,
            source: String? = nil
        ) {
            self.version = version
            self.scraped_at = scraped_at
            self.scrape_duration_ms = scrape_duration_ms
            self.success = success
            self.error = error
            self.scraper_version = scraper_version
            self.source = source
        }
    }

    public struct Statistics: Codable, Sendable {
        public var total_bookings: Int
        public var confirmed_bookings: Int
        public var pending_bookings: Int
        public var total_price: Double

        public init(
            total_bookings: Int,
            confirmed_bookings: Int,
            pending_bookings: Int,
            total_price: Double
        ) {
            self.total_bookings = total_bookings
            self.confirmed_bookings = confirmed_bookings
            self.pending_bookings = pending_bookings
            self.total_price = total_price
        }
    }

    public struct Booking: Codable, Sendable, Identifiable {
        public var reference_number: String
        public var date: String
        public var day_of_week: String?
        public var start_time: String
        public var end_time: String
        public var duration_hours: Double
        public var building: String
        public var room_name: String
        public var booked_by: String
        public var booking_type: String
        public var price: Double
        public var status: String
        public var raw_datetime: String?

        public var id: String { reference_number }

        public init(
            reference_number: String,
            date: String,
            day_of_week: String? = nil,
            start_time: String,
            end_time: String,
            duration_hours: Double,
            building: String,
            room_name: String,
            booked_by: String,
            booking_type: String,
            price: Double,
            status: String,
            raw_datetime: String? = nil
        ) {
            self.reference_number = reference_number
            self.date = date
            self.day_of_week = day_of_week
            self.start_time = start_time
            self.end_time = end_time
            self.duration_hours = duration_hours
            self.building = building
            self.room_name = room_name
            self.booked_by = booked_by
            self.booking_type = booking_type
            self.price = price
            self.status = status
            self.raw_datetime = raw_datetime
        }
    }

    public var metadata: Metadata
    public var statistics: Statistics
    public var bookings: [Booking]

    public init(
        metadata: Metadata,
        statistics: Statistics,
        bookings: [Booking]
    ) {
        self.metadata = metadata
        self.statistics = statistics
        self.bookings = bookings
    }
}

public struct ScrapedTasksResponse: Codable, Sendable {
    public struct Metadata: Codable, Sendable {
        public var version: String
        public var scraped_at: String
        public var scrape_duration_ms: Int
        public var success: Bool
        public var error: String?
        public var scraper_version: String
        public var source: String?

        public init(
            version: String,
            scraped_at: String,
            scrape_duration_ms: Int,
            success: Bool,
            error: String?,
            scraper_version: String,
            source: String? = nil
        ) {
            self.version = version
            self.scraped_at = scraped_at
            self.scrape_duration_ms = scrape_duration_ms
            self.success = success
            self.error = error
            self.scraper_version = scraper_version
            self.source = source
        }
    }

    public struct Statistics: Codable, Sendable {
        public var total_tasks: Int
        public var pending_tasks: Int
        public var approved_tasks: Int
        public var rejected_tasks: Int

        public init(
            total_tasks: Int,
            pending_tasks: Int,
            approved_tasks: Int,
            rejected_tasks: Int
        ) {
            self.total_tasks = total_tasks
            self.pending_tasks = pending_tasks
            self.approved_tasks = approved_tasks
            self.rejected_tasks = rejected_tasks
        }
    }

    public struct Task: Codable, Sendable, Identifiable {
        public var reference_number: String
        public var date: String
        public var start_time: String
        public var end_time: String
        public var duration_hours: Double
        public var building: String
        public var room_name: String
        public var task_type: String
        public var requested_by: String
        public var status: String
        public var raw_datetime: String?

        public var id: String { reference_number }

        public init(
            reference_number: String,
            date: String,
            start_time: String,
            end_time: String,
            duration_hours: Double,
            building: String,
            room_name: String,
            task_type: String,
            requested_by: String,
            status: String,
            raw_datetime: String? = nil
        ) {
            self.reference_number = reference_number
            self.date = date
            self.start_time = start_time
            self.end_time = end_time
            self.duration_hours = duration_hours
            self.building = building
            self.room_name = room_name
            self.task_type = task_type
            self.requested_by = requested_by
            self.status = status
            self.raw_datetime = raw_datetime
        }
    }

    public var metadata: Metadata
    public var statistics: Statistics
    public var tasks: [Task]

    public init(
        metadata: Metadata,
        statistics: Statistics,
        tasks: [Task]
    ) {
        self.metadata = metadata
        self.statistics = statistics
        self.tasks = tasks
    }
}

public extension Date {
    var iso8601String: String {
        ISO8601DateFormatter.sagasuInternetDateTime.string(from: self)
    }
}

public extension ISO8601DateFormatter {
    static let sagasuInternetDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
