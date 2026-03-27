import SwiftUI
import SagasuShared

enum DashboardSelection {
    case room(ScrapedRoomsResponse.Room)
    case booking(ScrapedBookingsResponse.Booking)
    case task(ScrapedTasksResponse.Task)
}

struct DatasetHealthPanel: View {
    let statuses: [DatasetStatus]
    let formattedStatus: (DatasetStatus) -> String
    let formattedTimestamp: (String?) -> String

    var body: some View {
        SagasuPanel(
            title: "Dataset health",
            subtitle: "Every helper refresh updates the cached rooms, bookings, and tasks payloads independently.",
            systemImage: "waveform.path.ecg.rectangle"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(statuses) { status in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(status.dataset.rawValue.capitalized)
                                .font(.headline)

                            Spacer(minLength: 0)

                            SagasuStatusPill(
                                title: "State",
                                value: formattedStatus(status),
                                tint: SagasuTheme.stateColor(for: status.state)
                            )
                        }

                        if let message = status.message {
                            Text(message)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }

                        LabeledContent("Last success", value: formattedTimestamp(status.last_success_at))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(SagasuTheme.stateColor(for: status.state).opacity(0.08))
                    )
                }
            }
        }
    }
}

struct DashboardSelectionPanel: View {
    let selection: DashboardSelection?
    let formattedTimestamp: (String?) -> String

    var body: some View {
        SagasuPanel(
            title: "Selected detail",
            subtitle: "Pick a room, booking, or task below to inspect the currently cached record.",
            systemImage: "sidebar.right"
        ) {
            Group {
                if let selection {
                    switch selection {
                    case let .room(room):
                        roomDetail(room)
                    case let .booking(booking):
                        bookingDetail(booking)
                    case let .task(task):
                        taskDetail(task)
                    }
                } else {
                    SagasuEmptyStateCard(
                        title: "Nothing selected",
                        message: "Choose a row from the rooms, bookings, or tasks panels to inspect more detail.",
                        systemImage: "cursorarrow.click"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func roomDetail(_ room: ScrapedRoomsResponse.Room) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(room.name)
                        .font(.title3.weight(.semibold))

                    Text("\(room.building) • \(room.floor) • \(room.facility_type)")
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                SagasuStatusPill(
                    title: "Availability",
                    value: room.availability_summary.is_available_now
                        ? "Free now"
                        : formattedTimestamp(room.availability_summary.next_available_at),
                    tint: room.availability_summary.is_available_now ? .green : .orange
                )
            }

            ForEach(Array(room.timeslots.prefix(8).enumerated()), id: \.offset) { _, slot in
                HStack {
                    Text("\(slot.start) - \(slot.end)")
                        .font(.system(.caption, design: .monospaced))
                    Spacer(minLength: 0)
                    Text(slot.status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func bookingDetail(_ booking: ScrapedBookingsResponse.Booking) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(booking.room_name)
                .font(.title3.weight(.semibold))

            detailRow(label: "Window", value: "\(booking.date) • \(booking.start_time)-\(booking.end_time)")
            detailRow(label: "Booked by", value: booking.booked_by)
            detailRow(label: "Type", value: booking.booking_type)
            detailRow(label: "Status", value: booking.status)
        }
    }

    @ViewBuilder
    private func taskDetail(_ task: ScrapedTasksResponse.Task) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(task.task_type)
                .font(.title3.weight(.semibold))

            detailRow(label: "Room", value: task.room_name)
            detailRow(label: "Date", value: task.date)
            detailRow(label: "Requested by", value: task.requested_by)
            detailRow(label: "Status", value: task.status)
        }
    }

    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        LabeledContent(label, value: value)
            .font(.callout)
    }
}

struct RoomsPanel: View {
    let rooms: [ScrapedRoomsResponse.Room]
    let selectedRoomID: String?
    let onSelect: (String) -> Void
    let formattedTimestamp: (String?) -> String

    var body: some View {
        SagasuPanel(
            title: "Rooms",
            subtitle: "The latest locally cached availability records.",
            systemImage: "door.left.hand.open"
        ) {
            if rooms.isEmpty {
                SagasuEmptyStateCard(
                    title: "No rooms cached",
                    message: "Run a refresh after credentials are stored to hydrate the local room snapshot.",
                    systemImage: "building.2"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(rooms.prefix(10)) { room in
                        SelectableListCard(
                            isSelected: room.id == selectedRoomID,
                            action: {
                                onSelect(room.id)
                            }
                        ) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(room.name)
                                        .font(.headline)
                                        .lineLimit(1)

                                    Spacer(minLength: 0)

                                    Text(
                                        room.availability_summary.is_available_now
                                            ? "Free now"
                                            : formattedTimestamp(room.availability_summary.next_available_at)
                                    )
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                }

                                Text("\(room.building) • \(room.floor) • \(room.facility_type)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct BookingsPanel: View {
    let bookings: [ScrapedBookingsResponse.Booking]
    let selectedBookingID: String?
    let onSelect: (String) -> Void

    var body: some View {
        SagasuPanel(
            title: "Bookings",
            subtitle: "Recent booking rows from the cached snapshot.",
            systemImage: "calendar.badge.clock"
        ) {
            if bookings.isEmpty {
                SagasuEmptyStateCard(
                    title: "No bookings cached",
                    message: "Once the helper refreshes successfully, recent booking rows will appear here.",
                    systemImage: "calendar"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(bookings) { booking in
                        SelectableListCard(
                            isSelected: booking.id == selectedBookingID,
                            action: {
                                onSelect(booking.id)
                            }
                        ) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(booking.room_name)
                                        .font(.headline)
                                    Text("\(booking.date) • \(booking.start_time)-\(booking.end_time)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 0)

                                Text(booking.status)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct TasksPanel: View {
    let tasks: [ScrapedTasksResponse.Task]
    let selectedTaskID: String?
    let onSelect: (String) -> Void

    var body: some View {
        SagasuPanel(
            title: "Tasks",
            subtitle: "Recently cached task activity produced by the helper.",
            systemImage: "checklist"
        ) {
            if tasks.isEmpty {
                SagasuEmptyStateCard(
                    title: "No tasks cached",
                    message: "Task rows will appear once the local helper writes them into the snapshot.",
                    systemImage: "list.bullet.rectangle"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(tasks) { task in
                        SelectableListCard(
                            isSelected: task.id == selectedTaskID,
                            action: {
                                onSelect(task.id)
                            }
                        ) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(task.task_type)
                                        .font(.headline)
                                    Text("\(task.room_name) • \(task.date)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 0)

                                Text(task.status)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct HelperConsolePanel: View {
    let console: String

    var body: some View {
        SagasuPanel(
            title: "Helper console",
            subtitle: "Stdout and stderr captured from the most recent helper runs.",
            systemImage: "terminal"
        ) {
            ScrollView {
                Text(console.isEmpty ? "No helper output recorded yet." : console)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 200)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.06))
            )
        }
    }
}

private struct SelectableListCard<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    private let content: Content

    init(
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isSelected ? SagasuTheme.brand.opacity(0.14) : Color.primary.opacity(0.04))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    isSelected ? SagasuTheme.brand.opacity(0.32) : Color.primary.opacity(0.06),
                                    lineWidth: 1
                                )
                        }
                )
        }
        .buttonStyle(.plain)
    }
}
