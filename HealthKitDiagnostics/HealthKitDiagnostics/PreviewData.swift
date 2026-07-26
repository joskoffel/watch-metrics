import MetricsCore
import SwiftUI

#if DEBUG
@MainActor
enum PreviewData {
    static let now = Date(timeIntervalSince1970: 1_767_268_800)
    static let snapshot = DailyDashboardSnapshot(
        referenceDate: now,
        sleep: SleepSession(
            start: now.addingTimeInterval(-8.1 * 3600),
            end: now.addingTimeInterval(-1.2 * 3600),
            asleepDuration: 6.55 * 3600
        ),
        hrv: HRVStatus(value: 54, level: .normal, confidence: .high),
        rhr: RHRStatus(value: 57, level: .normal, confidence: .medium),
        spo2: SpO2Status(value: 96, level: .normal, confidence: .medium)
    )

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
        DailyOverviewStore(
            sample: snapshot,
            history: history,
            hrvHistory: history.compactMap { day in day.hrv.map { DatedMetric(date: day.referenceDate, value: $0) } },
            rhrHistory: history.compactMap { day in day.rhr.map { DatedMetric(date: day.referenceDate, value: $0) } },
            spo2History: history.compactMap { day in day.spo2.map { DatedMetric(date: day.referenceDate, value: $0) } }
        )
    }

    static var emptyStore: DailyOverviewStore {
        DailyOverviewStore(sample: DailyDashboardSnapshot(referenceDate: now), states: .empty)
    }

    static var errorStore: DailyOverviewStore {
        DailyOverviewStore(sample: DailyDashboardSnapshot(referenceDate: now), states: .failed("HealthKit query"))
    }
}

#Preview("Today") {
    NavigationStack { TodayView(store: PreviewData.store, showsPrimaryNavigation: true) }
}

#Preview("HRV detail") {
    NavigationStack { HRVDetailView(store: PreviewData.store) }
}

#Preview("History") {
    NavigationStack { HistoryView(store: PreviewData.store) }
}

#Preview("Empty") {
    NavigationStack { TodayView(store: PreviewData.emptyStore, showsPrimaryNavigation: false) }
}

#Preview("Error") {
    NavigationStack { SpO2DetailView(store: PreviewData.errorStore) }
}
#endif
