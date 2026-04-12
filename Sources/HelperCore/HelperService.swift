import Foundation
import SagasuAutomationObjC
import SagasuCore
import SagasuShared

public actor SagasuHelperService {
    private let store: SnapshotStore
    private let bootstrapper = ArchivedSnapshotBootstrapper()
    private let configProvider: () -> ScrapeConfiguration
    private let refreshScheduler = RefreshScheduler()

    public init(
        store: SnapshotStore,
        configProvider: @escaping () -> ScrapeConfiguration = { .load() }
    ) {
        self.store = store
        self.configProvider = configProvider
    }

    public func currentSnapshot() async throws -> ServiceSnapshot {
        try await store.bootstrapSnapshotIfNeeded()
    }

    public func currentAuthState() async throws -> AuthState {
        let snapshot = try await currentSnapshot()
        return snapshot.auth_state
    }

    public func refresh(reason: String) async throws -> ServiceSnapshot {
        let startedAt = Date()
        try await store.appendConsole("[\(startedAt.iso8601String)] helper refresh started (\(reason))")

        if let environmentCredentials = SharedCredentialsStore.loadFromEnvironment() {
            try? SharedCredentialsStore.save(environmentCredentials)
        }

        let storedCredentials = try? SharedCredentialsStore.load()
        let runtime = SagasuAutomationRuntimeDescription()
        let hasCredentials = SagasuAutomationHasCredentialInputs(storedCredentials?.email, storedCredentials?.password)
        let fixtureSnapshot = try bootstrapper.load()
        var snapshot = (try? await store.loadSnapshot()) ?? fixtureSnapshot
        let now = Date()
        let nowString = now.iso8601String

        snapshot.generated_at = nowString
        snapshot.auth_state = AuthState(
            has_credentials: hasCredentials,
            storage_mode: SharedCredentialsStore.loadFromEnvironment() != nil ? .environment : (storedCredentials != nil ? .keychain : .none),
            runtime: runtime,
            last_error: hasCredentials ? nil : "Credentials are missing; helper is serving the last local snapshot or bundled fixtures."
        )

        guard let credentials = storedCredentials, hasCredentials else {
            snapshot.rooms = snapshot.rooms ?? fixtureSnapshot.rooms
            snapshot.bookings = snapshot.bookings ?? fixtureSnapshot.bookings
            snapshot.tasks = snapshot.tasks ?? fixtureSnapshot.tasks

            snapshot.setStatus(SnapshotMergeLogic.staleStatus(for: .rooms, attemptAt: nowString, currentSuccessAt: snapshot.rooms?.metadata.scraped_at, message: snapshot.auth_state.last_error ?? "No credentials configured."))
            snapshot.setStatus(SnapshotMergeLogic.staleStatus(for: .bookings, attemptAt: nowString, currentSuccessAt: snapshot.bookings?.metadata.scraped_at, message: snapshot.auth_state.last_error ?? "No credentials configured."))
            snapshot.setStatus(SnapshotMergeLogic.staleStatus(for: .tasks, attemptAt: nowString, currentSuccessAt: snapshot.tasks?.metadata.scraped_at, message: snapshot.auth_state.last_error ?? "No credentials configured."))

            try await store.saveSnapshot(snapshot)
            try await store.appendConsole("[\(Date().iso8601String)] helper refresh completed without credentials")
            return snapshot
        }

        let liveScraper = NativeFBSLiveScraper(config: configProvider())
        let outputs = liveScraper.scrapeAll(credentials: credentials)

        let roomsMerge = SnapshotMergeLogic.mergeRooms(
            outputs.rooms,
            current: snapshot.rooms,
            fallback: fixtureSnapshot.rooms,
            attemptAt: nowString
        )
        snapshot.rooms = roomsMerge.payload
        snapshot.setStatus(roomsMerge.status)
        try await store.appendConsole("[\(Date().iso8601String)] rooms status: \(roomsMerge.status.state.rawValue)")

        let bookingsMerge = SnapshotMergeLogic.mergeBookings(
            outputs.bookings,
            current: snapshot.bookings,
            fallback: fixtureSnapshot.bookings,
            attemptAt: nowString
        )
        snapshot.bookings = bookingsMerge.payload
        snapshot.setStatus(bookingsMerge.status)
        try await store.appendConsole("[\(Date().iso8601String)] bookings status: \(bookingsMerge.status.state.rawValue)")

        let tasksMerge = SnapshotMergeLogic.mergeTasks(
            outputs.tasks,
            current: snapshot.tasks,
            fallback: fixtureSnapshot.tasks,
            attemptAt: nowString
        )
        snapshot.tasks = tasksMerge.payload
        snapshot.setStatus(tasksMerge.status)
        try await store.appendConsole("[\(Date().iso8601String)] tasks status: \(tasksMerge.status.state.rawValue)")

        try await store.saveSnapshot(snapshot)
        try await store.appendConsole("[\(Date().iso8601String)] helper refresh completed")
        return snapshot
    }

    public func runServiceLoop() async throws {
        while true {
            _ = try await refresh(reason: "scheduled-service-loop")
            let delay = refreshScheduler.nextRefreshDelay(from: Date())
            try await store.appendConsole("[\(Date().iso8601String)] next scheduled refresh in \(Int(delay))s")
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
}
