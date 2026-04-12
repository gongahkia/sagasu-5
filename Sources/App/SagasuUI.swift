import AppKit
import SwiftUI
import SagasuShared

enum SagasuTheme {
    static let brand = Color(red: 0.00, green: 0.48, blue: 0.42)
    static let brandSecondary = Color(red: 0.11, green: 0.38, blue: 0.78)
    static let groupedBackground = Color(nsColor: .windowBackgroundColor)
    static let groupFill = Color(nsColor: .controlBackgroundColor)
    static let rowFill = Color.primary.opacity(0.045)
    static let separator = Color.primary.opacity(0.10)
    static let success = Color(red: 0.14, green: 0.62, blue: 0.20)

    static func stateColor(for state: DatasetState) -> Color {
        switch state {
        case .idle:
            return .secondary
        case .loading:
            return .orange
        case .success:
            return success
        case .stale:
            return .yellow
        case .failed:
            return .red
        }
    }
}

struct SagasuScreenBackground: View {
    var body: some View {
        SagasuTheme.groupedBackground
            .ignoresSafeArea()
    }
}

struct SagasuPanel<Content: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let showsIcon: Bool
    private let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        showsIcon: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.showsIcon = showsIcon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 9) {
                if showsIcon {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SagasuTheme.brand)
                        .frame(width: 18, height: 18)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }

            content
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SagasuTheme.groupFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(SagasuTheme.separator, lineWidth: 1)
                }
        }
    }
}

struct SagasuMetricCard: View {
    let title: String
    let value: String
    let detail: String?
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SagasuTheme.rowFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(tint.opacity(0.16), lineWidth: 1)
                }
        )
    }
}

struct SagasuStatusPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }
}

struct SagasuEmptyStateCard: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.semibold))

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SagasuTheme.rowFill)
        )
    }
}

struct SagasuStatStrip: View {
    struct Entry: Identifiable {
        let id = UUID()
        let title: String
        let value: String
    }

    let entries: [Entry]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(entry.value)
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

                if index < entries.count - 1 {
                    Rectangle()
                        .fill(SagasuTheme.separator)
                        .frame(width: 1)
                        .padding(.vertical, 8)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SagasuTheme.rowFill)
        )
    }
}

struct SagasuRow: View {
    let title: String
    let value: String
    let systemImage: String?
    let tint: Color

    init(
        title: String,
        value: String,
        systemImage: String? = nil,
        tint: Color = .secondary
    ) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 16)
            }

            Text(title)
                .font(.caption)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.vertical, 3)
    }
}

struct SagasuScrapeSummary: Identifiable {
    let id: String
    let title: String
    let scrapedAt: String
    let duration: String
    let state: String
    let stateTint: Color
    let detail: String?
}

struct SagasuScrapeSummaryDisclosureCard: View {
    let summary: SagasuScrapeSummary
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 0) {
                Divider()
                    .padding(.vertical, 4)

                SagasuRow(title: summary.scrapedAt, value: "", systemImage: "clock", tint: .secondary)
                SagasuRow(title: summary.duration, value: "", systemImage: "timer", tint: .secondary)
                SagasuRow(title: summary.state, value: "", systemImage: "checkmark.circle", tint: summary.stateTint)

                if let detail = summary.detail {
                    SagasuRow(title: detail, value: "", systemImage: "calendar", tint: .secondary)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(summary.title)
                    .font(.caption.weight(.semibold))

                Spacer(minLength: 8)

                Circle()
                    .fill(summary.stateTint)
                    .frame(width: 6, height: 6)

                Text(summary.state)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SagasuTheme.rowFill)
        )
    }
}

struct SagasuScrapeSummaryCard: View {
    let summary: SagasuScrapeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(summary.title)
                    .font(.caption.weight(.semibold))

                Spacer(minLength: 8)

                Circle()
                    .fill(summary.stateTint)
                    .frame(width: 6, height: 6)

                Text(summary.state)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Divider()
                .padding(.vertical, 2)

            SagasuRow(title: summary.scrapedAt, value: "", systemImage: "clock", tint: .secondary)
            SagasuRow(title: summary.duration, value: "", systemImage: "timer", tint: .secondary)

            if let detail = summary.detail {
                SagasuRow(title: detail, value: "", systemImage: "calendar", tint: .secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SagasuTheme.rowFill)
        )
    }
}

struct SagasuFooterText: View {
    let lastFetch: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
                .padding(.bottom, 3)

            Text("Last fetch: \(lastFetch)")
            Text("Data updates daily at 8:00 AM SGT")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}
