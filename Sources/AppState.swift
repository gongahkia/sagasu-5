import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var rooms: ScrapedRoomsResponse?
    @Published private(set) var bookings: ScrapedBookingsResponse?
    @Published private(set) var tasks: ScrapedTasksResponse?

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastRefresh: Date?

    @Published var menuBarTitle: String = "Loading…"

    private var refreshTask: Task<Void, Never>?

    private let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let sgtTimeZone = TimeZone(identifier: "Asia/Singapore")!

    init() {
        refresh()
        scheduleNextRefresh()
    }

    deinit {
        refreshTask?.cancel()
    }

    /// Formatted last refresh time, or "Never" if not yet fetched
    var formattedLastRefresh: String {
        guard let lastRefresh else { return "Never" }
        return DateFormatter.localizedString(from: lastRefresh, dateStyle: .none, timeStyle: .medium)
    }

    /// Schedules automatic refresh at 8:15 AM SGT daily (API updates at 8 AM SGT)
    private func scheduleNextRefresh() {
        refreshTask?.cancel()
        refreshTask = nil

        var calendar = Calendar.current
        calendar.timeZone = Self.sgtTimeZone

        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 8
        components.minute = 15
        components.second = 0

        guard var nextRefreshDate = calendar.date(from: components) else { return }

        // If 8:15 AM SGT has already passed today, schedule for tomorrow
        if nextRefreshDate <= now {
            nextRefreshDate = calendar.date(byAdding: .day, value: 1, to: nextRefreshDate) ?? nextRefreshDate
        }

        let interval = nextRefreshDate.timeIntervalSince(now)

        let clampedInterval = max(0, interval)
        let delayNanoseconds = UInt64(clampedInterval * 1_000_000_000)

        refreshTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            self?.refresh()
            self?.scheduleNextRefresh()
        }
    }

    struct RoomLine: Identifiable {
        let id: String
        let title: String
        let detail: String
        let minutes: Int
        let nextDate: Date?
    }

    var availableNow: [RoomLine] {
        guard let rooms = rooms?.rooms else { return [] }

        return rooms
            .filter { $0.availability_summary.is_available_now }
            .sorted { $0.availability_summary.free_duration_minutes > $1.availability_summary.free_duration_minutes }
            .prefix(8)
            .map { room in
                RoomLine(
                    id: room.id,
                    title: room.name,
                    detail: "Free for \(room.availability_summary.free_duration_minutes) min",
                    minutes: room.availability_summary.free_duration_minutes,
                    nextDate: parseISO(room.availability_summary.next_available_at)
                )
            }
    }

    var nextAvailable: [RoomLine] {
        guard let rooms = rooms?.rooms else { return [] }

        return rooms
            .filter { !$0.availability_summary.is_available_now }
            .compactMap { room -> RoomLine? in
                guard let next = parseISO(room.availability_summary.next_available_at) else { return nil }
                return RoomLine(
                    id: room.id,
                    title: room.name,
                    detail: DateFormatter.localizedString(from: next, dateStyle: .none, timeStyle: .short),
                    minutes: room.availability_summary.free_duration_minutes,
                    nextDate: next
                )
            }
            .sorted {
                guard let a = $0.nextDate, let b = $1.nextDate else { return false }
                return a < b
            }
            .prefix(8)
            .map { $0 }
    }

    func refresh() {
        guard !isLoading else { return }
        Task { await refreshAsync() }
    }

    private func refreshAsync() async {
        isLoading = true
        errorMessage = nil

        do {
            async let roomsRequest: ScrapedRoomsResponse = fetchJSON(from: GitHubEndpoints.scrapedLog)
            async let bookingsRequest: ScrapedBookingsResponse = fetchJSON(from: GitHubEndpoints.scrapedBookings)
            async let tasksRequest: ScrapedTasksResponse = fetchJSON(from: GitHubEndpoints.scrapedTasks)

            let (rooms, bookings, tasks) = try await (roomsRequest, bookingsRequest, tasksRequest)

            self.rooms = rooms
            self.bookings = bookings
            self.tasks = tasks
            self.lastRefresh = Date()

            menuBarTitle = makeMenuBarTitle(rooms: rooms)
        } catch {
            errorMessage = error.localizedDescription
            menuBarTitle = "Error"
        }

        isLoading = false
    }

    nonisolated private func fetchJSON<T: Decodable>(from url: URL) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    private func makeMenuBarTitle(rooms: ScrapedRoomsResponse) -> String {
        let available = rooms.statistics.available_rooms
        let total = rooms.statistics.total_rooms
        if available > 0 {
            return "\(available)/\(total) free"
        }

        let partial = rooms.statistics.partially_available_rooms
        return "\(available)/\(total) free (\(partial) partial)"
    }

    func formattedScrapedAt(_ scrapedAt: String?) -> String {
        guard let scrapedAt, let date = iso8601.date(from: scrapedAt) else { return scrapedAt ?? "—" }
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .medium)
    }

    private func parseISO(_ value: String?) -> Date? {
        guard let value else { return nil }
        return iso8601.date(from: value)
    }
}
