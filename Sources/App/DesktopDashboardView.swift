import SwiftUI
import SagasuShared

struct DesktopDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var email: String = ""
    @State private var password: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    datasetCards
                    authPanel
                    helperPanel
                    roomsPanel
                    bookingsPanel
                    tasksPanel
                    consolePanel
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Sagasu Desktop")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(appState.isLoading ? "Refreshing…" : "Refresh Now") {
                        appState.refresh(manual: true)
                    }
                    .disabled(appState.isLoading)
                }
            }
        }
        .frame(minWidth: 920, minHeight: 680)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Native local snapshot")
                .font(.largeTitle.weight(.bold))
            Text("The desktop app now reads locally cached room, booking, and task data produced by the helper instead of GitHub-hosted JSON.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var datasetCards: some View {
        HStack(spacing: 12) {
            ForEach(appState.statuses) { status in
                VStack(alignment: .leading, spacing: 6) {
                    Text(status.dataset.rawValue.capitalized)
                        .font(.headline)
                    Text(appState.formattedStatus(status))
                        .font(.subheadline.weight(.medium))
                    if let message = status.message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var roomsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rooms")
                .font(.title3.weight(.semibold))

            if let rooms = appState.rooms?.rooms, !rooms.isEmpty {
                ForEach(rooms.prefix(12)) { room in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(room.name)
                                .fontWeight(.medium)
                            Spacer()
                            Text(room.availability_summary.is_available_now ? "Free now" : "Next: \(appState.formattedScrapedAt(room.availability_summary.next_available_at))")
                                .foregroundStyle(.secondary)
                        }
                        Text("\(room.building) • \(room.floor) • \(room.facility_type)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            } else {
                emptyState("No locally cached room rows are available yet.")
            }
        }
    }

    private var authPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Authentication")
                .font(.title3.weight(.semibold))

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

                Button("Clear credentials") {
                    appState.clearCredentials()
                    email = ""
                    password = ""
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var helperPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Helper control")
                .font(.title3.weight(.semibold))

            Text("Mode: \(appState.helperModeDescription)")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                ForEach(HelperRunMode.allCases) { mode in
                    Button(appState.helperMode == mode ? "\(mode.title) running" : "Start \(mode.title)") {
                        appState.startHelper(mode: mode)
                    }
                    .buttonStyle(.bordered)
                }

                Button("Stop helper") {
                    appState.stopHelper()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var bookingsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bookings")
                .font(.title3.weight(.semibold))

            if !appState.recentBookings.isEmpty {
                ForEach(appState.recentBookings) { booking in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(booking.room_name)
                                .fontWeight(.medium)
                            Text("\(booking.date) • \(booking.start_time)-\(booking.end_time)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(booking.status)
                            .font(.caption.weight(.medium))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            } else {
                emptyState("No bookings are cached right now.")
            }
        }
    }

    private var tasksPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tasks")
                .font(.title3.weight(.semibold))

            if !appState.recentTasks.isEmpty {
                ForEach(appState.recentTasks) { task in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.task_type)
                                .fontWeight(.medium)
                            Text("\(task.room_name) • \(task.date)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(task.status)
                            .font(.caption.weight(.medium))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            } else {
                emptyState("No task rows are cached right now.")
            }
        }
    }

    private var consolePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Helper console")
                .font(.title3.weight(.semibold))
            ScrollView {
                Text(appState.helperConsole.isEmpty ? "No helper output recorded yet." : appState.helperConsole)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 180)
            .padding(12)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
