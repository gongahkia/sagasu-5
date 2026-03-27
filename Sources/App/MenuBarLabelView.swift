import SwiftUI
import SagasuShared

struct MenuBarLabelView: View {
    @ObservedObject var appState: AppState

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

    private var tint: Color {
        if appState.isLoading {
            return .orange
        }

        if appState.errorMessage != nil {
            return .red
        }

        if appState.authState.has_credentials {
            return SagasuTheme.brand
        }

        return .secondary
    }

    private var symbolName: String {
        if appState.errorMessage != nil {
            return "exclamationmark.triangle.fill"
        }

        if appState.isLoading {
            return "arrow.clockwise.circle.fill"
        }

        return "building.2.crop.circle.fill"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)

            Text(badgeText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(tint.opacity(0.14), in: Capsule())
        }
        .padding(.horizontal, 4)
        .accessibilityLabel(appState.menuBarTitle)
    }
}
