import Combine
import Foundation
import SagasuShared

@MainActor
final class AppState: ObservableObject {
    struct RoomLine: Identifiable {
        let id: String
        let title: String
        let detail: String
        let context: String
        let nextDate: Date?
    }

    @Published private(set) var snapshot: ServiceSnapshot = ServiceSnapshot()
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var helperConsole: String = ""
    @Published private(set) var helperMode: HelperRunMode?
    @Published private(set) var launchAgentStatus: HelperLaunchAgentStatus?
    @Published var scrapePreferences: ScrapePreferences = ScrapePreferences()
    @Published var menuBarTitle: String = "Loading…"

    private let client: HelperClientProtocol
    private let lifecycleController = HelperLifecycleController()
    private let iso8601 = ISO8601DateFormatter.sagasuInternetDateTime
    private let preferencesStore = try? ScrapePreferencesStore()

    private var pollTask: Task<Void, Never>?

    init(client: HelperClientProtocol = CompositeHelperClient()) {
        self.client = client
        Task {
            await reloadCachedSnapshot()
        }
        Task {
            await loadScrapePreferences()
        }
        refreshLaunchAgentStatus()
        startPolling()
    }

    deinit {
        pollTask?.cancel()
    }

    var rooms: ScrapedRoomsResponse? { snapshot.rooms }
    var bookings: ScrapedBookingsResponse? { snapshot.bookings }
    var tasks: ScrapedTasksResponse? { snapshot.tasks }
    var statuses: [DatasetStatus] { snapshot.statuses }
    var authState: AuthState { snapshot.auth_state }

    var formattedLastRefresh: String {
        guard let lastRefresh else { return "Never" }
        return DateFormatter.localizedString(from: lastRefresh, dateStyle: .none, timeStyle: .medium)
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
                    context: "\(room.building) • \(room.floor)",
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
                    context: "\(room.building) • \(room.floor)",
                    nextDate: next
                )
            }
            .sorted {
                guard let lhs = $0.nextDate, let rhs = $1.nextDate else { return false }
                return lhs < rhs
            }
    }

    var recentBookings: [ScrapedBookingsResponse.Booking] {
        Array((bookings?.bookings ?? []).prefix(8))
    }

    var recentTasks: [ScrapedTasksResponse.Task] {
        Array((tasks?.tasks ?? []).prefix(8))
    }

    var helperModeDescription: String {
        helperMode?.title ?? "Stopped"
    }

    var launchAgentDescription: String {
        launchAgentStatus?.summary ?? "Unavailable"
    }

    func refresh(manual: Bool = true) {
        guard !isLoading else { return }

        Task {
            await refreshAsync(manual: manual)
        }
    }

    func formattedScrapedAt(_ scrapedAt: String?) -> String {
        guard let scrapedAt, let date = iso8601.date(from: scrapedAt) else { return scrapedAt ?? "—" }
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .medium)
    }

    func formattedStatus(_ status: DatasetStatus) -> String {
        switch status.state {
        case .idle: return "Idle"
        case .loading: return "Refreshing"
        case .success: return "Healthy"
        case .stale: return "Stale"
        case .failed: return "Failed"
        }
    }

    func saveCredentials(email: String, password: String) {
        Task {
            do {
                try await client.storeCredentials(email: email, password: password)
                errorMessage = nil
                await reloadCachedSnapshot()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func clearCredentials() {
        Task {
            do {
                try await client.clearCredentials()
                errorMessage = nil
                await reloadCachedSnapshot()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func startHelper(mode: HelperRunMode) {
        do {
            try lifecycleController.start(mode: mode)
            helperMode = mode
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopHelper() {
        lifecycleController.stop()
        helperMode = nil
    }

    func installBackgroundService() {
        do {
            launchAgentStatus = try lifecycleController.installLaunchAgent()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startBackgroundService() {
        do {
            launchAgentStatus = try lifecycleController.startLaunchAgent()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopBackgroundService() {
        do {
            launchAgentStatus = try lifecycleController.stopLaunchAgent()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func uninstallBackgroundService() {
        do {
            try lifecycleController.uninstallLaunchAgent()
            refreshLaunchAgentStatus()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveScrapePreferences() {
        guard let preferencesStore else {
            errorMessage = "Scrape preferences storage is unavailable."
            return
        }

        Task {
            do {
                try await preferencesStore.save(scrapePreferences)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func refreshAsync(manual: Bool) async {
        isLoading = true
        errorMessage = nil

        do {
            snapshot = try await client.refresh(manual: manual)
            helperConsole = await client.loadConsole()
            lastRefresh = Date()
            menuBarTitle = makeMenuBarTitle()
        } catch {
            errorMessage = error.localizedDescription
            helperConsole = await client.loadConsole()
            menuBarTitle = "Helper error"
        }

        isLoading = false
    }

    private func reloadCachedSnapshot() async {
        do {
            snapshot = try await client.loadSnapshot()
            helperConsole = await client.loadConsole()
            menuBarTitle = makeMenuBarTitle()
        } catch {
            errorMessage = error.localizedDescription
            menuBarTitle = "Helper error"
        }
    }

    private func loadScrapePreferences() async {
        guard let preferencesStore else { return }

        do {
            scrapePreferences = try await preferencesStore.load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshLaunchAgentStatus() {
        do {
            launchAgentStatus = try lifecycleController.launchAgentStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeMenuBarTitle() -> String {
        guard let rooms else { return authState.has_credentials ? "Waiting" : "Setup" }

        let available = rooms.statistics.available_rooms
        let total = rooms.statistics.total_rooms
        return "\(available)/\(total) free"
    }

    private func parseISO(_ value: String?) -> Date? {
        guard let value else { return nil }
        return iso8601.date(from: value)
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard let self else { return }
                await self.reloadCachedSnapshot()
            }
        }
    }
}
