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
                    hero
                    datasetCards
                    authPanel
                    helperPanel
                    backgroundServicePanel
                    configPanel
                    detailPanel
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

    private var backgroundServicePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Background service")
                .font(.title3.weight(.semibold))

            Text(appState.launchAgentDescription)
                .font(.callout)
                .foregroundStyle(.secondary)

            if let status = appState.launchAgentStatus {
                Text("Plist: \(status.plistURL.path)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("Log: \(status.logURL.path)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Install agent") {
                    appState.installBackgroundService()
                }
                .buttonStyle(.borderedProminent)

                Button("Start agent") {
                    appState.startBackgroundService()
                }
                .buttonStyle(.bordered)

                Button("Stop agent") {
                    appState.stopBackgroundService()
                }
                .buttonStyle(.bordered)

                Button("Remove agent") {
                    appState.uninstallBackgroundService()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var configPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scrape preferences")
                .font(.title3.weight(.semibold))

            HStack {
                TextField("Date or TODAY", text: Binding(
                    get: { appState.scrapePreferences.date },
                    set: { appState.scrapePreferences.date = $0 }
                ))
                .textFieldStyle(.roundedBorder)

                TextField("Start", text: Binding(
                    get: { appState.scrapePreferences.start_time },
                    set: { appState.scrapePreferences.start_time = $0 }
                ))
                .textFieldStyle(.roundedBorder)

                TextField("End", text: Binding(
                    get: { appState.scrapePreferences.end_time },
                    set: { appState.scrapePreferences.end_time = $0 }
                ))
                .textFieldStyle(.roundedBorder)

                TextField("Capacity", text: Binding(
                    get: { appState.scrapePreferences.capacity },
                    set: { appState.scrapePreferences.capacity = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }

            TextField("Buildings (comma-separated)", text: csvBinding(for: \.buildings))
                .textFieldStyle(.roundedBorder)
            TextField("Floors (comma-separated)", text: csvBinding(for: \.floors))
                .textFieldStyle(.roundedBorder)
            TextField("Facility types (comma-separated)", text: csvBinding(for: \.facility_types))
                .textFieldStyle(.roundedBorder)
            TextField("Equipment (comma-separated)", text: csvBinding(for: \.equipment))
                .textFieldStyle(.roundedBorder)

            Button("Save scrape preferences") {
                appState.saveScrapePreferences()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var detailPanel: some View {
        if let room = selectedRoom {
            VStack(alignment: .leading, spacing: 10) {
                Text("Selected room")
                    .font(.title3.weight(.semibold))
                Text(room.name)
                    .font(.headline)
                Text("\(room.building) • \(room.floor) • \(room.facility_type)")
                    .foregroundStyle(.secondary)
                ForEach(Array(room.timeslots.prefix(12).enumerated()), id: \.offset) { _, slot in
                    Text("\(slot.start)-\(slot.end) • \(slot.status)")
                        .font(.system(.caption, design: .monospaced))
                }
            }
        } else if let booking = selectedBooking {
            VStack(alignment: .leading, spacing: 10) {
                Text("Selected booking")
                    .font(.title3.weight(.semibold))
                Text(booking.room_name)
                    .font(.headline)
                Text("\(booking.date) • \(booking.start_time)-\(booking.end_time)")
                    .foregroundStyle(.secondary)
                Text("Booked by: \(booking.booked_by)")
                Text("Type: \(booking.booking_type)")
                Text("Status: \(booking.status)")
            }
        } else if let task = selectedTask {
            VStack(alignment: .leading, spacing: 10) {
                Text("Selected task")
                    .font(.title3.weight(.semibold))
                Text(task.task_type)
                    .font(.headline)
                Text("\(task.room_name) • \(task.date)")
                    .foregroundStyle(.secondary)
                Text("Requested by: \(task.requested_by)")
                Text("Status: \(task.status)")
            }
        }
    }

    private var roomsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rooms")
                .font(.title3.weight(.semibold))

            if let rooms = appState.rooms?.rooms, !rooms.isEmpty {
                ForEach(rooms.prefix(12)) { room in
                    Button {
                        selectedRoomID = room.id
                        selectedBookingID = nil
                        selectedTaskID = nil
                    } label: {
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
                    .buttonStyle(.plain)
                }
            } else {
                emptyState("No locally cached room rows are available yet.")
            }
        }
    }

    private var bookingsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bookings")
                .font(.title3.weight(.semibold))

            if !appState.recentBookings.isEmpty {
                ForEach(appState.recentBookings) { booking in
                    Button {
                        selectedBookingID = booking.id
                        selectedRoomID = nil
                        selectedTaskID = nil
                    } label: {
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
                    .buttonStyle(.plain)
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
                    Button {
                        selectedTaskID = task.id
                        selectedRoomID = nil
                        selectedBookingID = nil
                    } label: {
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
                    .buttonStyle(.plain)
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

    private func csvBinding(for keyPath: WritableKeyPath<ScrapePreferences, [String]>) -> Binding<String> {
        Binding<String>(
            get: {
                appState.scrapePreferences[keyPath: keyPath].joined(separator: ", ")
            },
            set: { value in
                appState.scrapePreferences[keyPath: keyPath] = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }
}
