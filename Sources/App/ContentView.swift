import AppKit
import SwiftUI
import SagasuShared

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var appState: AppState
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showsRooms = true
    @State private var showsDetails = true
    @State private var expandedScrapeDetails: Set<String> = []
    @State private var preferencesExpanded = false
    @State private var controlsExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                header
                metricsGrid

                if let errorMessage = appState.errorMessage {
                    errorPanel(message: errorMessage)
                }

                if showsRooms {
                    roomsPanel
                }

                if showsDetails {
                    scrapeDetailsPanel
                }

                preferencesPanel
                controlsPanel
                footerPanel
            }
            .padding(10)
        }
        .background {
            SagasuScreenBackground()
        }
        .frame(width: 420, height: 560)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "building.2.crop.circle")
                .font(.callout.weight(.semibold))
                .foregroundStyle(SagasuTheme.brand)

            VStack(alignment: .leading, spacing: 2) {
                Text("Sagasu \(appState.rooms?.statistics.available_rooms ?? 0)")
                    .font(.callout.weight(.semibold))

                Text(appState.menuBarTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(appState.isLoading ? "Refreshing" : "Refresh", action: refreshSnapshot)
                .disabled(appState.isLoading)
                .buttonStyle(.bordered)
                .controlSize(.mini)
        }
        .padding(.horizontal, 2)
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: metricColumns, spacing: 7) {
            SagasuMetricCard(
                title: "Free now",
                value: String(appState.rooms?.statistics.available_rooms ?? 0),
                detail: nil,
                systemImage: "door.left.hand.open",
                tint: SagasuTheme.success
            )
            SagasuMetricCard(
                title: "Partial",
                value: String(appState.rooms?.statistics.partially_available_rooms ?? 0),
                detail: nil,
                systemImage: "clock",
                tint: .orange
            )
            SagasuMetricCard(
                title: "Booked",
                value: String(appState.rooms?.statistics.booked_rooms ?? 0),
                detail: nil,
                systemImage: "lock",
                tint: SagasuTheme.brandSecondary
            )
            SagasuMetricCard(
                title: "Total",
                value: String(appState.rooms?.statistics.total_rooms ?? 0),
                detail: nil,
                systemImage: "square.grid.2x2",
                tint: .secondary
            )
        }
    }

    private var roomsPanel: some View {
        SagasuPanel(title: "Rooms next available", systemImage: "door.left.hand.open") {
            if preferredRooms.isEmpty {
                SagasuEmptyStateCard(
                    title: "Waiting for rooms",
                    message: "No room availability has been cached yet.",
                    systemImage: "building.2"
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(preferredRooms.enumerated()), id: \.element.id) { index, item in
                        SagasuRow(
                            title: item.title,
                            value: item.detail,
                            systemImage: nil,
                            tint: SagasuTheme.brand
                        )

                        if index < preferredRooms.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var scrapeDetailsPanel: some View {
        SagasuPanel(title: "Scraping details", systemImage: "waveform.path.ecg.rectangle") {
            VStack(spacing: 6) {
                ForEach(scrapeSummaries) { summary in
                    SagasuScrapeSummaryDisclosureCard(
                        summary: summary,
                        isExpanded: scrapeDetailExpansion(for: summary.id)
                    )
                }
            }
        }
    }

    private var preferencesPanel: some View {
        DisclosureGroup(isExpanded: $preferencesExpanded) {
            VStack(alignment: .leading, spacing: 5) {
                Toggle("Rooms", isOn: $showsRooms)
                Toggle("Details", isOn: $showsDetails)
            }
            .toggleStyle(.checkbox)
            .padding(.top, 4)
        } label: {
            Text("Preferences")
                .font(.callout.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SagasuTheme.groupFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(SagasuTheme.separator, lineWidth: 1)
                }
        )
    }

    private var controlsPanel: some View {
        DisclosureGroup(isExpanded: $controlsExpanded) {
            VStack(alignment: .leading, spacing: 8) {
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
                    showsPaths: false,
                    onInstall: appState.installBackgroundService,
                    onStart: appState.startBackgroundService,
                    onStop: appState.stopBackgroundService,
                    onRemove: appState.uninstallBackgroundService
                )
            }
            .padding(.top, 8)
        } label: {
            Text("Controls")
                .font(.callout.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var footerPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()

            menuActionButton("Open Desktop Dashboard", action: openDashboard)
            Divider()
            menuActionButton("Quit", action: quitApplication)
            Divider()

            SagasuFooterText(lastFetch: appState.formattedLastRefresh)
                .padding(.top, 6)
        }
        .padding(.horizontal, 8)
    }

    private var metricColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 7),
            GridItem(.flexible(), spacing: 7)
        ]
    }

    private var preferredRooms: [AppState.RoomLine] {
        if !appState.nextAvailable.isEmpty {
            return Array(appState.nextAvailable.prefix(8))
        }

        return Array(appState.availableNow.prefix(8))
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
    private func menuActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 7)
    }

    private func scrapeDetailExpansion(for id: String) -> Binding<Bool> {
        Binding(
            get: {
                expandedScrapeDetails.contains(id)
            },
            set: { isExpanded in
                if isExpanded {
                    expandedScrapeDetails.insert(id)
                } else {
                    expandedScrapeDetails.remove(id)
                }
            }
        )
    }

    @ViewBuilder
    private func errorPanel(message: String) -> some View {
        SagasuPanel(title: "Helper warning", systemImage: "exclamationmark.triangle.fill") {
            Text(message)
                .font(.callout)
        }
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

    private func refreshSnapshot() {
        appState.refresh(manual: true)
    }

    private func openDashboard() {
        openWindow(id: "dashboard")
    }

    private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
}
