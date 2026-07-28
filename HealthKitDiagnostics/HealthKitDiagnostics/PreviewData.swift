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

    static var adverseStore: DailyOverviewStore {
        let sample = DailyDashboardSnapshot(
            referenceDate: now,
            sleep: SleepSession(
                start: now.addingTimeInterval(-6.4 * 3600),
                end: now.addingTimeInterval(-1.1 * 3600),
                asleepDuration: 4.85 * 3600
            ),
            hrv: HRVStatus(value: 36, level: .low, confidence: .high),
            rhr: RHRStatus(value: 68, level: .elevated, confidence: .high),
            spo2: SpO2Status(value: 89, level: .critical, confidence: .low)
        )
        return DailyOverviewStore(
            sample: sample,
            history: history,
            hrvHistory: history.compactMap { day in
                day.hrv.map { DatedMetric(date: day.referenceDate, value: $0) }
            },
            rmssdHistory: history.enumerated().map {
                DatedMetric(date: $0.element.referenceDate, value: 34 + Double($0.offset % 4))
            },
            rmssdValue: 35,
            rmssdStatus: RMSSDStatus(value: 35, level: .low, confidence: .medium),
            rhrHistory: history.compactMap { day in
                day.rhr.map { DatedMetric(date: day.referenceDate, value: $0) }
            },
            spo2History: history.compactMap { day in
                day.spo2.map { DatedMetric(date: day.referenceDate, value: $0) }
            }
        )
    }

    static var unavailableStore: DailyOverviewStore {
        DailyOverviewStore(
            sample: DailyDashboardSnapshot(referenceDate: now),
            states: .empty
        )
    }

    static var missingBaselineStore: DailyOverviewStore {
        DailyOverviewStore(
            sample: DailyDashboardSnapshot(referenceDate: now, sleep: sleep),
            states: .loaded
        )
    }

    static var hrvWithoutRMSSDStore: DailyOverviewStore {
        DailyOverviewStore(
            sample: snapshot,
            history: history,
            hrvHistory: history.compactMap { day in
                day.hrv.map { DatedMetric(date: day.referenceDate, value: $0) }
            },
            rmssdValue: nil,
            rmssdStatus: nil
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

#Preview("Sleep detail · 40 mm", traits: .fixedLayout(width: 162, height: 197)) {
    NavigationStack { SleepDetailView(store: PreviewData.store) }
}

#Preview("Sleep detail · loading", traits: .fixedLayout(width: 205, height: 251)) {
    NavigationStack { SleepDetailView(store: PreviewData.loadingStore) }
}

#Preview("Sleep detail · unavailable", traits: .fixedLayout(width: 162, height: 197)) {
    NavigationStack { SleepDetailView(store: PreviewData.unavailableStore) }
}

#Preview("HRV detail · SDNN + RMSSD · Ultra", traits: .fixedLayout(width: 205, height: 251)) {
    NavigationStack { HRVDetailView(store: PreviewData.store) }
}

#Preview("HRV detail · adverse · 40 mm", traits: .fixedLayout(width: 162, height: 197)) {
    NavigationStack { HRVDetailView(store: PreviewData.adverseStore) }
}

#Preview("HRV detail · without RMSSD", traits: .fixedLayout(width: 176, height: 215)) {
    NavigationStack { HRVDetailView(store: PreviewData.hrvWithoutRMSSDStore) }
}

#Preview("HRV detail · loading", traits: .fixedLayout(width: 205, height: 251)) {
    NavigationStack { HRVDetailView(store: PreviewData.loadingStore) }
}

#Preview("HRV detail · missing baseline", traits: .fixedLayout(width: 162, height: 197)) {
    NavigationStack { HRVDetailView(store: PreviewData.missingBaselineStore) }
}

#Preview("RHR detail · normal · Ultra", traits: .fixedLayout(width: 205, height: 251)) {
    NavigationStack { RHRDetailView(store: PreviewData.store) }
}

#Preview("RHR detail · elevated · 40 mm", traits: .fixedLayout(width: 162, height: 197)) {
    NavigationStack { RHRDetailView(store: PreviewData.adverseStore) }
}

#Preview("RHR detail · loading", traits: .fixedLayout(width: 176, height: 215)) {
    NavigationStack { RHRDetailView(store: PreviewData.loadingStore) }
}

#Preview("RHR detail · missing baseline", traits: .fixedLayout(width: 162, height: 197)) {
    NavigationStack { RHRDetailView(store: PreviewData.missingBaselineStore) }
}

#Preview("SpO₂ detail · normal · Ultra", traits: .fixedLayout(width: 205, height: 251)) {
    NavigationStack { SpO2DetailView(store: PreviewData.store) }
}

#Preview("SpO₂ detail · critical · 40 mm", traits: .fixedLayout(width: 162, height: 197)) {
    NavigationStack { SpO2DetailView(store: PreviewData.adverseStore) }
}

#Preview("SpO₂ detail · loading", traits: .fixedLayout(width: 176, height: 215)) {
    NavigationStack { SpO2DetailView(store: PreviewData.loadingStore) }
}

#Preview("SpO₂ detail · unavailable", traits: .fixedLayout(width: 162, height: 197)) {
    NavigationStack { SpO2DetailView(store: PreviewData.unavailableStore) }
}

#Preview("History") {
    NavigationStack { HistoryView(store: PreviewData.store) }
}

#Preview("Error") {
    NavigationStack { SpO2DetailView(store: PreviewData.errorStore) }
}
#endif
