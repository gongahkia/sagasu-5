import Foundation
import SagasuAutomationObjC
import SagasuCore
import SagasuShared

// pure helpers extracted for unit testing (no WebKit deps)
enum NativeFBSLiveScraperHelpers {
    static func retryDelayMilliseconds(for attempt: Int) -> Int {
        1500 * max(1, attempt)
    }
}

struct PartialScrapeOutputs {
    var rooms: Result<ScrapedRoomsResponse, Error>?
    var bookings: Result<ScrapedBookingsResponse, Error>?
    var tasks: Result<ScrapedTasksResponse, Error>?
}

struct ScrapeAttemptError: LocalizedError {
    let dataset: ScrapeDataset?
    let stage: String
    let attempt: Int
    let diagnosticsURL: URL?
    let underlyingError: Error

    var errorDescription: String? {
        var parts = ["\(stage) attempt \(attempt) failed: \(underlyingError.localizedDescription)"]
        if let dataset {
            parts.insert("\(dataset.rawValue)", at: 0)
        }
        if let diagnosticsURL {
            parts.append("Diagnostics: \(diagnosticsURL.path)")
        }
        return parts.joined(separator: " ")
    }
}

final class NativeFBSLiveScraper {
    private let driver: NativeAutomationDriver
    private let config: ScrapeConfiguration
    private let diagnosticsStore: ScrapeDiagnosticsStore?

    init(
        driver: NativeAutomationDriver = NativeAutomationDriver(),
        config: ScrapeConfiguration = .load(),
        diagnosticsStore: ScrapeDiagnosticsStore? = try? ScrapeDiagnosticsStore()
    ) {
        self.driver = driver
        self.config = config
        self.diagnosticsStore = diagnosticsStore
    }

    func scrapeAll(credentials: SharedCredentials) -> PartialScrapeOutputs {
        do {
            try retrying(stage: "authenticate", attempts: 2) {
                try authenticate(credentials: credentials)
            }
        } catch {
            return PartialScrapeOutputs(
                rooms: .failure(error),
                bookings: .failure(error),
                tasks: .failure(error)
            )
        }

        return PartialScrapeOutputs(
            rooms: captureResult(dataset: .rooms, stage: "rooms") { try scrapeRooms() },
            bookings: captureResult(dataset: .bookings, stage: "bookings") { try scrapeBookings() },
            tasks: captureResult(dataset: .tasks, stage: "tasks") { try scrapeTasks() }
        )
    }

    private func authenticate(credentials: SharedCredentials) throws {
        try driver.load(NativeScraperDefinitions.landingURL)

        if let href = try driver.attribute(selector: NativeScraperDefinitions.Selectors.fbsLink, name: "href"), !href.isEmpty {
            try driver.load(href)
        } else {
            try driver.click(selector: NativeScraperDefinitions.Selectors.fbsLink)
        }

        try driver.waitForURL(NativeScraperDefinitions.microsoftLoginPattern)
        try driver.waitFor(scriptCondition: NativeScraperDefinitions.JavaScript.querySelectorExists(NativeScraperDefinitions.Selectors.emailInput))
        try driver.fill(selector: "#i0116", value: credentials.email)
        try driver.click(selector: "#idSIButton9")

        do {
            try driver.waitForURL(NativeScraperDefinitions.smuLoginPattern, timeout: 10)
        } catch {
            if let href = try driver.attribute(selector: NativeScraperDefinitions.Selectors.redirectLink, name: "href"), !href.isEmpty {
                try driver.load(href)
            } else {
                try driver.click(selector: NativeScraperDefinitions.Selectors.redirectLink)
            }
            try driver.waitForURL(NativeScraperDefinitions.smuLoginPattern)
        }

        try driver.waitFor(scriptCondition: NativeScraperDefinitions.JavaScript.querySelectorExists(NativeScraperDefinitions.Selectors.passwordInput))
        try driver.fill(selector: NativeScraperDefinitions.Selectors.passwordInput, value: credentials.password)
        try driver.click(selector: NativeScraperDefinitions.Selectors.passwordSubmit)
        try driver.waitForURL(NativeScraperDefinitions.dashboardPattern)
    }

    private func scrapeRooms() throws -> ScrapedRoomsResponse {
        let startedAt = Date()
        try driver.load(NativeScraperDefinitions.homeURL)
        try driver.waitForNestedFrameSelector(NativeScraperDefinitions.Selectors.dateInput)

        try driver.fillInNestedFrame(selector: NativeScraperDefinitions.Selectors.dateInput, value: config.date)
        try driver.selectInNestedFrame(selector: NativeScraperDefinitions.Selectors.timeFrom, value: config.startTime)
        try driver.selectInNestedFrame(selector: NativeScraperDefinitions.Selectors.timeTo, value: config.endTime)
        driver.sleep(milliseconds: 1500)

        try applyFilters()

        try driver.waitForNestedFrameSelector(NativeScraperDefinitions.Selectors.roomGrid)
        let matchingRooms = try driver.roomNamesInNestedFrame(selector: NativeScraperDefinitions.Selectors.roomRows)
        try driver.clickInNestedFrame(selector: NativeScraperDefinitions.Selectors.checkAvailability)
        driver.sleep(milliseconds: 10000)

        let rawBookings = try driver.titleAttributesInNestedFrame(selector: NativeScraperDefinitions.Selectors.schedulerEvents)
        let mapped = LegacyScraperLogic.mapTimeslotsToRooms(rawRooms: matchingRooms, rawTimeslots: rawBookings)
        let rooms = matchingRooms.map { roomName -> ScrapedRoomsResponse.Room in
            let timeslots = mapped[roomName] ?? []
            let metadata = LegacyScraperLogic.extractRoomMetadata(roomName: roomName, filters: config.filters)
            let summary = LegacyScraperLogic.calculateAvailabilitySummary(timeslots: timeslots)
            return .init(
                id: roomName,
                name: roomName,
                building: metadata.building,
                building_code: metadata.buildingCode,
                floor: metadata.floor,
                facility_type: metadata.facilityType,
                equipment: metadata.equipment,
                timeslots: timeslots,
                availability_summary: summary
            )
        }

        return .init(
            metadata: .init(
                version: "5.0.0",
                scraped_at: Date().iso8601String,
                scrape_duration_ms: Int(Date().timeIntervalSince(startedAt) * 1000),
                success: true,
                error: nil,
                scraper_version: "rooms-native-v1",
                source: SagasuAutomationRuntimeDescription()
            ),
            config: .init(
                date: config.date,
                start_time: config.startTime,
                end_time: config.endTime,
                filters: .init(
                    buildings: config.filters.buildings,
                    floors: config.filters.floors,
                    facility_types: config.filters.facilityTypes,
                    equipment: config.filters.equipment,
                    capacity: config.filters.capacity
                )
            ),
            statistics: LegacyScraperLogic.roomStatistics(from: rooms),
            rooms: rooms
        )
    }

    private func scrapeBookings() throws -> ScrapedBookingsResponse {
        let startedAt = Date()
        try driver.load(NativeScraperDefinitions.homeURL)
        try driver.waitForNestedFrameSelector(NativeScraperDefinitions.Selectors.myBookingsTab)
        try driver.clickInNestedFrame(selector: NativeScraperDefinitions.Selectors.myBookingsTab)
        driver.sleep(milliseconds: 15000)
        try driver.waitForNestedFrameSelector(NativeScraperDefinitions.Selectors.bookingsGrid)

        let rows = try driver.rowsMatrixInNestedFrame(selector: NativeScraperDefinitions.Selectors.bookingRows)
        let bookings = rows.compactMap(LegacyScraperLogic.parseBookingRow)

        return .init(
            metadata: .init(
                version: "5.0.0",
                scraped_at: Date().iso8601String,
                scrape_duration_ms: Int(Date().timeIntervalSince(startedAt) * 1000),
                success: true,
                error: nil,
                scraper_version: "bookings-native-v1",
                source: SagasuAutomationRuntimeDescription()
            ),
            statistics: LegacyScraperLogic.bookingStatistics(from: bookings),
            bookings: bookings
        )
    }

    private func scrapeTasks() throws -> ScrapedTasksResponse {
        let startedAt = Date()
        try driver.load(NativeScraperDefinitions.homeURL)
        try driver.waitForNestedFrameSelector(NativeScraperDefinitions.Selectors.taskListTab)
        try driver.clickInNestedFrame(selector: NativeScraperDefinitions.Selectors.taskListTab)
        driver.sleep(milliseconds: 15000)
        try driver.waitForNestedFrameSelector(NativeScraperDefinitions.Selectors.tasksGrid)

        let rows = try driver.rowsMatrixInNestedFrame(selector: NativeScraperDefinitions.Selectors.taskRows)
        let tasks = rows.compactMap(LegacyScraperLogic.parseTaskRow)

        return .init(
            metadata: .init(
                version: "5.0.0",
                scraped_at: Date().iso8601String,
                scrape_duration_ms: Int(Date().timeIntervalSince(startedAt) * 1000),
                success: true,
                error: nil,
                scraper_version: "tasks-native-v1",
                source: SagasuAutomationRuntimeDescription()
            ),
            statistics: LegacyScraperLogic.taskStatistics(from: tasks),
            tasks: tasks
        )
    }

    private func applyFilters() throws {
        if !config.filters.buildings.isEmpty {
            try driver.clickInNestedFrame(selector: NativeScraperDefinitions.Selectors.buildingPicker)
            for building in config.filters.buildings {
                try driver.clickTextInNestedFrame(building)
            }
            try driver.clickInNestedFrame(selector: NativeScraperDefinitions.Selectors.buildingOK)
            driver.sleep(milliseconds: 1500)
        }

        if !config.filters.floors.isEmpty {
            try driver.clickInNestedFrame(selector: NativeScraperDefinitions.Selectors.floorPicker)
            for floor in config.filters.floors {
                try driver.clickTextInNestedFrame(floor)
            }
            try driver.clickInNestedFrame(selector: NativeScraperDefinitions.Selectors.floorOK)
            driver.sleep(milliseconds: 1500)
        }

        if !config.filters.facilityTypes.isEmpty {
            try driver.clickInNestedFrame(selector: NativeScraperDefinitions.Selectors.facilityPicker)
            for facilityType in config.filters.facilityTypes {
                try driver.clickTextInNestedFrame(facilityType)
            }
            try driver.clickInNestedFrame(selector: NativeScraperDefinitions.Selectors.facilityOK)
            driver.sleep(milliseconds: 1500)
        }

        if !config.filters.capacity.isEmpty {
            try driver.selectInNestedFrame(selector: NativeScraperDefinitions.Selectors.capacity, value: config.filters.capacity)
            driver.sleep(milliseconds: 1500)
        }

        if !config.filters.equipment.isEmpty {
            try driver.clickInNestedFrame(selector: NativeScraperDefinitions.Selectors.equipmentPicker)
            for equipment in config.filters.equipment {
                try driver.clickTextInNestedFrame(equipment)
            }
            try driver.clickInNestedFrame(selector: NativeScraperDefinitions.Selectors.equipmentOK)
            driver.sleep(milliseconds: 1500)
        }
    }

    private func captureResult<T>(
        dataset: ScrapeDataset,
        stage: String,
        operation: () throws -> T
    ) -> Result<T, Error> {
        Result {
            try retrying(dataset: dataset, stage: stage, attempts: 2, operation: operation)
        }
    }

    private func retrying<T>(
        dataset: ScrapeDataset? = nil,
        stage: String,
        attempts: Int,
        operation: () throws -> T
    ) throws -> T {
        precondition(attempts > 0, "At least one attempt is required.")

        for attempt in 1...attempts {
            do {
                return try operation()
            } catch {
                let diagnosticsURL = captureDiagnostics(
                    dataset: dataset,
                    stage: stage,
                    error: error,
                    attempt: attempt,
                    attempts: attempts
                )

                if attempt == attempts {
                    throw ScrapeAttemptError(
                        dataset: dataset,
                        stage: stage,
                        attempt: attempt,
                        diagnosticsURL: diagnosticsURL,
                        underlyingError: error
                    )
                }

                driver.sleep(milliseconds: retryDelayMilliseconds(for: attempt))
            }
        }

        throw NativeAutomationError.actionFailed("Retry loop for \(stage) exited without returning a result.")
    }

    private func retryDelayMilliseconds(for attempt: Int) -> Int {
        NativeFBSLiveScraperHelpers.retryDelayMilliseconds(for: attempt)
    }

    private func captureDiagnostics(
        dataset: ScrapeDataset?,
        stage: String,
        error: Error,
        attempt: Int,
        attempts: Int
    ) -> URL? {
        guard let diagnosticsStore else { return nil }

        let currentURL = driver.currentURL()
        let pageHTML = try? driver.pageHTML()
        let screenshotPNG = try? driver.snapshotPNGData()

        return try? diagnosticsStore.recordFailure(
            dataset: dataset,
            stage: "\(stage)-attempt-\(attempt)",
            error: error,
            currentURL: currentURL,
            pageHTML: pageHTML,
            screenshotPNG: screenshotPNG,
            extra: [
                "attempt": String(attempt),
                "attempts": String(attempts),
                "config_date": config.date,
                "config_start": config.startTime,
                "config_end": config.endTime
            ]
        )
    }
}
