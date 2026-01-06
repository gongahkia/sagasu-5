import SwiftUI

struct MenuBarLabelView: View {
    let appState: AppState

    private var badgeText: String {
        if appState.isLoading {
            return "…"
        }

        if appState.errorMessage != nil {
            return "!"
        }

        if let rooms = appState.rooms {
            let anyFreeCount = rooms.rooms?.filter { $0.availability_summary.free_slots_count > 0 }.count ?? 0
            return String(anyFreeCount)
        }

        return "0"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "building.2")
                .font(.system(size: 13, weight: .medium))

            Text(badgeText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.quaternary, in: Capsule())
        }
        .accessibilityLabel(appState.menuBarTitle)
    }
}
