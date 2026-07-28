import MetricsCore
import SwiftUI

#if DEBUG
@MainActor
enum PreviewData {
    static let now = Date(timeIntervalSince1970: 1_767_268_800)
    static let sleep = SleepSession(
        start: now.addingTimeInterval(-8.1 * 3600),
        end: now.addingTimeInterval(-1.2 * 3600),
        asleepDuration: 6.55 * 3600
    )

    static let snapshot = snapshot(for: .typical)

    static var history: [DailyDashboardSnapshot] {
        (0..<14).map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: now) ?? now
            return DailyDashboardSnapshot(
                referenceDate: date,
                hrv: HRVStatus(value: 47 + Double(offset % 6), level: offset == 3 ? .low : .normal, confidence: .medium),
                rhr: RHRStatus(value: 56 + Double(offset % 4), level: offset == 4 ? .elevated : .normal, confidence: .medium),
                spo2: SpO2Status(value: offset == 2 ? 93 : 96, level: offset == 2 ? .low : .normal, confidence: .low)
            )
        }
    }

    static var store: DailyOverviewStore {
        store(for: .typical)
    }

    static func store(for level: RecoverySignalLevel) -> DailyOverviewStore {
        let selected = snapshot(for: level)
        return DailyOverviewStore(
            sample: selected,
            history: history,
            hrvHistory: history.compactMap { day in day.hrv.map { DatedMetric(date: day.referenceDate, value: $0) } },
            rmssdHistory: history.enumerated().map {
                DatedMetric(date: $0.element.referenceDate, value: 46 + Double($0.offset % 5))
            },
            rmssdValue: 49,
            rmssdStatus: RMSSDStatus(value: 49, level: .normal, confidence: .medium),
            rhrHistory: history.compactMap { day in day.rhr.map { DatedMetric(date: day.referenceDate, value: $0) } },
            spo2History: history.compactMap { day in day.spo2.map { DatedMetric(date: day.referenceDate, value: $0) } }
        )
    }

    static var partialStore: DailyOverviewStore {
        DailyOverviewStore(
            sample: DailyDashboardSnapshot(
                referenceDate: now,
                sleep: sleep,
                hrv: HRVStatus(value: 51, level: .normal, confidence: .low)
            ),
            states: .empty
        )
    }

    static var loadingStore: DailyOverviewStore {
        DailyOverviewStore(
            sample: DailyDashboardSnapshot(referenceDate: now),
            states: .loading
        )
    }

    static var errorStore: DailyOverviewStore {
        DailyOverviewStore(sample: DailyDashboardSnapshot(referenceDate: now), states: .failed("HealthKit query"))
    }

    private static func snapshot(for level: RecoverySignalLevel) -> DailyDashboardSnapshot {
        let statuses: (HRVStatusLevel, RHRStatusLevel)
        switch level {
        case .favorable:
            statuses = (.high, .suppressed)
        case .typical:
            statuses = (.normal, .normal)
        case .mixed:
            statuses = (.high, .elevated)
        case .strained:
            statuses = (.low, .elevated)
        }

        return DailyDashboardSnapshot(
            referenceDate: now,
            sleep: sleep,
            hrv: HRVStatus(value: 54, level: statuses.0, confidence: .high),
            rhr: RHRStatus(value: 57, level: statuses.1, confidence: .high),
            spo2: SpO2Status(value: 96, level: .normal, confidence: .medium)
        )
    }
}

#Preview("Favorable · 40 mm", traits: .fixedLayout(width: 162, height: 197)) {
    NavigationStack {
        TodayView(store: PreviewData.store(for: .favorable), showsPrimaryNavigation: true)
    }
}

#Preview("Favorable · Ultra", traits: .fixedLayout(width: 205, height: 251)) {
    NavigationStack {
        TodayView(store: PreviewData.store(for: .favorable), showsPrimaryNavigation: true)
    }
}

#Preview("Strained", traits: .fixedLayout(width: 176, height: 215)) {
    NavigationStack {
        TodayView(store: PreviewData.store(for: .strained), showsPrimaryNavigation: true)
    }
}

#Preview("Mixed", traits: .fixedLayout(width: 176, height: 215)) {
    NavigationStack {
        TodayView(store: PreviewData.store(for: .mixed), showsPrimaryNavigation: true)
    }
}

#Preview("Missing recovery · partial", traits: .fixedLayout(width: 162, height: 197)) {
    NavigationStack {
        TodayView(store: PreviewData.partialStore, showsPrimaryNavigation: true)
    }
}

#Preview("Loading", traits: .fixedLayout(width: 205, height: 251)) {
    NavigationStack {
        TodayView(store: PreviewData.loadingStore, showsPrimaryNavigation: true)
    }
}

#Preview("Historical · static", traits: .fixedLayout(width: 162, height: 197)) {
    NavigationStack {
        TodayView(store: PreviewData.store(for: .typical), showsPrimaryNavigation: false)
    }
}

#Preview("HRV detail") {
    NavigationStack { HRVDetailView(store: PreviewData.store) }
}

#Preview("History") {
    NavigationStack { HistoryView(store: PreviewData.store) }
}

#Preview("Error") {
    NavigationStack { SpO2DetailView(store: PreviewData.errorStore) }
}
#endif
