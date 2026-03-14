import AppKit
import SwiftUI
import SagasuShared

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var appState: AppState
    @State private var email: String = ""
    @State private var password: String = ""

    private var summaryColumns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible())]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header

                if let errorMessage = appState.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                summaryGrid
                statusGrid
                authSection
                helperSection
                roomsSection
                actionsSection
                footer
            }
            .padding(14)
        }
        .frame(width: 430, height: 560)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sagasu 5")
                .font(.title3.weight(.semibold))
            Text("Local desktop client backed by the native helper service.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: summaryColumns, spacing: 8) {
            SummaryTile(title: "Free now", value: String(appState.rooms?.statistics.available_rooms ?? 0))
            SummaryTile(title: "Partial", value: String(appState.rooms?.statistics.partially_available_rooms ?? 0))
            SummaryTile(title: "Bookings", value: String(appState.bookings?.statistics.total_bookings ?? 0))
            SummaryTile(title: "Tasks", value: String(appState.tasks?.statistics.total_tasks ?? 0))
        }
    }

    private var statusGrid: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Service state")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(appState.statuses) { status in
                HStack {
                    Text(status.dataset.rawValue.capitalized)
                        .fontWeight(.medium)
                    Spacer()
                    Text(appState.formattedStatus(status))
                        .foregroundStyle(color(for: status.state))
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Rooms")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !appState.nextAvailable.isEmpty {
                RoomLineList(items: appState.nextAvailable)
            } else if !appState.availableNow.isEmpty {
                RoomLineList(items: appState.availableNow)
            } else {
                Text("No room availability has been cached locally yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var authSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Authentication")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("SMU email", text: $email)
                .textFieldStyle(.roundedBorder)
            SecureField("SMU password", text: $password)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Save to Keychain") {
                    appState.saveCredentials(email: email, password: password)
                    password = ""
                }
                .buttonStyle(.borderedProminent)

                Button("Clear") {
                    appState.clearCredentials()
                    email = ""
                    password = ""
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var helperSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Helper control")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                ForEach(HelperRunMode.allCases) { mode in
                    Button(appState.helperMode == mode ? "\(mode.title) running" : "Start \(mode.title)") {
                        appState.startHelper(mode: mode)
                    }
                    .buttonStyle(.bordered)
                }

                Button("Stop") {
                    appState.stopHelper()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 8) {
            Button("Refresh Helper Snapshot") {
                appState.refresh(manual: true)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(appState.isLoading)

            Button("Open Desktop Dashboard") {
                openWindow(id: "dashboard")
            }
            .buttonStyle(.bordered)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Last helper refresh: \(appState.formattedLastRefresh)")
            Text("Auth store: \(appState.authState.storage_mode.rawValue.capitalized)")
            Text("Helper mode: \(appState.helperModeDescription)")
            Text(appState.authState.runtime)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func color(for state: DatasetState) -> Color {
        switch state {
        case .idle: return .secondary
        case .loading: return .orange
        case .success: return .green
        case .stale: return .yellow
        case .failed: return .red
        }
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct RoomLineList: View {
    let items: [AppState.RoomLine]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.title)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Spacer()
                        Text(item.detail)
                            .foregroundStyle(.secondary)
                    }
                    Text(item.context)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}
