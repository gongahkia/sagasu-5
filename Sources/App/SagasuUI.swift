import SwiftUI
import SagasuShared

enum SagasuTheme {
    static let brand = Color(red: 0.08, green: 0.62, blue: 0.57)
    static let brandSecondary = Color(red: 0.16, green: 0.40, blue: 0.84)
    static let backgroundTop = Color(red: 0.96, green: 0.98, blue: 0.97)
    static let backgroundBottom = Color(red: 0.91, green: 0.95, blue: 0.99)

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                brand,
                brandSecondary
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var pageGradient: LinearGradient {
        LinearGradient(
            colors: [
                backgroundTop,
                backgroundBottom
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func stateColor(for state: DatasetState) -> Color {
        switch state {
        case .idle:
            return .secondary
        case .loading:
            return .orange
        case .success:
            return .green
        case .stale:
            return .yellow
        case .failed:
            return .red
        }
    }
}

struct SagasuScreenBackground: View {
    var body: some View {
        SagasuTheme.pageGradient
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(SagasuTheme.brand.opacity(0.16))
                    .frame(width: 280, height: 280)
                    .blur(radius: 18)
                    .offset(x: 96, y: -72)
            }
            .overlay(alignment: .bottomLeading) {
                Circle()
                    .fill(SagasuTheme.brandSecondary.opacity(0.12))
                    .frame(width: 320, height: 320)
                    .blur(radius: 24)
                    .offset(x: -120, y: 100)
            }
            .ignoresSafeArea()
    }
}

struct SagasuHeroBanner<Content: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let systemImage: String
    private let content: Content

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(eyebrow.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.82))

                    Text(title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.88))
                }

                Spacer(minLength: 0)

                Image(systemName: systemImage)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            content
        }
        .padding(20)
        .background(
            SagasuTheme.heroGradient,
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 22, x: 0, y: 16)
    }
}

struct SagasuPanel<Content: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    private let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(SagasuTheme.brand)
                    .frame(width: 34, height: 34)
                    .background(SagasuTheme.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    if let subtitle {
                        Text(subtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }

            content
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.45), lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 10)
    }
}

struct SagasuMetricCard: View {
    let title: String
    let value: String
    let detail: String?
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)

                Spacer(minLength: 0)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(tint.opacity(0.14), lineWidth: 1)
                }
        )
    }
}

struct SagasuStatusPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)

                Text(value)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }
}

struct SagasuEmptyStateCard: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.quaternary.opacity(0.7))
        )
    }
}
