import Foundation

public struct ArchivedSnapshotBootstrapper {
    public init() {}

    public func load() throws -> ServiceSnapshot {
        guard let root = locateArchiveRoot() else {
            return placeholderSnapshot(message: "Archived Sagasu 4 fixtures were not found.")
        }

        let rooms = try decode(ScrapedRoomsResponse.self, from: root.appendingPathComponent("scraped_log.json"))
        let bookings = try decode(ScrapedBookingsResponse.self, from: root.appendingPathComponent("scraped_bookings.json"))
        let tasks = try decode(ScrapedTasksResponse.self, from: root.appendingPathComponent("scraped_tasks.json"))

        var snapshot = ServiceSnapshot(
            generated_at: Date().iso8601String,
            statuses: [
                DatasetStatus(dataset: .rooms, state: .stale, last_attempt_at: Date().iso8601String, last_success_at: rooms.metadata.scraped_at, message: "Bootstrapped from archived Sagasu 4 data."),
                DatasetStatus(dataset: .bookings, state: .stale, last_attempt_at: Date().iso8601String, last_success_at: bookings.metadata.scraped_at, message: "Bootstrapped from archived Sagasu 4 data."),
                DatasetStatus(dataset: .tasks, state: .stale, last_attempt_at: Date().iso8601String, last_success_at: tasks.metadata.scraped_at, message: "Bootstrapped from archived Sagasu 4 data.")
            ],
            auth_state: AuthState(
                has_credentials: false,
                storage_mode: .none,
                runtime: "Archived bootstrap",
                last_error: "Live native helper has not completed a credentialed run yet."
            ),
            rooms: rooms,
            bookings: bookings,
            tasks: tasks
        )

        snapshot.rooms?.metadata.source = "archived-scraping/sagasu-4"
        snapshot.bookings?.metadata.source = "archived-scraping/sagasu-4"
        snapshot.tasks?.metadata.source = "archived-scraping/sagasu-4"
        return snapshot
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    private func locateArchiveRoot() -> URL? {
        let fileManager = FileManager.default
        let current = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let candidates = [
            current,
            current.deletingLastPathComponent(),
            current.appendingPathComponent("dist/Sagasu.app/Contents/Resources"),
            Bundle.main.resourceURL,
            Bundle.main.bundleURL.deletingLastPathComponent()
        ].compactMap { $0 }

        for candidate in candidates {
            let root = candidate.appendingPathComponent("archived-scraping/sagasu-4/backend/log", isDirectory: true)
            if fileManager.fileExists(atPath: root.path) {
                return root
            }
        }

        return nil
    }

    private func placeholderSnapshot(message: String) -> ServiceSnapshot {
        ServiceSnapshot(
            generated_at: Date().iso8601String,
            statuses: ScrapeDataset.allCases.map {
                DatasetStatus(
                    dataset: $0,
                    state: .failed,
                    last_attempt_at: Date().iso8601String,
                    last_success_at: nil,
                    message: message
                )
            },
            auth_state: AuthState(
                has_credentials: false,
                storage_mode: .none,
                runtime: "Unavailable",
                last_error: message
            ),
            rooms: nil,
            bookings: nil,
            tasks: nil
        )
    }
}
