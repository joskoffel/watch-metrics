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
                                title: "SPÁNOK",
                                accessibilityTitle: "Spánok",
                                symbol: "bed.double.fill",
                                value: store.snapshot.sleep.map {
                                    compactSleepValue($0.asleepDuration)
                                },
                                unit: store.snapshot.sleep == nil ? nil : "h",
                                status: "hlavný spánok",
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
                                accessibilityTitle: "Nočná HRV, SDNN",
                                symbol: "waveform.path.ecg",
                                value: store.snapshot.hrv.map {
                                    "\(Int($0.value.rounded()))"
                                },
                                unit: store.snapshot.hrv == nil ? nil : "ms",
                                status: store.snapshot.hrv.map {
                                    hrvLevel($0.level)
                                } ?? "osobná baseline",
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
                                title: "POKOJ. PULZ",
                                accessibilityTitle: "Pokojový pulz",
                                symbol: "heart.fill",
                                value: store.snapshot.rhr.map {
                                    "\(Int($0.value.rounded()))"
                                },
                                unit: store.snapshot.rhr == nil ? nil : "bpm",
                                status: store.snapshot.rhr.map {
                                    rhrLevel($0.level)
                                } ?? "osobná baseline",
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
                                accessibilityTitle: "Okysličenie krvi",
                                symbol: "lungs.fill",
                                value: store.snapshot.spo2.map {
                                    "\(Int($0.value.rounded()))"
                                },
                                unit: store.snapshot.spo2 == nil ? nil : "%",
                                status: store.snapshot.spo2.map {
                                    spo2Level($0.level)
                                } ?? "počas spánku",
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
                                    title: "História",
                                    symbol: "calendar"
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                SettingsView(store: store)
                            } label: {
                                DashboardSecondaryNavigationLabel(
                                    title: "Nastavenia",
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
        .navigationTitle(showsPrimaryNavigation ? "Dnes" : dayTitle(store.referenceDate))
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
        .navigationTitle("14 nocí")
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
            source: "Apple Health · hlavný spánok",
            status: store.snapshot.sleep == nil
                ? nil
                : MetricStatusPresentation(
                    text: "Hlavný spánok",
                    context: "čas spánku",
                    color: AppTheme.statusNormal
                ),
            state: store.sleepState,
            unavailableText: detailUnavailableText(store.sleepState)
        ) {
            MetricDetailPanel(
                theme: .sleep,
                title: "Čo hodnota znamená",
                eyebrow: "Kontext"
            ) {
                Text("Čas skutočne strávený v spánkových fázach. Nezahŕňa bdenie ani čas iba v posteli.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            MetricDetailPanel(
                theme: .sleep,
                title: "Historický trend",
                eyebrow: "7 nocí"
            ) {
                MetricNeutralPanel(
                    symbol: "moon.stars",
                    text: "Trend bude dostupný po zapojení historickej sleep pipeline."
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
            source: "Apple Health · nočný SDNN",
            status: store.snapshot.hrv.map(hrvStatusPresentation),
            state: store.hrvState,
            unavailableText: hrvUnavailableText(store.hrvState)
        ) {
            MetricDetailPanel(
                theme: .hrv,
                title: hrvAgreementText(store.hrvAgreement),
                eyebrow: "Zhoda signálov"
            ) {
                MetricStatusCapsule(status: hrvAgreementPresentation(store.hrvAgreement))
            }

            MetricDetailPanel(
                theme: .hrv,
                title: "SDNN",
                eyebrow: "Autoritatívny signál · Apple Health"
            ) {
                MetricValueRow(
                    value: store.snapshot.hrv.map { "\(Int($0.value.rounded()))" },
                    unit: "ms",
                    status: store.snapshot.hrv.map(hrvStatusPresentation),
                    unavailableText: hrvUnavailableText(store.hrvState)
                )
                Text("Nočný medián SDNN porovnávame s vašou osobnou 7/28-dňovou baseline.")
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
                eyebrow: "Doplnkový signál · RR intervaly"
            ) {
                MetricValueRow(
                    value: store.rmssdValue.map { "\(Int($0.rounded()))" },
                    unit: "ms",
                    status: store.rmssdStatus.map(hrvStatusPresentation),
                    unavailableText: rmssdUnavailableText(store.rmssdState)
                )
                Text("RMSSD počítame zo samostatných heartbeat sérií počas hlavného spánku; hranice sérií nikdy nespájame.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
                MetricLineChart(
                    points: store.rmssdHistory.map { ($0.date, $0.value) },
                    theme: .hrv,
                    variant: .secondary,
                    unavailableText: "Nedostatok RMSSD dát"
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
            source: "Apple Health · denná hodnota",
            status: store.snapshot.rhr.map(rhrStatusPresentation),
            state: store.rhrState,
            unavailableText: baselineUnavailableText(store.rhrState)
        ) {
            MetricDetailPanel(
                theme: .restingHeartRate,
                title: "Osobný kontext",
                eyebrow: "7/28-dňová baseline"
            ) {
                Text("Pokojový pulz je denná hodnota zo Zdravia porovnaná s vašou osobnou baseline.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            MetricDetailPanel(
                theme: .restingHeartRate,
                title: "Posledné platné dni",
                eyebrow: "Trend"
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
            source: "Apple Health · počas hlavného spánku",
            status: store.snapshot.spo2.map(spo2StatusPresentation),
            state: store.spo2State,
            unavailableText: detailUnavailableText(store.spo2State)
        ) {
            MetricDetailPanel(
                theme: .oxygenSaturation,
                title: "Nočný kontext",
                eyebrow: "Okysličenie krvi"
            ) {
                Text("Odhad nasýtenia krvi kyslíkom zo zápästia. Nízky stav ostáva viditeľný bez ohľadu na množstvo histórie.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            MetricDetailPanel(
                theme: .oxygenSaturation,
                title: "Posledné platné noci",
                eyebrow: "Trend"
            ) {
                MetricLineChart(
                    points: store.spo2History.map { ($0.date, $0.value.value) },
                    theme: .oxygenSaturation
                )
            }

            MetricQuietFooter(
                symbol: "info.circle",
                text: "Watch Metrics nie je zdravotnícka pomôcka."
            )
        }
    }
}

struct SettingsView: View {
    let store: DailyOverviewStore
    @State private var weatherStatus = WeatherBriefService.shared.lastStatus
    @State private var weatherSymbolName = WeatherBriefService.shared.lastSymbolName

    var body: some View {
        List {
            Section("Ranný brief") {
                LabeledContent("Stav", value: store.morningBriefText)
                LabeledContent("Notifikácie", value: store.notificationAccess.rawValue)
                Button("Odoslať bezpečný test") {
                    Task { await store.sendSafeTestNotification() }
                }
                if let message = store.notificationTestMessage {
                    Text(message).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Section("Zdravie") {
                Text(store.healthKitAccessText)
                    .font(.caption)
            }
            Section("Počasie") {
                LabeledContent("Poloha", value: WeatherLocationProvider.shared.managerAuthorizationText)
                LabeledContent("Cache polohy", value: WeatherLocationProvider.shared.cachedLocationAgeText())
                Label(weatherStatus, systemImage: weatherSymbolName)
                    .font(.caption2)
                Text("Weather by Apple")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Section("O aplikácii") {
                LabeledContent("Watch Metrics", value: "1.0")
                Text("Denný prehľad údajov zo Zdravia. Nie je zdravotníckou pomôckou.")
                    .font(.caption2)
            }
            NavigationLink {
                DeveloperMenuView()
            } label: {
                Label("Developer", systemImage: "hammer.fill")
            }
        }
        .navigationTitle("Nastavenia")
        .task {
            WeatherLocationProvider.shared.requestForegroundAuthorizationIfNeeded()
            await store.refreshNotificationAccess()
            _ = await WeatherBriefService.shared.currentSummary()
            weatherStatus = WeatherBriefService.shared.lastStatus
            weatherSymbolName = WeatherBriefService.shared.lastSymbolName
        }
    }
}

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
    case .low: "nízka"
    case .medium: "stredná"
    case .high: "vysoká"
    }
}

func hrvLevel(_ level: HRVStatusLevel) -> String {
    switch level {
    case .low: "nižšie než zvyčajne"
    case .normal: "v osobnom pásme"
    case .high: "vyššie než zvyčajne"
    }
}

func hrvAgreementText(_ insight: HRVAgreementInsight) -> String {
    switch insight {
    case .bothLower: "Oba signály nižšie než osobná baseline"
    case .bothTypicalOrHigher: "Oba signály v osobnom pásme alebo vyššie"
    case .mixed: "Zmiešané HRV signály"
    case .insufficientRMSSD: "Nedostatok RMSSD dát"
    }
}

func rhrLevel(_ level: RHRStatusLevel) -> String {
    switch level {
    case .suppressed: "nižší než zvyčajne"
    case .normal: "v osobnom pásme"
    case .elevated: "zvýšený"
    }
}

func spo2Level(_ level: SpO2StatusLevel) -> String {
    switch level {
    case .normal: "V bežnom rozsahu"
    case .low: "Nízka hodnota"
    case .critical: "Kriticky nízka hodnota"
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
        context: "\(confidenceText(status.confidence)) istota",
        color: hrvStatusColor(status.level)
    )
}

func hrvStatusPresentation(_ status: RMSSDStatus) -> MetricStatusPresentation {
    MetricStatusPresentation(
        text: hrvLevel(status.level),
        context: "\(confidenceText(status.confidence)) istota",
        color: hrvStatusColor(status.level)
    )
}

func rhrStatusPresentation(_ status: RHRStatus) -> MetricStatusPresentation {
    MetricStatusPresentation(
        text: rhrLevel(status.level),
        context: "\(confidenceText(status.confidence)) istota",
        color: rhrStatusColor(status.level)
    )
}

func spo2StatusPresentation(_ status: SpO2Status) -> MetricStatusPresentation {
    MetricStatusPresentation(
        text: spo2Level(status.level),
        context: "\(confidenceText(status.confidence)) kontext",
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
    state == .loading ? "Načítavam…" : stateMessage(state)
}

func baselineUnavailableText(_ state: DataLoadState) -> String {
    switch state {
    case .loaded, .empty:
        "Nedostatok dát pre osobnú baseline"
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
        "Načítavam RMSSD…"
    case .permissionDenied:
        stateMessage(state)
    default:
        "Nedostatok RMSSD dát"
    }
}

func stateMessage(_ state: DataLoadState) -> String {
    switch state {
    case .idle: "Dáta ešte neboli načítané"
    case .loading: "Načítavam…"
    case .loaded: "Dáta sú dostupné"
    case .empty: "Pre tento deň nie sú dáta"
    case .permissionDenied: "Skontrolujte prístup v aplikácii Zdravie"
    case .failed(let message): "Načítanie zlyhalo: \(message)"
    }
}

func dayTitle(_ date: Date) -> String {
    date.formatted(.dateTime.day().month())
}
