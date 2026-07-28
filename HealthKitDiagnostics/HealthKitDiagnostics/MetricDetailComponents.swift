import Charts
import SwiftUI

struct MetricVisualTheme {
    enum Kind {
        case sleep
        case hrv
        case restingHeartRate
        case oxygenSaturation
    }

    let kind: Kind
    let title: String
    let symbol: String
    let identityColor: Color
    let secondaryColor: Color

    static let sleep = MetricVisualTheme(
        kind: .sleep,
        title: "Spánok",
        symbol: "bed.double.fill",
        identityColor: AppTheme.dashboardViolet,
        secondaryColor: AppTheme.dashboardBlue
    )

    static let hrv = MetricVisualTheme(
        kind: .hrv,
        title: "Nočná HRV",
        symbol: "waveform.path.ecg",
        identityColor: AppTheme.dashboardCyan,
        secondaryColor: AppTheme.dashboardCyan.opacity(0.62)
    )

    static let restingHeartRate = MetricVisualTheme(
        kind: .restingHeartRate,
        title: "Pokojový pulz",
        symbol: "heart.fill",
        identityColor: AppTheme.dashboardMagenta,
        secondaryColor: AppTheme.dashboardRed
    )

    static let oxygenSaturation = MetricVisualTheme(
        kind: .oxygenSaturation,
        title: "SpO₂",
        symbol: "lungs.fill",
        identityColor: AppTheme.dashboardBlue,
        secondaryColor: AppTheme.dashboardViolet
    )
}

struct MetricStatusPresentation {
    let text: String
    let context: String?
    let color: Color

    static func neutral(_ text: String, context: String? = nil) -> Self {
        MetricStatusPresentation(
            text: text,
            context: context,
            color: Color.white.opacity(0.48)
        )
    }
}

struct MetricDetailBackground: View {
    let theme: MetricVisualTheme

    var body: some View {
        ZStack {
            AppTheme.dashboardBackground

            RadialGradient(
                colors: [theme.identityColor.opacity(0.24), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 205
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    theme.secondaryColor.opacity(0.09),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .allowsHitTesting(false)
    }
}

struct MetricDetailScreen<Content: View>: View {
    let theme: MetricVisualTheme
    let value: String?
    let unit: String?
    let source: String
    let status: MetricStatusPresentation?
    let state: DataLoadState
    let unavailableText: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            MetricDetailBackground(theme: theme)
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    MetricDetailHero(
                        theme: theme,
                        value: value,
                        unit: unit,
                        source: source,
                        status: status,
                        state: state,
                        unavailableText: unavailableText
                    )
                    content()
                }
                .padding(.horizontal, 7)
                .padding(.bottom, 12)
            }
        }
        .navigationTitle(theme.title)
        .containerBackground(AppTheme.dashboardBackground, for: .navigation)
    }
}

struct MetricDetailHero: View {
    let theme: MetricVisualTheme
    let value: String?
    let unit: String?
    let source: String
    let status: MetricStatusPresentation?
    let state: DataLoadState
    let unavailableText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: theme.symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.identityColor)
                    .frame(width: 27, height: 27)
                    .background(theme.identityColor.opacity(0.15), in: Circle())
                    .overlay {
                        Circle().stroke(theme.identityColor.opacity(0.32), lineWidth: 0.7)
                    }

                Text(theme.title.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.9)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)
            }

            heroValue

            Text(source)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let status, state != .loading {
                MetricStatusCapsule(status: status)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.identityColor.opacity(0.22),
                                AppTheme.dashboardSurface.opacity(0.96),
                                theme.secondaryColor.opacity(0.11)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RadialGradient(
                    colors: [theme.identityColor.opacity(0.20), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 115
                )
                .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            theme.identityColor.opacity(0.65),
                            Color.white.opacity(0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
        .shadow(color: theme.identityColor.opacity(0.18), radius: 15, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    @ViewBuilder
    private var heroValue: some View {
        if state == .loading {
            VStack(alignment: .leading, spacing: 7) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(theme.identityColor.opacity(0.26))
                    .frame(width: 82, height: 29)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 106, height: 8)
            }
            .frame(minHeight: 48, alignment: .leading)
            .accessibilityHidden(true)
        } else if let value {
            ViewThatFits(in: .horizontal) {
                valueLine(value, unit: unit, valueFont: .largeTitle, unitFont: .callout)
                valueLine(value, unit: unit, valueFont: .title, unitFont: .caption)
                valueLine(value, unit: unit, valueFont: .title2, unitFont: .caption2)
            }
            .frame(minHeight: 48, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 3) {
                Text("—")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white.opacity(0.48))
                Text(unavailableText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 48, alignment: .leading)
        }
    }

    private func valueLine(
        _ value: String,
        unit: String?,
        valueFont: Font,
        unitFont: Font
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(value)
                .font(valueFont.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .fixedSize(horizontal: true, vertical: false)
            if let unit {
                Text(unit)
                    .font(unitFont.weight(.semibold))
                    .foregroundStyle(theme.identityColor)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var accessibilityDescription: String {
        if state == .loading {
            return "\(theme.title), načítavam. Zdroj: \(source)"
        }
        guard let value else {
            return "\(theme.title), \(unavailableText). Zdroj: \(source)"
        }
        let measuredValue = "\(value) \(unit ?? "")"
        guard let status else {
            return "\(theme.title), \(measuredValue). Zdroj: \(source)"
        }
        let context = status.context.map { ", \($0)" } ?? ""
        return "\(theme.title), \(measuredValue), \(status.text)\(context). Zdroj: \(source)"
    }
}

struct MetricStatusCapsule: View {
    let status: MetricStatusPresentation

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Circle()
                .fill(status.color)
                .frame(width: 7, height: 7)
                .shadow(color: status.color.opacity(0.55), radius: 4)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 1) {
                Text(status.text)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.90))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let context = status.context {
                    Text(context)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            status.color.opacity(0.11),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(status.color.opacity(0.30), lineWidth: 0.7)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MetricDetailPanel<Content: View>: View {
    let theme: MetricVisualTheme
    let title: String
    let eyebrow: String?
    @ViewBuilder let content: () -> Content

    init(
        theme: MetricVisualTheme,
        title: String,
        eyebrow: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.theme = theme
        self.title = title
        self.eyebrow = eyebrow
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(theme.identityColor)
            }
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.dashboardSurface.opacity(0.80))
                LinearGradient(
                    colors: [theme.identityColor.opacity(0.10), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.identityColor.opacity(0.22), lineWidth: 0.7)
        }
    }
}

struct MetricValueRow: View {
    let value: String?
    let unit: String
    let status: MetricStatusPresentation?
    let unavailableText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let value {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                    Text(unit)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }
                if let status {
                    MetricStatusCapsule(status: status)
                }
            } else {
                Text(unavailableText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
    }
}

struct MetricLineChart: View {
    enum Variant {
        case primary
        case secondary
    }

    let points: [(Date, Double)]
    let theme: MetricVisualTheme
    var variant: Variant = .primary
    var unavailableText = "Trend zatiaľ nie je dostupný."

    var body: some View {
        if points.count >= 2 {
            Chart(points, id: \.0) { point in
                LineMark(
                    x: .value("Deň", point.0),
                    y: .value("Hodnota", point.1)
                )
                .foregroundStyle(chartColor)
                .lineStyle(lineStyle)

                PointMark(
                    x: .value("Deň", point.0),
                    y: .value("Hodnota", point.1)
                )
                .foregroundStyle(chartColor)
                .symbolSize(variant == .primary ? 20 : 14)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartPlotStyle { plot in
                plot
                    .background(chartColor.opacity(0.045))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .frame(height: 84)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Trend za posledných \(points.count) platných dní")
        } else {
            MetricNeutralPanel(
                symbol: "chart.xyaxis.line",
                text: unavailableText
            )
        }
    }

    private var chartColor: Color {
        switch variant {
        case .primary: theme.identityColor
        case .secondary: theme.secondaryColor
        }
    }

    private var lineStyle: StrokeStyle {
        switch variant {
        case .primary:
            StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        case .secondary:
            StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round, dash: [4, 3])
        }
    }
}

struct MetricNeutralPanel: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.44))
                .frame(width: 20)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.7)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MetricQuietFooter: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.52))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 13))
    }
}
