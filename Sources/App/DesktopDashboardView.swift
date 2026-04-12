import SwiftUI
import SagasuShared

struct DesktopDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var selectedRoomID: String?
    @State private var selectedBookingID: String?
    @State private var selectedTaskID: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    dashboardHeader

                    if let errorMessage = appState.errorMessage {
                        errorPanel(message: errorMessage)
                    }

                    metricsGrid

                    LazyVGrid(columns: dashboardColumns, spacing: 16) {
                        DatasetHealthPanel(
                            statuses: appState.statuses,
                            formattedStatus: appState.formattedStatus,
                            formattedTimestamp: appState.formattedScrapedAt
                        )

                        scrapeDetailsPanel

                        DashboardSelectionPanel(
                            selection: currentSelection,
                            formattedTimestamp: appState.formattedScrapedAt
                        )

                        runtimePanel

                        RoomsPanel(
                            rooms: appState.rooms?.rooms ?? [],
                            selectedRoomID: selectedRoomID,
                            onSelect: selectRoom,
                            formattedTimestamp: appState.formattedScrapedAt
                        )

                        BookingsPanel(
                            bookings: appState.recentBookings,
                            selectedBookingID: selectedBookingID,
                            onSelect: selectBooking
                        )

                        TasksPanel(
                            tasks: appState.recentTasks,
                            selectedTaskID: selectedTaskID,
                            onSelect: selectTask
                        )

                        CredentialsPanel(
                            title: "Authentication",
                            subtitle: nil,
                            email: $email,
                            password: $password,
                            onSave: saveCredentials,
                            onClear: clearCredentials
                        )

                        HelperControlsPanel(
                            currentMode: appState.helperMode,
                            currentDescription: appState.helperModeDescription,
                            onStart: appState.startHelper(mode:),
                            onStop: appState.stopHelper
                        )

                        BackgroundServicePanel(
                            status: appState.launchAgentStatus,
                            summary: appState.launchAgentDescription,
                            showsPaths: true,
                            onInstall: appState.installBackgroundService,
                            onStart: appState.startBackgroundService,
                            onStop: appState.stopBackgroundService,
                            onRemove: appState.uninstallBackgroundService
                        )

                        ScrapePreferencesPanel(
                            preferences: scrapePreferencesBinding,
                            onSave: appState.saveScrapePreferences
                        )
                    }

                    HelperConsolePanel(console: appState.helperConsole)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Sagasu")
            .background {
                SagasuScreenBackground()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(appState.isLoading ? "Refreshing..." : "Refresh Now", action: refreshNow)
                        .disabled(appState.isLoading)
                }
            }
        }
        .frame(minWidth: 1100, minHeight: 760)
    }

    private var dashboardHeader: some View {
        SagasuPanel(title: "Sagasu Desktop", systemImage: "building.2.crop.circle") {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.menuBarTitle)
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("Last fetch \(appState.formattedLastRefresh)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                SagasuStatusPill(
                    title: "Auth",
                    value: appState.authState.storage_mode.rawValue.capitalized,
                    tint: appState.authState.has_credentials ? SagasuTheme.success : .secondary
                )

                SagasuStatusPill(
                    title: "Helper",
                    value: appState.helperModeDescription,
                    tint: appState.helperMode == nil ? .secondary : SagasuTheme.brand
                )

                SagasuStatusPill(
                    title: "Agent",
                    value: appState.launchAgentDescription,
                    tint: appState.launchAgentStatus?.isLoaded == true ? SagasuTheme.success : .secondary
                )
            }
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: summaryColumns, spacing: 12) {
            SagasuMetricCard(
                title: "Free now",
                value: String(appState.rooms?.statistics.available_rooms ?? 0),
                detail: "Immediate room availability",
                systemImage: "door.left.hand.open",
                tint: SagasuTheme.success
            )
            SagasuMetricCard(
                title: "Partial",
                value: String(appState.rooms?.statistics.partially_available_rooms ?? 0),
                detail: "Rooms with mixed availability",
                systemImage: "clock.badge.exclamationmark",
                tint: .orange
            )
            SagasuMetricCard(
                title: "Booked",
                value: String(appState.rooms?.statistics.booked_rooms ?? 0),
                detail: "Unavailable rooms",
                systemImage: "lock",
                tint: SagasuTheme.brandSecondary
            )
            SagasuMetricCard(
                title: "Total",
                value: String(appState.rooms?.statistics.total_rooms ?? 0),
                detail: "Cached room rows",
                systemImage: "square.grid.2x2",
                tint: .secondary
            )
        }
    }

    private var scrapeDetailsPanel: some View {
        SagasuPanel(title: "Scraping details", systemImage: "waveform.path.ecg.rectangle") {
            VStack(spacing: 10) {
                ForEach(scrapeSummaries) { summary in
                    SagasuScrapeSummaryCard(summary: summary)
                }
            }
        }
    }

    private var runtimePanel: some View {
        SagasuPanel(title: "Runtime", systemImage: "info.circle") {
            VStack(alignment: .leading, spacing: 0) {
                SagasuRow(title: "Last refresh", value: appState.formattedLastRefresh)
                Divider()
                SagasuRow(title: "Auth store", value: appState.authState.storage_mode.rawValue.capitalized)
                Divider()
                SagasuRow(title: "Helper mode", value: appState.helperModeDescription)
                Divider()
                SagasuRow(title: "Launch agent", value: appState.launchAgentDescription)

                Text(appState.authState.runtime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
    }

    private var selectedRoom: ScrapedRoomsResponse.Room? {
        guard let selectedRoomID else { return nil }
        return appState.rooms?.rooms?.first(where: { $0.id == selectedRoomID })
    }

    private var selectedBooking: ScrapedBookingsResponse.Booking? {
        guard let selectedBookingID else { return nil }
        return appState.bookings?.bookings.first(where: { $0.id == selectedBookingID })
    }

    private var selectedTask: ScrapedTasksResponse.Task? {
        guard let selectedTaskID else { return nil }
        return appState.tasks?.tasks.first(where: { $0.id == selectedTaskID })
    }

    private var currentSelection: DashboardSelection? {
        if let selectedRoom {
            return .room(selectedRoom)
        }
        if let selectedBooking {
            return .booking(selectedBooking)
        }
        if let selectedTask {
            return .task(selectedTask)
        }
        return nil
    }

    private var summaryColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 210), spacing: 12)
        ]
    }

    private var dashboardColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 320), spacing: 16),
            GridItem(.flexible(minimum: 320), spacing: 16)
        ]
    }

    private var scrapePreferencesBinding: Binding<ScrapePreferences> {
        Binding(
            get: { appState.scrapePreferences },
            set: { appState.scrapePreferences = $0 }
        )
    }

    private var scrapeSummaries: [SagasuScrapeSummary] {
        var summaries: [SagasuScrapeSummary] = []

        if let rooms = appState.rooms {
            summaries.append(
                SagasuScrapeSummary(
                    id: "rooms",
                    title: "Rooms",
                    scrapedAt: appState.formattedScrapedAt(rooms.metadata.scraped_at),
                    duration: "\(rooms.metadata.scrape_duration_ms) ms",
                    state: rooms.metadata.success ? "Success" : (rooms.metadata.error ?? "Failed"),
                    stateTint: rooms.metadata.success ? SagasuTheme.success : .red,
                    detail: "\(rooms.config.date) \(rooms.config.start_time)-\(rooms.config.end_time)"
                )
            )
        }

        if let bookings = appState.bookings {
            summaries.append(
                SagasuScrapeSummary(
                    id: "bookings",
                    title: "Bookings",
                    scrapedAt: appState.formattedScrapedAt(bookings.metadata.scraped_at),
                    duration: "\(bookings.metadata.scrape_duration_ms) ms",
                    state: bookings.metadata.success ? "Success" : (bookings.metadata.error ?? "Failed"),
                    stateTint: bookings.metadata.success ? SagasuTheme.success : .red,
                    detail: nil
                )
            )
        }

        if let tasks = appState.tasks {
            summaries.append(
                SagasuScrapeSummary(
                    id: "tasks",
                    title: "Tasks",
                    scrapedAt: appState.formattedScrapedAt(tasks.metadata.scraped_at),
                    duration: "\(tasks.metadata.scrape_duration_ms) ms",
                    state: tasks.metadata.success ? "Success" : (tasks.metadata.error ?? "Failed"),
                    stateTint: tasks.metadata.success ? SagasuTheme.success : .red,
                    detail: nil
                )
            )
        }

        if summaries.isEmpty {
            summaries.append(
                SagasuScrapeSummary(
                    id: "empty",
                    title: "Snapshot",
                    scrapedAt: "Waiting for data",
                    duration: "0 ms",
                    state: "Idle",
                    stateTint: .secondary,
                    detail: nil
                )
            )
        }

        return summaries
    }

    @ViewBuilder
    private func errorPanel(message: String) -> some View {
        SagasuPanel(title: "Helper warning", systemImage: "exclamationmark.triangle.fill") {
            Text(message)
                .font(.callout)
        }
    }

    private func refreshNow() {
        appState.refresh(manual: true)
    }

    private func saveCredentials() {
        appState.saveCredentials(email: email, password: password)
        password = ""
    }

    private func clearCredentials() {
        appState.clearCredentials()
        email = ""
        password = ""
    }

    private func selectRoom(_ id: String) {
        selectedRoomID = id
        selectedBookingID = nil
        selectedTaskID = nil
    }

    private func selectBooking(_ id: String) {
        selectedBookingID = id
        selectedRoomID = nil
        selectedTaskID = nil
    }

    private func selectTask(_ id: String) {
        selectedTaskID = id
        selectedRoomID = nil
        selectedBookingID = nil
    }
}
