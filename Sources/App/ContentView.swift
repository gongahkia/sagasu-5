import AppKit
import SwiftUI
import SagasuShared

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var appState: AppState
    @State private var email: String = ""
    @State private var password: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                heroBanner

                if let errorMessage = appState.errorMessage {
                    errorPanel(message: errorMessage)
                }

                snapshotOverviewPanel

                CredentialsPanel(
                    title: "Authentication",
                    subtitle: "Store SMU credentials locally in the Keychain before refreshing.",
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

                roomsPanel
                actionsPanel
                runtimePanel
            }
            .padding(16)
        }
        .background {
            SagasuScreenBackground()
        }
        .frame(width: 460, height: 620)
    }

    private var heroBanner: some View {
        SagasuHeroBanner(
            eyebrow: "Menu Bar Console",
            title: "Sagasu 5",
            subtitle: "Native helper snapshots, credentials, and refresh controls stay one click away.",
            systemImage: "sparkles.rectangle.stack"
        ) {
            HStack(spacing: 10) {
                heroPill(
                    title: "Free now",
                    value: String(appState.rooms?.statistics.available_rooms ?? 0)
                )
                heroPill(title: "Refresh", value: appState.formattedLastRefresh)
                heroPill(title: "Helper", value: appState.helperModeDescription)
            }
        }
    }

    private var snapshotOverviewPanel: some View {
        SagasuPanel(
            title: "Local snapshot",
            subtitle: "A compact view of the helper-owned cache that drives the menu bar status.",
            systemImage: "chart.bar.xaxis"
        ) {
            LazyVGrid(columns: summaryColumns, spacing: 10) {
                SagasuMetricCard(
                    title: "Free now",
                    value: String(appState.rooms?.statistics.available_rooms ?? 0),
                    detail: "Immediately available rooms",
                    systemImage: "door.left.hand.open",
                    tint: .green
                )
                SagasuMetricCard(
                    title: "Partial",
                    value: String(appState.rooms?.statistics.partially_available_rooms ?? 0),
                    detail: "Rooms with mixed timeslots",
                    systemImage: "clock.badge.exclamationmark",
                    tint: .orange
                )
                SagasuMetricCard(
                    title: "Bookings",
                    value: String(appState.bookings?.statistics.total_bookings ?? 0),
                    detail: "Cached booking rows",
                    systemImage: "calendar",
                    tint: SagasuTheme.brandSecondary
                )
                SagasuMetricCard(
                    title: "Tasks",
                    value: String(appState.tasks?.statistics.total_tasks ?? 0),
                    detail: "Cached task rows",
                    systemImage: "checklist",
                    tint: SagasuTheme.brand
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(appState.statuses) { status in
                    HStack {
                        Text(status.dataset.rawValue.capitalized)
                            .font(.subheadline.weight(.semibold))
                        Spacer(minLength: 0)
                        SagasuStatusPill(
                            title: "Status",
                            value: appState.formattedStatus(status),
                            tint: SagasuTheme.stateColor(for: status.state)
                        )
                    }
                }
            }
        }
    }

    private var roomsPanel: some View {
        SagasuPanel(
            title: "Room preview",
            subtitle: "The menu bar window prioritizes what you can use next.",
            systemImage: "building.2"
        ) {
            if preferredRooms.isEmpty {
                SagasuEmptyStateCard(
                    title: "Waiting for cached data",
                    message: "No room availability has been written locally yet.",
                    systemImage: "building.2.crop.circle"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(preferredRooms) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.title)
                                    .font(.headline)
                                    .lineLimit(1)

                                Spacer(minLength: 0)

                                Text(item.detail)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            Text(item.context)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                    }
                }
            }
        }
    }

    private var actionsPanel: some View {
        SagasuPanel(
            title: "Quick actions",
            subtitle: "The menu bar stays focused on the highest-frequency controls.",
            systemImage: "bolt.fill"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Button(appState.isLoading ? "Refreshing…" : "Refresh Helper Snapshot", action: refreshSnapshot)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(appState.isLoading)

                Button("Open Desktop Dashboard", action: openDashboard)
                    .buttonStyle(.bordered)

                Button("Quit", action: quitApplication)
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var runtimePanel: some View {
        SagasuPanel(
            title: "Runtime",
            subtitle: "Quick context for the helper and auth stores backing this desktop client.",
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

    private var summaryColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    private var preferredRooms: [AppState.RoomLine] {
        if !appState.nextAvailable.isEmpty {
            return Array(appState.nextAvailable.prefix(5))
        }

        return Array(appState.availableNow.prefix(5))
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func errorPanel(message: String) -> some View {
        SagasuPanel(
            title: "Helper warning",
            subtitle: "The local helper reported an issue. Existing cached data is preserved where possible.",
            systemImage: "exclamationmark.triangle.fill"
        ) {
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
