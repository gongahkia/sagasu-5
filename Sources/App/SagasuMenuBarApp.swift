import SwiftUI

@main
struct SagasuMenuBarApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup(id: "dashboard") {
            DesktopDashboardView()
                .environmentObject(appState)
        }

        MenuBarExtra {
            ContentView()
                .environmentObject(appState)
        } label: {
            MenuBarLabelView(appState: appState)
        }
        .menuBarExtraStyle(.window)
    }
}
