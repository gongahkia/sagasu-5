import SwiftUI
import SagasuShared

struct CredentialsPanel: View {
    let title: String
    let subtitle: String?
    @Binding var email: String
    @Binding var password: String
    let onSave: () -> Void
    let onClear: () -> Void

    var body: some View {
        SagasuPanel(
            title: title,
            subtitle: subtitle,
            systemImage: "person.crop.circle.badge.key",
            showsIcon: false
        ) {
            VStack(alignment: .leading, spacing: 7) {
                TextField("SMU email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)

                SecureField("SMU password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)

                HStack(spacing: 7) {
                    Button("Save to Keychain", action: onSave)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                    Button("Clear Credentials", action: onClear)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
    }
}

struct HelperControlsPanel: View {
    let currentMode: HelperRunMode?
    let currentDescription: String
    let onStart: (HelperRunMode) -> Void
    let onStop: () -> Void

    var body: some View {
        SagasuPanel(
            title: "Helper control",
            systemImage: "cpu",
            showsIcon: false
        ) {
            VStack(alignment: .leading, spacing: 6) {
                SagasuRow(title: "Mode", value: currentDescription)

                HStack(spacing: 6) {
                    ForEach(HelperRunMode.allCases) { mode in
                        helperButton(for: mode)
                    }

                    Button("Stop", action: onStop)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    private func helperButton(for mode: HelperRunMode) -> some View {
        if currentMode == mode {
            Button("\(mode.title) Active") {
                onStart(mode)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        } else {
            Button("Start \(mode.title)") {
                onStart(mode)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

struct BackgroundServicePanel: View {
    let status: HelperLaunchAgentStatus?
    let summary: String
    let showsPaths: Bool
    let onInstall: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void
    let onRemove: () -> Void

    var body: some View {
        SagasuPanel(
            title: "Background service",
            systemImage: "clock.arrow.2.circlepath",
            showsIcon: false
        ) {
            VStack(alignment: .leading, spacing: 6) {
                SagasuRow(title: "Launch agent", value: summary)

                if showsPaths, let status {
                    VStack(alignment: .leading, spacing: 8) {
                        pathRow(title: "Plist", value: status.plistURL.path)
                        pathRow(title: "Log", value: status.logURL.path)

                        if let helperURL = status.helperURL {
                            pathRow(title: "Helper", value: helperURL.path)
                        }
                    }
                }

                HStack(spacing: 6) {
                    Button("Install", action: onInstall)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                    Button("Start", action: onStart)
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    Button("Stop", action: onStop)
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    Button("Remove", action: onRemove)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
    }

    private var statusTint: Color {
        guard let status else { return .secondary }
        if status.isLoaded {
            return .green
        }
        if status.isInstalled {
            return .yellow
        }
        return .secondary
    }

    @ViewBuilder
    private func pathRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(.secondary)
        }
    }
}

struct ScrapePreferencesPanel: View {
    @Binding var preferences: ScrapePreferences
    let onSave: () -> Void

    var body: some View {
        SagasuPanel(
            title: "Scrape preferences",
            systemImage: "slider.horizontal.3"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: columns, spacing: 10) {
                    textField(title: "Date", text: $preferences.date, prompt: "TODAY")
                    textField(title: "Start", text: $preferences.start_time, prompt: "08:00")
                    textField(title: "End", text: $preferences.end_time, prompt: "22:00")
                    textField(title: "Capacity", text: $preferences.capacity, prompt: "Optional")
                }

                textField(title: "Buildings", text: csvBinding(for: \.buildings), prompt: "Comma-separated")
                textField(title: "Floors", text: csvBinding(for: \.floors), prompt: "Comma-separated")
                textField(title: "Facility types", text: csvBinding(for: \.facility_types), prompt: "Comma-separated")
                textField(title: "Equipment", text: csvBinding(for: \.equipment), prompt: "Comma-separated")

                Button("Save preferences", action: onSave)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    @ViewBuilder
    private func textField(title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func csvBinding(for keyPath: WritableKeyPath<ScrapePreferences, [String]>) -> Binding<String> {
        Binding(
            get: {
                preferences[keyPath: keyPath].joined(separator: ", ")
            },
            set: { value in
                preferences[keyPath: keyPath] = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }
}
