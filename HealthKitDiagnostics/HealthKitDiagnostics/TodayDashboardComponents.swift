import Foundation
import MetricsCore
import SwiftUI

struct DashboardBackground: View {
    var body: some View {
        ZStack {
            AppTheme.dashboardBackground

            RadialGradient(
                colors: [
                    AppTheme.dashboardBlue.opacity(0.20),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 190
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    AppTheme.dashboardViolet.opacity(0.10),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .allowsHitTesting(false)
    }
}

struct DashboardHeader: View {
    let date: Date
    let dataStatusText: String
    let dataStatusSymbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            Label(dataStatusText, systemImage: dataStatusSymbol)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct RecoveryHero: View {
    let signal: RecoverySignal?
    let animates: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseExpanded = false

    private var style: RecoveryHeroStyle {
        RecoveryHeroStyle(level: signal?.level)
    }

    private var shouldAnimate: Bool {
        animates && !reduceMotion
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            style.primary.opacity(0.30),
                            AppTheme.dashboardSurface.opacity(0.96),
                            style.secondary.opacity(0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RadialGradient(
                colors: [style.secondary.opacity(0.30), .clear],
                center: .trailing,
                startRadius: 2,
                endRadius: 105
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            RecoveryPulseVisual(
                primary: style.primary,
                secondary: style.secondary,
                expanded: pulseExpanded
            )
            .frame(width: 76, height: 76)
            .offset(x: 8, y: 7)
            .opacity(0.82)

            VStack(alignment: .leading, spacing: 7) {
                Text("RECOVERY")
                    .font(.caption2.weight(.bold))
                    .tracking(1.15)
                    .foregroundStyle(style.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)

                ViewThatFits(in: .horizontal) {
                    heroStatus(font: .title2)
                    heroStatus(font: .title3)
                    heroStatus(font: .headline)
                }

                Text("Personal HRV and resting heart rate history")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, 34)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 15)
            .padding(.leading, 15)
            .padding(.trailing, 15)
        }
        .frame(minHeight: 126)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            style.primary.opacity(0.72),
                            style.secondary.opacity(0.18),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
        .shadow(color: style.primary.opacity(0.22), radius: 18, y: 7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String.localizedStringWithFormat(
                String(localized: "Recovery, %@. Based on your personal HRV and resting heart rate history."),
                recoveryHeroText(signal)
            )
        )
        .onAppear(perform: updatePulse)
        .onChange(of: shouldAnimate) { _, _ in updatePulse() }
    }

    private func updatePulse() {
        if shouldAnimate {
            pulseExpanded = false
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                pulseExpanded = true
            }
        } else {
            withAnimation(.none) {
                pulseExpanded = false
            }
        }
    }

    private func heroStatus(font: Font) -> some View {
        Text(recoveryHeroText(signal))
            .font(font.weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.80)
            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
    }
}

private struct RecoveryPulseVisual: View {
    let primary: Color
    let secondary: Color
    let expanded: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [primary.opacity(0.25), .clear],
                        center: .center,
                        startRadius: 2,
                        endRadius: 42
                    )
                )
                .scaleEffect(expanded ? 1.08 : 0.92)
                .opacity(expanded ? 0.48 : 0.82)

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            primary.opacity(0.88),
                            secondary.opacity(0.28),
                            primary.opacity(0.10),
                            primary.opacity(0.88)
                        ],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .padding(13)
                .scaleEffect(expanded ? 1.05 : 0.95)
                .opacity(expanded ? 0.48 : 0.78)

            Image(systemName: "heart.fill")
                .font(.title3)
                .foregroundStyle(
                    LinearGradient(
                        colors: [primary, secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: primary.opacity(0.55), radius: 7)
        }
        .accessibilityHidden(true)
    }
}

struct DashboardMetricTile: View {
    let title: String
    let accessibilityTitle: String
    let symbol: String
    let value: String?
    let unit: String?
    let status: String
    let statusColor: Color?
    let tint: Color
    let state: DataLoadState

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 18, height: 18)
                    .background(tint.opacity(0.14), in: Circle())

                Text(title)
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(0.25)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.32))
            }

            Group {
                if state == .loading {
                    StaticMetricPlaceholder(tint: tint)
                } else if let value {
                    VStack(alignment: .leading, spacing: 3) {
                        ViewThatFits(in: .horizontal) {
                            metricValue(value, unit: unit, font: .title3, unitFont: .caption2)
                            metricValue(value, unit: unit, font: .headline, unitFont: .caption2)
                        }
                        HStack(spacing: 4) {
                            if let statusColor {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 5, height: 5)
                            }
                            Text(status)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.62))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("—")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.45))
                        Text(compactStateMessage(state))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.60))
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(AppTheme.dashboardSurface.opacity(0.88))
                RadialGradient(
                    colors: [tint.opacity(0.18), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 92
                )
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [tint.opacity(0.42), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.7
                )
        }
        .shadow(color: tint.opacity(0.10), radius: 8, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(.isButton)
    }

    private func metricValue(
        _ value: String,
        unit: String?,
        font: Font,
        unitFont: Font
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(font.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
                .fixedSize(horizontal: true, vertical: false)
            if let unit {
                Text(unit)
                    .font(unitFont.weight(.semibold))
                    .foregroundStyle(tint)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var accessibilityDescription: String {
        if state == .loading {
            return String.localizedStringWithFormat(
                String(localized: "%@, loading"),
                accessibilityTitle
            )
        }
        guard let value else {
            return "\(accessibilityTitle), \(compactStateMessage(state))"
        }
        return "\(accessibilityTitle), \(value) \(unit ?? ""), \(status)"
    }
}

private struct StaticMetricPlaceholder: View {
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(tint.opacity(0.28))
                .frame(width: 42, height: 15)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.10))
                .frame(maxWidth: 58)
                .frame(height: 7)
        }
        .accessibilityHidden(true)
    }
}

struct MorningBriefCapsule: View {
    let text: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "sunrise.fill")
                .font(.caption)
                .foregroundStyle(AppTheme.dashboardAmber)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String.localizedStringWithFormat(
                String(localized: "Morning brief, %@"),
                text
            )
        )
    }
}

struct DashboardSecondaryNavigationLabel: View {
    let title: String
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.72))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.055), in: Capsule())
            .overlay {
                Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.7)
            }
    }
}

private struct RecoveryHeroStyle {
    let primary: Color
    let secondary: Color

    init(level: RecoverySignalLevel?) {
        switch level {
        case .favorable:
            primary = AppTheme.dashboardCyan
            secondary = AppTheme.dashboardGreen
        case .typical:
            primary = AppTheme.dashboardBlue
            secondary = AppTheme.dashboardCyan
        case .mixed:
            primary = AppTheme.dashboardViolet
            secondary = AppTheme.dashboardAmber
        case .strained:
            primary = AppTheme.dashboardMagenta
            secondary = AppTheme.dashboardRed
        case nil:
            primary = AppTheme.dashboardBlue
            secondary = AppTheme.dashboardViolet
        }
    }
}

private func recoveryHeroText(_ signal: RecoverySignal?) -> String {
    guard let signal else { return String(localized: "Collecting data") }
    return switch signal.level {
    case .favorable: String(localized: "Favorable")
    case .typical: String(localized: "Within personal range")
    case .mixed: String(localized: "Mixed signal")
    case .strained: String(localized: "Lower than usual")
    }
}

private func compactStateMessage(_ state: DataLoadState) -> String {
    switch state {
    case .idle: String(localized: "Waiting for data")
    case .loading: String(localized: "Loading")
    case .loaded: String(localized: "Data available")
    case .empty: String(localized: "No data")
    case .permissionDenied: String(localized: "Check Health")
    case .failed: String(localized: "Loading failed")
    }
}

func compactSleepValue(_ duration: TimeInterval) -> String {
    let totalMinutes = max(0, Int(duration / 60))
    return "\(totalMinutes / 60):\(String(format: "%02d", totalMinutes % 60))"
}
