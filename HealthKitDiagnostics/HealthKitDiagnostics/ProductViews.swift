import MetricsCore
import SwiftUI

struct WatchMetricsRootView: View {
    @State private var store = DailyOverviewStore()

    var body: some View {
        NavigationStack {
            TodayView(store: store, showsPrimaryNavigation: true)
        }
        .tint(AppTheme.accent)
        .background(AppTheme.background)
    }
}

struct TodayView: View {
    let store: DailyOverviewStore
    let showsPrimaryNavigation: Bool

    private let metricColumns = [
        GridItem(.flexible(minimum: 64), spacing: 7),
        GridItem(.flexible(minimum: 64), spacing: 7)
    ]

    var body: some View {
        ZStack {
            DashboardBackground()
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 11) {
                    DashboardHeader(
                        date: store.referenceDate,
                        dataStatusText: store.dataStatusText,
                        dataStatusSymbol: dataStatusSymbol
                    )

                    RecoveryHero(
                        signal: store.snapshot.recovery,
                        animates: showsPrimaryNavigation
                    )

                    LazyVGrid(columns: metricColumns, spacing: 7) {
                        NavigationLink {
                            SleepDetailView(store: store)
                        } label: {
                            DashboardMetricTile(
                                title: String(localized: "SLEEP"),
                                accessibilityTitle: String(localized: "Sleep"),
                                symbol: "bed.double.fill",
                                value: store.snapshot.sleep.map {
                                    compactSleepValue($0.asleepDuration)
                                },
                                unit: store.snapshot.sleep == nil ? nil : "h",
                                status: String(localized: "main sleep"),
                                statusColor: nil,
                                tint: AppTheme.dashboardViolet,
                                state: store.sleepState
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            HRVDetailView(store: store)
                        } label: {
                            DashboardMetricTile(
                                title: "HRV · SDNN",
                                accessibilityTitle: String(localized: "Nightly HRV, SDNN"),
                                symbol: "waveform.path.ecg",
                                value: store.snapshot.hrv.map {
                                    "\(Int($0.value.rounded()))"
                                },
                                unit: store.snapshot.hrv == nil ? nil : "ms",
                                status: store.snapshot.hrv.map {
                                    hrvLevel($0.level)
                                } ?? String(localized: "personal baseline"),
                                statusColor: store.snapshot.hrv.map {
                                    hrvStatusColor($0.level)
                                },
                                tint: AppTheme.dashboardCyan,
                                state: store.hrvState
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            RHRDetailView(store: store)
                        } label: {
                            DashboardMetricTile(
                                title: String(localized: "RESTING HR"),
                                accessibilityTitle: String(localized: "Resting heart rate"),
                                symbol: "heart.fill",
                                value: store.snapshot.rhr.map {
                                    "\(Int($0.value.rounded()))"
                                },
                                unit: store.snapshot.rhr == nil ? nil : "bpm",
                                status: store.snapshot.rhr.map {
                                    rhrLevel($0.level)
                                } ?? String(localized: "personal baseline"),
                                statusColor: store.snapshot.rhr.map {
                                    rhrStatusColor($0.level)
                                },
                                tint: AppTheme.dashboardMagenta,
                                state: store.rhrState
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            SpO2DetailView(store: store)
                        } label: {
                            DashboardMetricTile(
                                title: "SPO₂",
                                accessibilityTitle: String(localized: "Blood oxygen"),
                                symbol: "lungs.fill",
                                value: store.snapshot.spo2.map {
                                    "\(Int($0.value.rounded()))"
                                },
                                unit: store.snapshot.spo2 == nil ? nil : "%",
                                status: store.snapshot.spo2.map {
                                    spo2Level($0.level)
                                } ?? String(localized: "during sleep"),
                                statusColor: store.snapshot.spo2.map {
                                    spo2StatusColor($0.level)
                                },
                                tint: AppTheme.dashboardBlue,
                                state: store.spo2State
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    MorningBriefCapsule(text: store.morningBriefText)

                    if showsPrimaryNavigation {
                        HStack(spacing: 7) {
                            NavigationLink {
                                HistoryView(store: store)
                            } label: {
                                DashboardSecondaryNavigationLabel(
                                    title: String(localized: "History"),
                                    symbol: "calendar"
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                SettingsView(store: store)
                            } label: {
                                DashboardSecondaryNavigationLabel(
                                    title: String(localized: "Settings"),
                                    symbol: "gearshape"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 7)
                .padding(.bottom, 10)
            }
        }
        .containerBackground(AppTheme.dashboardBackground, for: .navigation)
        .navigationTitle(showsPrimaryNavigation ? String(localized: "Today") : dayTitle(store.referenceDate))
        .task(id: store.referenceDate) {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
    }

    private var dataStatusSymbol: String {
        if store.isLoading { return "arrow.triangle.2.circlepath" }
        return store.snapshot.availableSectionCount == 0 ? "exclamationmark.circle" : "checkmark.circle"
    }
}

struct HistoryView: View {
    let store: DailyOverviewStore

    var body: some View {
        List(store.history, id: \.referenceDate) { day in
            NavigationLink {
                HistoricalDayView(referenceDate: day.referenceDate)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(day.referenceDate.formatted(.dateTime.weekday(.abbreviated).day().month()))
                        .font(.footnote.weight(.semibold))
                    HStack(spacing: 8) {
                        historyValue("HRV", day.hrv.map { "\(Int($0.value.rounded()))" }, day.hrv.map { hrvColor($0.level) })
                        historyValue("RHR", day.rhr.map { "\(Int($0.value.rounded()))" }, day.rhr.map { rhrColor($0.level) })
                        historyValue("O₂", day.spo2.map { "\(Int($0.value.rounded()))" }, day.spo2.map { spo2Color($0.level) })
                    }
                }
            }
        }
        .navigationTitle(String(localized: "14 nights"))
    }

    private func historyValue(_ label: String, _ value: String?, _ color: Color?) -> some View {
        HStack(spacing: 2) {
            Circle().fill(color ?? Color.secondary.opacity(0.4)).frame(width: 6, height: 6)
            Text("\(label) \(value ?? "—")").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct HistoricalDayView: View {
    @State private var store: DailyOverviewStore

    init(referenceDate: Date) {
        _store = State(initialValue: DailyOverviewStore(referenceDate: referenceDate))
    }

    var body: some View {
        TodayView(store: store, showsPrimaryNavigation: false)
    }
}

struct SleepDetailView: View {
    let store: DailyOverviewStore

    var body: some View {
        MetricDetailScreen(
            theme: .sleep,
            value: store.snapshot.sleep.map { compactSleepValue($0.asleepDuration) },
            unit: store.snapshot.sleep == nil ? nil : "h",
            source: String(localized: "Apple Health · main sleep"),
            status: store.snapshot.sleep == nil
                ? nil
                : MetricStatusPresentation(
                    text: String(localized: "Main sleep"),
                    context: String(localized: "time asleep"),
                    color: AppTheme.statusNormal
                ),
            state: store.sleepState,
            unavailableText: detailUnavailableText(store.sleepState)
        ) {
            MetricDetailPanel(
                theme: .sleep,
                title: String(localized: "What this value means"),
                eyebrow: String(localized: "Context")
            ) {
                Text("Time actually spent in sleep stages. It excludes awake time and time spent only in bed.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            MetricDetailPanel(
                theme: .sleep,
                title: String(localized: "Historical trend"),
                eyebrow: String(localized: "7 nights")
            ) {
                MetricNeutralPanel(
                    symbol: "moon.stars",
                    text: String(localized: "A trend will appear when historical sleep data is available.")
                )
            }
        }
    }
}

struct HRVDetailView: View {
    let store: DailyOverviewStore

    var body: some View {
        MetricDetailScreen(
            theme: .hrv,
            value: store.snapshot.hrv.map { "\(Int($0.value.rounded()))" },
            unit: store.snapshot.hrv == nil ? nil : "ms SDNN",
            source: String(localized: "Apple Health · nightly SDNN"),
            status: store.snapshot.hrv.map(hrvStatusPresentation),
            state: store.hrvState,
            unavailableText: hrvUnavailableText(store.hrvState)
        ) {
            MetricDetailPanel(
                theme: .hrv,
                title: hrvAgreementText(store.hrvAgreement),
                eyebrow: String(localized: "Signal agreement")
            ) {
                MetricStatusCapsule(status: hrvAgreementPresentation(store.hrvAgreement))
            }

            MetricDetailPanel(
                theme: .hrv,
                title: "SDNN",
                eyebrow: String(localized: "Primary signal · Apple Health")
            ) {
                MetricValueRow(
                    value: store.snapshot.hrv.map { "\(Int($0.value.rounded()))" },
                    unit: "ms",
                    status: store.snapshot.hrv.map(hrvStatusPresentation),
                    unavailableText: hrvUnavailableText(store.hrvState)
                )
                Text("Your nightly median SDNN compared with your personal 7/28-day baseline.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
                MetricLineChart(
                    points: store.hrvHistory.map { ($0.date, $0.value.value) },
                    theme: .hrv,
                    variant: .primary
                )
            }

            MetricDetailPanel(
                theme: .hrv,
                title: "RMSSD",
                eyebrow: String(localized: "Supporting signal · RR intervals")
            ) {
                MetricValueRow(
                    value: store.rmssdValue.map { "\(Int($0.rounded()))" },
                    unit: "ms",
                    status: store.rmssdStatus.map(hrvStatusPresentation),
                    unavailableText: rmssdUnavailableText(store.rmssdState)
                )
                Text("RMSSD is calculated from separate heartbeat series during main sleep; series boundaries are never joined.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
                MetricLineChart(
                    points: store.rmssdHistory.map { ($0.date, $0.value) },
                    theme: .hrv,
                    variant: .secondary,
                    unavailableText: String(localized: "Not enough RMSSD data")
                )
            }
        }
    }
}

struct RHRDetailView: View {
    let store: DailyOverviewStore

    var body: some View {
        MetricDetailScreen(
            theme: .restingHeartRate,
            value: store.snapshot.rhr.map { "\(Int($0.value.rounded()))" },
            unit: store.snapshot.rhr == nil ? nil : "bpm",
            source: String(localized: "Apple Health · daily value"),
            status: store.snapshot.rhr.map(rhrStatusPresentation),
            state: store.rhrState,
            unavailableText: baselineUnavailableText(store.rhrState)
        ) {
            MetricDetailPanel(
                theme: .restingHeartRate,
                title: String(localized: "Personal context"),
                eyebrow: String(localized: "7/28-day baseline")
            ) {
                Text("Resting heart rate is a daily Apple Health value compared with your personal baseline.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            MetricDetailPanel(
                theme: .restingHeartRate,
                title: String(localized: "Recent valid days"),
                eyebrow: String(localized: "Trend")
            ) {
                MetricLineChart(
                    points: store.rhrHistory.map { ($0.date, $0.value.value) },
                    theme: .restingHeartRate
                )
            }
        }
    }
}

struct SpO2DetailView: View {
    let store: DailyOverviewStore

    var body: some View {
        MetricDetailScreen(
            theme: .oxygenSaturation,
            value: store.snapshot.spo2.map { "\(Int($0.value.rounded()))" },
            unit: store.snapshot.spo2 == nil ? nil : "%",
            source: String(localized: "Apple Health · during main sleep"),
            status: store.snapshot.spo2.map(spo2StatusPresentation),
            state: store.spo2State,
            unavailableText: detailUnavailableText(store.spo2State)
        ) {
            MetricDetailPanel(
                theme: .oxygenSaturation,
                title: String(localized: "Nightly context"),
                eyebrow: String(localized: "Blood oxygen")
            ) {
                Text("An estimate of blood oxygen saturation from your wrist. Low readings remain visible regardless of available history.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            MetricDetailPanel(
                theme: .oxygenSaturation,
                title: String(localized: "Recent valid nights"),
                eyebrow: String(localized: "Trend")
            ) {
                MetricLineChart(
                    points: store.spo2History.map { ($0.date, $0.value.value) },
                    theme: .oxygenSaturation
                )
            }

            MetricQuietFooter(
                symbol: "info.circle",
                text: String(localized: "Watch Metrics is not a medical device.")
            )
        }
    }
}

struct SettingsView: View {
    let store: DailyOverviewStore

    var body: some View {
        List {
            Section("Morning brief") {
                LabeledContent("Status", value: store.morningBriefText)
                LabeledContent("Notifications", value: store.notificationAccess.localizedText)
                #if DEBUG
                Button("Odoslať bezpečný test") {
                    Task { await store.sendSafeTestNotification() }
                }
                if let message = store.notificationTestMessage {
                    Text(message).font(.caption2).foregroundStyle(.secondary)
                }
                #endif
            }
            Section("Health") {
                Text(store.healthKitAccessText)
                    .font(.caption)
            }
            Section("About") {
                LabeledContent("Watch Metrics", value: "1.0")
                Text("A daily overview of Apple Health data. Not a medical device.")
                    .font(.caption2)
            }
            #if DEBUG
                NavigationLink {
                    DeveloperMenuView()
                } label: {
                    Label("Developer", systemImage: "hammer.fill")
                }
            #endif
        }
        .navigationTitle("Settings")
        .task {
            await store.refreshNotificationAccess()
        }
    }
}

#if DEBUG
struct DeveloperMenuView: View {
    var body: some View {
        List {
            NavigationLink("HRV Data Audit") { HRVDataAuditView() }
            NavigationLink("HealthKit diagnostika") { DiagnosticsView() }
            NavigationLink("Ranný brief debug") { BriefDebugPanel() }
        }
        .navigationTitle("Developer")
    }
}
#endif

extension View {
    func cardStyle() -> some View {
        self
            .padding(AppTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppTheme.cardBackground,
                in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }
}

func confidenceText(_ confidence: ConfidenceLevel) -> String {
    switch confidence {
    case .low: String(localized: "low")
    case .medium: String(localized: "medium")
    case .high: String(localized: "high")
    }
}

func hrvLevel(_ level: HRVStatusLevel) -> String {
    switch level {
    case .low: String(localized: "lower than usual")
    case .normal: String(localized: "within personal range")
    case .high: String(localized: "higher than usual")
    }
}

func hrvAgreementText(_ insight: HRVAgreementInsight) -> String {
    switch insight {
    case .bothLower: String(localized: "Both signals are below personal baseline")
    case .bothTypicalOrHigher: String(localized: "Both signals are within personal range or higher")
    case .mixed: String(localized: "Mixed HRV signals")
    case .insufficientRMSSD: String(localized: "Not enough RMSSD data")
    }
}

func rhrLevel(_ level: RHRStatusLevel) -> String {
    switch level {
    case .suppressed: String(localized: "lower than usual")
    case .normal: String(localized: "within personal range")
    case .elevated: String(localized: "elevated")
    }
}

func spo2Level(_ level: SpO2StatusLevel) -> String {
    switch level {
    case .normal: String(localized: "Within normal range")
    case .low: String(localized: "Low reading")
    case .critical: String(localized: "Critically low reading")
    }
}

func hrvColor(_ level: HRVStatusLevel) -> Color {
    level == .normal ? AppTheme.statusNormal : AppTheme.statusLow
}

func rhrColor(_ level: RHRStatusLevel) -> Color {
    switch level {
    case .normal, .suppressed: AppTheme.statusNormal
    case .elevated: AppTheme.statusLow
    }
}

func spo2Color(_ level: SpO2StatusLevel) -> Color {
    switch level {
    case .normal: AppTheme.statusNormal
    case .low: AppTheme.statusLow
    case .critical: AppTheme.statusCritical
    }
}

func hrvStatusColor(_ level: HRVStatusLevel) -> Color {
    switch level {
    case .low: AppTheme.statusLow
    case .normal, .high: AppTheme.statusNormal
    }
}

func rhrStatusColor(_ level: RHRStatusLevel) -> Color {
    switch level {
    case .suppressed, .normal: AppTheme.statusNormal
    case .elevated: AppTheme.statusLow
    }
}

func spo2StatusColor(_ level: SpO2StatusLevel) -> Color {
    switch level {
    case .normal: AppTheme.statusNormal
    case .low: AppTheme.statusLow
    case .critical: AppTheme.statusCritical
    }
}

func hrvStatusPresentation(_ status: HRVStatus) -> MetricStatusPresentation {
    MetricStatusPresentation(
        text: hrvLevel(status.level),
        context: localizedConfidence(status.confidence),
        color: hrvStatusColor(status.level)
    )
}

func hrvStatusPresentation(_ status: RMSSDStatus) -> MetricStatusPresentation {
    MetricStatusPresentation(
        text: hrvLevel(status.level),
        context: localizedConfidence(status.confidence),
        color: hrvStatusColor(status.level)
    )
}

func rhrStatusPresentation(_ status: RHRStatus) -> MetricStatusPresentation {
    MetricStatusPresentation(
        text: rhrLevel(status.level),
        context: localizedConfidence(status.confidence),
        color: rhrStatusColor(status.level)
    )
}

func spo2StatusPresentation(_ status: SpO2Status) -> MetricStatusPresentation {
    MetricStatusPresentation(
        text: spo2Level(status.level),
        context: localizedContext(status.confidence),
        color: spo2StatusColor(status.level)
    )
}

func hrvAgreementPresentation(_ insight: HRVAgreementInsight) -> MetricStatusPresentation {
    switch insight {
    case .bothLower:
        MetricStatusPresentation(
            text: hrvAgreementText(insight),
            context: nil,
            color: AppTheme.statusLow
        )
    case .bothTypicalOrHigher:
        MetricStatusPresentation(
            text: hrvAgreementText(insight),
            context: nil,
            color: AppTheme.statusNormal
        )
    case .mixed:
        MetricStatusPresentation(
            text: hrvAgreementText(insight),
            context: nil,
            color: AppTheme.dashboardAmber
        )
    case .insufficientRMSSD:
        .neutral(hrvAgreementText(insight))
    }
}

func detailUnavailableText(_ state: DataLoadState) -> String {
    state == .loading ? String(localized: "Loading…") : stateMessage(state)
}

func baselineUnavailableText(_ state: DataLoadState) -> String {
    switch state {
    case .loaded, .empty:
        String(localized: "Not enough data for a personal baseline")
    default:
        detailUnavailableText(state)
    }
}

func hrvUnavailableText(_ state: DataLoadState) -> String {
    baselineUnavailableText(state)
}

func rmssdUnavailableText(_ state: DataLoadState) -> String {
    switch state {
    case .loading:
        String(localized: "Loading RMSSD…")
    case .permissionDenied:
        stateMessage(state)
    default:
        String(localized: "Not enough RMSSD data")
    }
}

func stateMessage(_ state: DataLoadState) -> String {
    switch state {
    case .idle: String(localized: "Data has not been loaded yet")
    case .loading: String(localized: "Loading…")
    case .loaded: String(localized: "Data available")
    case .empty: String(localized: "No data for this day")
    case .permissionDenied: String(localized: "Check access in the Health app")
    case .failed: String(localized: "Unable to load data")
    }
}

private func localizedConfidence(_ confidence: ConfidenceLevel) -> String {
    String.localizedStringWithFormat(
        String(localized: "%@ confidence"),
        confidenceText(confidence)
    )
}

private func localizedContext(_ confidence: ConfidenceLevel) -> String {
    String.localizedStringWithFormat(
        String(localized: "%@ context"),
        confidenceText(confidence)
    )
}

func dayTitle(_ date: Date) -> String {
    date.formatted(.dateTime.day().month())
}
