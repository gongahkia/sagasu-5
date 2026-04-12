import SwiftUI
import SagasuShared

private enum DesktopSection: String, CaseIterable, Identifiable {
    case general = "General"
    case rooms = "Rooms"
    case bookings = "Bookings"
    case tasks = "Tasks"
    case controls = "Controls"
    case console = "Console"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .general:
            return "gearshape.fill"
        case .rooms:
            return "door.left.hand.open"
        case .bookings:
            return "calendar.badge.clock"
        case .tasks:
            return "checklist"
        case .controls:
            return "switch.2"
        case .console:
            return "terminal"
        }
    }
}

struct DesktopDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var selectedSection: DesktopSection? = .general
    @State private var selectedRoomID: String?
    @State private var selectedBookingID: String?
    @State private var selectedTaskID: String?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let errorMessage = appState.errorMessage {
                        errorPanel(message: errorMessage)
                    }

                    selectedContent
                }
                .padding(20)
                .frame(maxWidth: 720, alignment: .leading)
            }
            .background {
                SagasuScreenBackground()
            }
            .navigationTitle(selectedSectionValue.rawValue)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(appState.isLoading ? "Refreshing..." : "Refresh Now", action: refreshNow)
                        .disabled(appState.isLoading)
                }
            }
        }
        .frame(minWidth: 980, minHeight: 720)
    }

    private var sidebar: some View {
        List(selection: $selectedSection) {
            Section {
                ForEach(DesktopSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.systemImage)
                        .tag(section)
                }
            }

            Section("Status") {
                SidebarStatusRow(title: "Rooms", value: String(appState.rooms?.statistics.available_rooms ?? 0))
                SidebarStatusRow(title: "Helper", value: appState.helperModeDescription)
                SidebarStatusRow(title: "Agent", value: appState.launchAgentDescription)
            }
        }
        .navigationTitle("Sagasu")
        .frame(minWidth: 220)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedSectionValue {
        case .general:
            generalContent
        case .rooms:
            roomsContent
        case .bookings:
            bookingsContent
        case .tasks:
            tasksContent
        case .controls:
            controlsContent
        case .console:
            HelperConsolePanel(console: appState.helperConsole)
        }
    }

    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            summaryHeader
            metricsGrid

            DatasetHealthPanel(
                statuses: appState.statuses,
                formattedStatus: appState.formattedStatus,
                formattedTimestamp: appState.formattedScrapedAt
            )

            scrapeDetailsPanel
            runtimePanel
        }
    }

    private var roomsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoomsPanel(
                rooms: appState.rooms?.rooms ?? [],
                selectedRoomID: selectedRoomID,
                onSelect: selectRoom,
                formattedTimestamp: appState.formattedScrapedAt
            )

            DashboardSelectionPanel(
                selection: currentSelection,
                formattedTimestamp: appState.formattedScrapedAt
            )
        }
    }

    private var bookingsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            BookingsPanel(
                bookings: appState.recentBookings,
                selectedBookingID: selectedBookingID,
                onSelect: selectBooking
            )

            DashboardSelectionPanel(
                selection: currentSelection,
                formattedTimestamp: appState.formattedScrapedAt
            )
        }
    }

    private var tasksContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            TasksPanel(
                tasks: appState.recentTasks,
                selectedTaskID: selectedTaskID,
                onSelect: selectTask
            )

            DashboardSelectionPanel(
                selection: currentSelection,
                formattedTimestamp: appState.formattedScrapedAt
            )
        }
    }

    private var controlsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
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
    }

    private var summaryHeader: some View {
        SagasuPanel(title: "General", systemImage: "gearshape.fill") {
            VStack(alignment: .leading, spacing: 8) {
                SagasuRow(title: "Snapshot", value: appState.menuBarTitle)
                Divider()
                SagasuRow(title: "Last fetch", value: appState.formattedLastRefresh)
                Divider()
                SagasuRow(title: "Auth store", value: appState.authState.storage_mode.rawValue.capitalized)
            }
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: summaryColumns, spacing: 8) {
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
            VStack(spacing: 6) {
                ForEach(scrapeSummaries) { summary in
                    SagasuScrapeSummaryCard(summary: summary)
                }
            }
        }
    }

    private var runtimePanel: some View {
        SagasuPanel(title: "Runtime", systemImage: "info.circle") {
            VStack(alignment: .leading, spacing: 0) {
                SagasuRow(title: "Helper mode", value: appState.helperModeDescription)
                Divider()
                SagasuRow(title: "Launch agent", value: appState.launchAgentDescription)
                Divider()
                Text(appState.authState.runtime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
        }
    }

    private var selectedSectionValue: DesktopSection {
        selectedSection ?? .general
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
            GridItem(.adaptive(minimum: 150), spacing: 8)
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
        selectedSection = .rooms
    }

    private func selectBooking(_ id: String) {
        selectedBookingID = id
        selectedRoomID = nil
        selectedTaskID = nil
        selectedSection = .bookings
    }

    private func selectTask(_ id: String) {
        selectedTaskID = id
        selectedRoomID = nil
        selectedBookingID = nil
        selectedSection = .tasks
    }
}

private struct SidebarStatusRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: 8)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
