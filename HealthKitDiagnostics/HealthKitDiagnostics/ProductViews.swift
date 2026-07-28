import Charts
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

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.spacing) {
                header
                NavigationLink {
                    SleepDetailView(store: store)
                } label: {
                    metricCard(
                        title: "Spánok",
                        symbol: "bed.double.fill",
                        value: store.snapshot.sleep.map { durationText($0.asleepDuration) },
                        subtitle: "Skutočný čas spánku",
                        color: AppTheme.accent,
                        state: store.sleepState
                    )
                }
                .buttonStyle(.plain)

                if let recovery = store.snapshot.recovery {
                    recoveryCard(recovery)
                }

                NavigationLink {
                    HRVDetailView(store: store)
                } label: {
                    metricCard(
                        title: "Nočná HRV",
                        symbol: "waveform.path.ecg",
                        value: store.snapshot.hrv.map { "\(Int($0.value.rounded())) ms" },
                        subtitle: store.snapshot.hrv.map {
                            "SDNN · \(hrvLevel($0.level))"
                        } ?? "Variabilita srdcového rytmu",
                        color: store.snapshot.hrv.map { hrvColor($0.level) } ?? AppTheme.accent,
                        state: store.hrvState
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    RHRDetailView(store: store)
                } label: {
                    metricCard(
                        title: "Pokojový pulz",
                        symbol: "heart.fill",
                        value: store.snapshot.rhr.map { "\(Int($0.value.rounded())) bpm" },
                        subtitle: store.snapshot.rhr.map {
                            "\(rhrLevel($0.level)) · \(confidenceText($0.confidence)) istota"
                        } ?? "Pulz v pokoji voči baseline",
                        color: store.snapshot.rhr.map { rhrColor($0.level) } ?? AppTheme.accent,
                        state: store.rhrState
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    SpO2DetailView(store: store)
                } label: {
                    metricCard(
                        title: "Okysličenie",
                        symbol: "lungs.fill",
                        value: store.snapshot.spo2.map { "\(Int($0.value.rounded())) %" },
                        subtitle: store.snapshot.spo2.map { spo2Level($0.level) } ?? "SpO₂ počas hlavného spánku",
                        color: store.snapshot.spo2.map { spo2Color($0.level) } ?? AppTheme.accent,
                        state: store.spo2State
                    )
                }
                .buttonStyle(.plain)

                statusCard

                if showsPrimaryNavigation {
                    NavigationLink {
                        HistoryView(store: store)
                    } label: {
                        Label("História", systemImage: "calendar")
                    }
                    NavigationLink {
                        SettingsView(store: store)
                    } label: {
                        Label("Nastavenia", systemImage: "gearshape")
                    }
                }
            }
            .padding(.horizontal, 6)
        }
        .containerBackground(AppTheme.background.gradient, for: .navigation)
        .navigationTitle(showsPrimaryNavigation ? "Dnes" : dayTitle(store.referenceDate))
        .task(id: store.referenceDate) {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(store.referenceDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.headline)
            Label(store.dataStatusText, systemImage: dataStatusSymbol)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dataStatusSymbol: String {
        if store.isLoading { return "arrow.triangle.2.circlepath" }
        return store.snapshot.availableSectionCount == 0 ? "exclamationmark.circle" : "checkmark.circle"
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Ranný brief", systemImage: "sunrise.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            Text(store.morningBriefText)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .cardStyle()
    }

    private func metricCard(
        title: String,
        symbol: String,
        value: String?,
        subtitle: String,
        color: Color,
        state: DataLoadState
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if state == .loading {
                PulsingSkeleton()
                    .frame(height: 34)
            } else if let value {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Circle().fill(color).frame(width: 9, height: 9)
                    Text(value).font(.title3.weight(.semibold))
                }
                Text(subtitle).font(.caption2).foregroundStyle(AppTheme.secondaryText)
            } else {
                Text(stateMessage(state))
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .cardStyle()
    }

    private func recoveryCard(_ signal: RecoverySignal) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("Regenerácia", systemImage: "heart.text.square.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle().fill(recoveryColor(signal.level)).frame(width: 9, height: 9)
                Text(signal.briefText).font(.title3.weight(.semibold))
            }
            Text("Interpretácia HRV a pokojového pulzu voči vašej histórii")
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .cardStyle()
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
        MetricDetailContainer(
            title: "Spánok",
            symbol: "bed.double.fill",
            value: store.snapshot.sleep.map { durationText($0.asleepDuration) },
            status: store.snapshot.sleep == nil ? nil : "Hlavný spánok",
            explanation: "Čas skutočne strávený v spánkových fázach. Nezahŕňa bdenie ani čas iba v posteli.",
            state: store.sleepState
        ) {
            Text("Sedemdňový trend sa zobrazí, keď bude dostupná historická sleep pipeline.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct HRVDetailView: View {
    let store: DailyOverviewStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacing) {
                Label("Nočná HRV", systemImage: "waveform.path.ecg")
                    .foregroundStyle(AppTheme.accent)

                StatusBadge(text: hrvAgreementText(store.hrvAgreement))

                hrvMetricSection(
                    title: "SDNN · Apple Health",
                    value: store.snapshot.hrv.map { "\(Int($0.value.rounded())) ms" },
                    status: store.snapshot.hrv.map {
                        "\(hrvLevel($0.level)) · \(confidenceText($0.confidence)) istota"
                    },
                    state: store.hrvState,
                    explanation: "Nočný medián SDNN porovnávame s vašou osobnou 7/28-dňovou baseline."
                ) {
                    MetricLineChart(
                        points: store.hrvHistory.map { ($0.date, $0.value.value) },
                        color: AppTheme.accent
                    )
                }

                hrvMetricSection(
                    title: "RMSSD · z RR intervalov",
                    value: store.rmssdValue.map { "\(Int($0.rounded())) ms" },
                    status: store.rmssdStatus.map {
                        "\(hrvLevel($0.level)) · \(confidenceText($0.confidence)) istota"
                    },
                    state: store.rmssdState,
                    explanation: "RMSSD počítame zo samostatných heartbeat sérií počas hlavného spánku; hranice sérií nikdy nespájame."
                ) {
                    if store.rmssdValue != nil {
                        MetricLineChart(
                            points: store.rmssdHistory.map { ($0.date, $0.value) },
                            color: .cyan
                        )
                    } else if store.rmssdState != .loading {
                        Text("Nedostatok RMSSD dát")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("Nočná HRV")
        .containerBackground(AppTheme.background.gradient, for: .navigation)
    }

    private func hrvMetricSection<Content: View>(
        title: String,
        value: String?,
        status: String?,
        state: DataLoadState,
        explanation: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
            if state == .loading {
                PulsingSkeleton()
            } else if let value {
                Text(value).font(.title2.weight(.bold))
                if let status {
                    StatusBadge(text: status)
                } else {
                    StatusBadge(text: "Nedostatok dát pre osobnú baseline")
                }
            } else {
                Text(title.hasPrefix("RMSSD") ? "Nedostatok RMSSD dát" : stateMessage(state))
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Text(explanation)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
            content()
        }
        .cardStyle()
    }
}

struct RHRDetailView: View {
    let store: DailyOverviewStore

    var body: some View {
        MetricDetailContainer(
            title: "Pokojový pulz",
            symbol: "heart.fill",
            value: store.snapshot.rhr.map { "\(Int($0.value.rounded())) bpm" },
            status: store.snapshot.rhr.map { "\(rhrLevel($0.level)) · \(confidenceText($0.confidence)) istota" },
            explanation: "Pokojový pulz je denná hodnota zo Zdravia porovnaná s vašou osobnou baseline.",
            state: store.rhrState
        ) {
            MetricLineChart(points: store.rhrHistory.map { ($0.date, $0.value.value) }, color: .pink)
        }
    }
}

struct SpO2DetailView: View {
    let store: DailyOverviewStore

    var body: some View {
        MetricDetailContainer(
            title: "SpO₂",
            symbol: "lungs.fill",
            value: store.snapshot.spo2.map { "\(Int($0.value.rounded())) %" },
            status: store.snapshot.spo2.map { "\(spo2Level($0.level)) · \(confidenceText($0.confidence)) kontext" },
            explanation: "Odhad nasýtenia krvi kyslíkom zo zápästia. Nízky stav ostáva viditeľný bez ohľadu na množstvo histórie.",
            state: store.spo2State
        ) {
            MetricLineChart(points: store.spo2History.map { ($0.date, $0.value.value) }, color: .cyan)
            Text("Watch Metrics nie je zdravotnícka pomôcka.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct MetricDetailContainer<Content: View>: View {
    let title: String
    let symbol: String
    let value: String?
    let status: String?
    let explanation: String
    let state: DataLoadState
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacing) {
                Label(title, systemImage: symbol)
                    .foregroundStyle(AppTheme.accent)
                if state == .loading {
                    PulsingSkeleton()
                } else if let value {
                    Text(value).font(.largeTitle.weight(.bold))
                    if let status {
                        StatusBadge(text: status)
                    }
                } else {
                    DataStateView(state: state)
                }
                Text(explanation).font(.caption).foregroundStyle(AppTheme.secondaryText)
                content()
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle(title)
        .containerBackground(AppTheme.background.gradient, for: .navigation)
    }
}

struct MetricLineChart: View {
    let points: [(Date, Double)]
    let color: Color

    var body: some View {
        if points.count >= 2 {
            Chart(points, id: \.0) { point in
                LineMark(x: .value("Deň", point.0), y: .value("Hodnota", point.1))
                PointMark(x: .value("Deň", point.0), y: .value("Hodnota", point.1))
            }
            .foregroundStyle(color)
            .chartXAxis(.hidden)
            .frame(height: 80)
            .accessibilityLabel("Trend za posledných \(points.count) dní")
        } else {
            Text("Trend zatiaľ nie je dostupný.")
                .font(.caption2).foregroundStyle(.secondary)
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

struct StatusBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.elevatedBackground, in: Capsule())
    }
}

struct DataStateView: View {
    let state: DataLoadState

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: state == .permissionDenied ? "lock.fill" : "waveform.slash")
            Text(stateMessage(state)).font(.caption).multilineTextAlignment(.center)
        }
        .foregroundStyle(AppTheme.secondaryText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
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

func durationText(_ duration: TimeInterval) -> String {
    let minutes = Int(duration / 60)
    return "\(minutes / 60) h \(minutes % 60) min"
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

func recoveryColor(_ level: RecoverySignalLevel) -> Color {
    switch level {
    case .strained: AppTheme.statusLow
    case .mixed: AppTheme.accent
    case .typical, .favorable: AppTheme.statusNormal
    }
}

func spo2Color(_ level: SpO2StatusLevel) -> Color {
    switch level {
    case .normal: AppTheme.statusNormal
    case .low: AppTheme.statusLow
    case .critical: AppTheme.statusCritical
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
