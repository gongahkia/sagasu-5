import SwiftUI
import SagasuShared

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
            return String(rooms.statistics.available_rooms)
        }

        return appState.authState.has_credentials ? "0" : "?"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "building.2.crop.circle")
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
