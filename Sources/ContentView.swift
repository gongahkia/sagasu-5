import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
        @State private var showDetails: Bool = false
        @State private var showPreferences: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header

                if let errorMessage = appState.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                summaryGrid

                roomsSection

                @AppStorage("showRoomsCard") private var showRoomsCard: Bool = true
                @AppStorage("showBookingsCard") private var showBookingsCard: Bool = true
                @AppStorage("showTasksCard") private var showTasksCard: Bool = true
                @AppStorage("showDetailsCard") private var showDetailsCard: Bool = true

                var body: some View {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            header

                            if let errorMessage = appState.errorMessage {
                                Label(errorMessage, systemImage: "exclamationmark.triangle")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }

                            summaryGrid

                            if showRoomsCard { roomsSection }
                            if showBookingsCard { bookingsSection }
                            if showTasksCard { tasksSection }
                            if showDetailsCard {
                                DisclosureGroup("Details", isExpanded: $showDetails) {
                                    detailsSection
                                }
                                .font(.callout)
                            }

                            footer

                            Divider()
                            HStack {
                                Spacer()
                                Button {
                                    showPreferences = true
                                } label: {
                                    Label("Preferences", systemImage: "gearshape")
                                }
                                .buttonStyle(.bordered)
                                Button {
                                    NSApplication.shared.terminate(nil)
                                } label: {
                                    Label("Quit", systemImage: "power")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .sheet(isPresented: $showPreferences) {
                            PreferencesView()
                        }
                        .padding(12)
                    }
                    .frame(width: 420, height: 560)
                }
        return LazyVGrid(columns: columns, spacing: 10) {
            SummaryTile(title: "Free now", value: String(appState.rooms?.statistics.available_rooms ?? 0), tooltip: "Fully available rooms")
            SummaryTile(title: "Partial", value: String(appState.rooms?.statistics.partially_available_rooms ?? 0), tooltip: "Some slots available")
            SummaryTile(title: "Booked", value: String(appState.rooms?.statistics.booked_rooms ?? 0), tooltip: "Completely booked")
            SummaryTile(title: "Total", value: String(appState.rooms?.statistics.total_rooms ?? 0), tooltip: "All tracked rooms")
        }
    }

    var roomsSection: some View {
        Group {
            Text("Rooms next available at")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !appState.nextAvailable.isEmpty {
                RoomsList(items: appState.nextAvailable)
            } else if !appState.availableNow.isEmpty {
                RoomsList(items: appState.availableNow)
            } else {
                Text("No room availability details.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
                    Divider()
                    HStack {
                        Spacer()
                        Button {
                            NSApplication.shared.terminate(nil)
                        } label: {
                            Label("Quit", systemImage: "power")
                        }
                        .buttonStyle(.borderedProminent)
                    }
        }
    }

    var bookingsSection: some View {
        Group {
            if let bookings = appState.bookings {
                Text("Bookings")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                GroupBox {
                    HStack {
                        LabeledContent("Total", value: String(bookings.statistics.total_bookings))
                        Spacer()
                        LabeledContent("Pending", value: String(bookings.statistics.pending_bookings))
                        Spacer()
                        LabeledContent("Confirmed", value: String(bookings.statistics.confirmed_bookings))
                    }
                }
            }
        }
    }

    var tasksSection: some View {
        Group {
            if let tasks = appState.tasks {
                Text("Tasks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                GroupBox {
                    HStack {
                        LabeledContent("Total", value: String(tasks.statistics.total_tasks))
                        Spacer()
                        LabeledContent("Pending", value: String(tasks.statistics.pending_tasks))
                        Spacer()
                        LabeledContent("Approved", value: String(tasks.statistics.approved_tasks))
                    }
                }
            }
        }
    }

    var detailsSection: some View {
        return VStack(alignment: .leading, spacing: 8) {
            DetailCard(
                title: "Rooms",
                updated: appState.formattedScrapedAt(appState.rooms?.metadata.scraped_at),
                duration: appState.rooms?.metadata.scrape_duration_ms,
                success: appState.rooms?.metadata.success ?? false,
                extra: appState.rooms.map { "\($0.config.date) \($0.config.start_time)–\($0.config.end_time)" }
            )

            DetailCard(
                title: "Bookings",
                updated: appState.formattedScrapedAt(appState.bookings?.metadata.scraped_at),
                duration: appState.bookings?.metadata.scrape_duration_ms,
                success: appState.bookings?.metadata.success ?? false,
                extra: nil
            )

            DetailCard(
                title: "Tasks",
                updated: appState.formattedScrapedAt(appState.tasks?.metadata.scraped_at),
                duration: appState.tasks?.metadata.scrape_duration_ms,
                success: appState.tasks?.metadata.success ?? false,
                extra: nil
            )
        }
        .padding(.top, 6)
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String
    var tooltip: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .help(tooltip)
    }
}

private struct DetailCard: View {
    let title: String
    let updated: String
    let duration: Int?
    let success: Bool
    let extra: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Divider()

            Group {
                Label(updated, systemImage: "clock")
                if let duration {
                    Label("\(duration) ms", systemImage: "timer")
                }
                Label(success ? "Success" : "Failed", systemImage: success ? "checkmark.circle" : "xmark.circle")
                    .foregroundStyle(success ? .green : .red)
                if let extra {
                    Label(extra, systemImage: "calendar")
                }
            }
            .font(.caption2)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct RoomsList: View {
    let items: [AppState.RoomLine]

    var body: some View {
        GroupBox {
            VStack(spacing: 6) {
                ForEach(items.prefix(8)) { item in
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.title)
                            .lineLimit(1)
                        Spacer(minLength: 10)
                        Text(item.detail)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .font(.callout)

                    if item.id != items.prefix(8).last?.id {
                        Divider()
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}
