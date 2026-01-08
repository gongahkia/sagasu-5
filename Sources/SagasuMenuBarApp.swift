import SwiftUI

@main
struct SagasuMenuBarApp: App {
	@StateObject private var appState = AppState()

	@State private var showLanding = true

	var body: some Scene {
		MenuBarExtra {
			ZStack {
				ContentView()
					.environmentObject(appState)
					.opacity(showLanding ? 0 : 1)
				if showLanding {
					LandingView(onDismiss: { showLanding = false })
						.transition(.opacity)
				}
			}
		} label: {
			MenuBarLabelView(appState: appState)
		}
		.menuBarExtraStyle(.window)
	}
}
