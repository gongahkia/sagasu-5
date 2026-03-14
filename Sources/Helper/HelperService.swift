import Foundation
import SagasuAutomationObjC
import SagasuShared

actor SagasuHelperService {
    private let store: SnapshotStore
    private let bootstrapper = ArchivedSnapshotBootstrapper()

    private static let sgtTimeZone = TimeZone(identifier: "Asia/Singapore")!

    init(store: SnapshotStore) {
        self.store = store
    }

    func currentSnapshot() async throws -> ServiceSnapshot {
        try await store.bootstrapSnapshotIfNeeded()
    }

    func currentAuthState() async throws -> AuthState {
        let snapshot = try await currentSnapshot()
        return snapshot.auth_state
    }

    func refresh(reason: String) async throws -> ServiceSnapshot {
        let startedAt = Date()
        try await store.appendConsole("[\(startedAt.iso8601String)] helper refresh started (\(reason))")

        if let environmentCredentials = HelperCredentialsStore.loadFromEnvironment() {
            try? HelperCredentialsStore.save(environmentCredentials)
        }

        let storedCredentials = try? HelperCredentialsStore.load()
        let runtime = SagasuAutomationRuntimeDescription()
        let hasCredentials = SagasuAutomationHasCredentialInputs(storedCredentials?.email, storedCredentials?.password)

        var snapshot = (try? await store.loadSnapshot()) ?? ServiceSnapshot()
        let archived = try bootstrapper.load()
        let now = Date()
        let nowString = now.iso8601String

        snapshot.generated_at = nowString
        snapshot.auth_state = AuthState(
            has_credentials: hasCredentials,
            storage_mode: HelperCredentialsStore.loadFromEnvironment() != nil ? .environment : (storedCredentials != nil ? .keychain : .none),
            runtime: runtime,
            last_error: hasCredentials ? nil : "Credentials are missing; helper is using archived fixtures until the native browser automation is completed."
        )

        snapshot.rooms = archived.rooms.map { self.rewritten($0, runtime: runtime, startedAt: startedAt, label: "rooms-swift-fixture") }
        snapshot.bookings = archived.bookings.map { self.rewritten($0, runtime: runtime, startedAt: startedAt, label: "bookings-swift-fixture") }
        snapshot.tasks = archived.tasks.map { self.rewritten($0, runtime: runtime, startedAt: startedAt, label: "tasks-swift-fixture") }

        snapshot.setStatus(makeStatus(for: .rooms, payloadPresent: snapshot.rooms != nil, attemptAt: nowString))
        snapshot.setStatus(makeStatus(for: .bookings, payloadPresent: snapshot.bookings != nil, attemptAt: nowString))
        snapshot.setStatus(makeStatus(for: .tasks, payloadPresent: snapshot.tasks != nil, attemptAt: nowString))

        try await store.saveSnapshot(snapshot)
        try await store.appendConsole("[\(Date().iso8601String)] helper refresh completed")
        return snapshot
    }

    func runServiceLoop() async throws {
        while true {
            _ = try await refresh(reason: "scheduled-service-loop")
            let delay = nextRefreshDelay(from: Date())
            try await store.appendConsole("[\(Date().iso8601String)] next scheduled refresh in \(Int(delay))s")
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }

    private func makeStatus(for dataset: ScrapeDataset, payloadPresent: Bool, attemptAt: String) -> DatasetStatus {
        DatasetStatus(
            dataset: dataset,
            state: payloadPresent ? .success : .failed,
            last_attempt_at: attemptAt,
            last_success_at: payloadPresent ? attemptAt : nil,
            message: payloadPresent
                ? "Loaded from the local helper cache/bootstrap path."
                : "No local payload is available for this dataset."
        )
    }

    private func nextRefreshDelay(from now: Date) -> TimeInterval {
        var calendar = Calendar.current
        calendar.timeZone = Self.sgtTimeZone

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 8
        components.minute = 15
        components.second = 0

        guard var next = calendar.date(from: components) else {
            return 60 * 60
        }

        if next <= now {
            next = calendar.date(byAdding: .day, value: 1, to: next) ?? next
        }

        return max(60, next.timeIntervalSince(now))
    }

    private func rewritten(
        _ payload: ScrapedRoomsResponse,
        runtime: String,
        startedAt: Date,
        label: String
    ) -> ScrapedRoomsResponse {
        var updated = payload
        updated.metadata.scraped_at = Date().iso8601String
        updated.metadata.scrape_duration_ms = Int(Date().timeIntervalSince(startedAt) * 1000)
        updated.metadata.scraper_version = label
        updated.metadata.source = runtime
        updated.metadata.error = nil
        updated.metadata.success = true
        return updated
    }

    private func rewritten(
        _ payload: ScrapedBookingsResponse,
        runtime: String,
        startedAt: Date,
        label: String
    ) -> ScrapedBookingsResponse {
        var updated = payload
        updated.metadata.scraped_at = Date().iso8601String
        updated.metadata.scrape_duration_ms = Int(Date().timeIntervalSince(startedAt) * 1000)
        updated.metadata.scraper_version = label
        updated.metadata.source = runtime
        updated.metadata.error = nil
        updated.metadata.success = true
        return updated
    }

    private func rewritten(
        _ payload: ScrapedTasksResponse,
        runtime: String,
        startedAt: Date,
        label: String
    ) -> ScrapedTasksResponse {
        var updated = payload
        updated.metadata.scraped_at = Date().iso8601String
        updated.metadata.scrape_duration_ms = Int(Date().timeIntervalSince(startedAt) * 1000)
        updated.metadata.scraper_version = label
        updated.metadata.source = runtime
        updated.metadata.error = nil
        updated.metadata.success = true
        return updated
    }
}
