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
                VStack(alignment: .leading, spacing: 18) {
                    heroBanner

                    if let errorMessage = appState.errorMessage {
                        errorPanel(message: errorMessage)
                    }

                    LazyVGrid(columns: summaryColumns, spacing: 12) {
                        SagasuMetricCard(
                            title: "Free now",
                            value: String(appState.rooms?.statistics.available_rooms ?? 0),
                            detail: "Immediate room availability",
                            systemImage: "door.left.hand.open",
                            tint: .green
                        )
                        SagasuMetricCard(
                            title: "Partial rooms",
                            value: String(appState.rooms?.statistics.partially_available_rooms ?? 0),
                            detail: "Rooms with mixed occupancy",
                            systemImage: "clock.badge.exclamationmark",
                            tint: .orange
                        )
                        SagasuMetricCard(
                            title: "Bookings",
                            value: String(appState.bookings?.statistics.total_bookings ?? 0),
                            detail: "Cached booking records",
                            systemImage: "calendar",
                            tint: SagasuTheme.brandSecondary
                        )
                        SagasuMetricCard(
                            title: "Tasks",
                            value: String(appState.tasks?.statistics.total_tasks ?? 0),
                            detail: "Cached task records",
                            systemImage: "checklist",
                            tint: SagasuTheme.brand
                        )
                    }

                    LazyVGrid(columns: dashboardColumns, spacing: 16) {
                        DatasetHealthPanel(
                            statuses: appState.statuses,
                            formattedStatus: appState.formattedStatus,
                            formattedTimestamp: appState.formattedScrapedAt
                        )

                        DashboardSelectionPanel(
                            selection: currentSelection,
                            formattedTimestamp: appState.formattedScrapedAt
                        )

                        CredentialsPanel(
                            title: "Authentication",
                            subtitle: "Store credentials before running helper refreshes against the source system.",
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

                        runtimePanel
                    }

                    HelperConsolePanel(console: appState.helperConsole)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Sagasu Desktop")
            .background {
                SagasuScreenBackground()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(appState.isLoading ? "Refreshing…" : "Refresh Now", action: refreshNow)
                    .disabled(appState.isLoading)
                }
            }
        }
        .frame(minWidth: 1100, minHeight: 760)
    }

    private var heroBanner: some View {
        SagasuHeroBanner(
            eyebrow: "Desktop Dashboard",
            title: "Local snapshot control room",
            subtitle: "Monitor helper health, refine scrape inputs, and inspect cached room, booking, and task data from one desktop surface.",
            systemImage: "rectangle.3.group.bubble.left.fill"
        ) {
            HStack(spacing: 12) {
                heroPill(title: "Last refresh", value: appState.formattedLastRefresh)
                heroPill(title: "Auth", value: appState.authState.storage_mode.rawValue.capitalized)
                heroPill(title: "Launch agent", value: appState.launchAgentDescription)
            }
        }
    }

    private var runtimePanel: some View {
        SagasuPanel(
            title: "Runtime",
            subtitle: "Environment details that shape how the helper and desktop shell are currently operating.",
            systemImage: "info.circle"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Last refresh", value: appState.formattedLastRefresh)
                LabeledContent("Auth store", value: appState.authState.storage_mode.rawValue.capitalized)
                LabeledContent("Helper mode", value: appState.helperModeDescription)
                LabeledContent("Launch agent", value: appState.launchAgentDescription)
                Text(appState.authState.runtime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            GridItem(.adaptive(minimum: 220), spacing: 12)
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

    @ViewBuilder
    private func heroPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.78))

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func errorPanel(message: String) -> some View {
        SagasuPanel(
            title: "Helper warning",
            subtitle: "The helper surfaced an error during the last refresh cycle.",
            systemImage: "exclamationmark.triangle.fill"
        ) {
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
