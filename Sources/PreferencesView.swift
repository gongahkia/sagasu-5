import SwiftUI

struct PreferencesView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("showRoomsCard") private var showRoomsCard: Bool = true
    @AppStorage("showBookingsCard") private var showBookingsCard: Bool = true
    @AppStorage("showTasksCard") private var showTasksCard: Bool = true
    @AppStorage("showDetailsCard") private var showDetailsCard: Bool = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(radius: 10)
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Preferences")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
                Divider()
                Text("Select which cards/subtabs to show on the menubar app.")
                    .font(.headline)
                Form {
                    Toggle("Rooms", isOn: $showRoomsCard)
                    Toggle("Bookings", isOn: $showBookingsCard)
                    Toggle("Tasks", isOn: $showTasksCard)
                    Toggle("Details", isOn: $showDetailsCard)
                }
                .formStyle(.grouped)
                Spacer()
            }
            .padding(24)
            .frame(width: 400, height: 300)
        }
    }
}