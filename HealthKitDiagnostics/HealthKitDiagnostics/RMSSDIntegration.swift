import Foundation
import HealthKit
import MetricsCore
import WatchMetricsSupport

/// Optional production bridge for RR-derived nightly RMSSD. It is owned by
/// `DailyOverviewStore`, not `BriefRunner`, so heartbeat-series availability
/// and query cost cannot affect morning-brief policy or delivery.
@MainActor
@Observable
final class RMSSDIntegration {
    private let heartbeatService = HeartbeatSeriesService()

    private(set) var nightlyValue: Double?
    private(set) var status: RMSSDStatus?
    private(set) var history: [DatedMetric<Double>] = []
    private(set) var statusText = "Not started"
    private(set) var isLoading = false

    func run(
        referenceDate: Date,
        nights: [ResolvedNight],
        requestAccess: Bool = true
    ) async {
        isLoading = true
        defer { isLoading = false }

        guard HKHealthStore.isHealthDataAvailable() else {
            clear(status: "HealthKit nie je na tomto zariadení dostupný")
            return
        }

        if requestAccess {
            do {
                try await heartbeatService.requestAuthorization()
            } catch {
                clear(status: "Authorization error: \(error.localizedDescription)")
                return
            }
        }

        await compute(referenceDate: referenceDate, nights: nights)
    }

    private func compute(referenceDate: Date, nights: [ResolvedNight]) async {
        let calendar = Calendar.current
        guard let selected = nights.first(where: {
            calendar.isDate($0.day, inSameDayAs: referenceDate)
        }) else {
            clear(status: "Nedostatok RMSSD dát — chýba hlavný spánok")
            return
        }

        // The selected night plus at most 28 preceding nights are loaded once
        // per dashboard refresh. The extra predecessor is needed to construct
        // a full 28-day baseline while the exposed trend remains capped at
        // 28 valid nightly values.
        let candidateNights = Array(nights.prefix(29))
        var dailyValues: [DailyMetricValue] = []
        dailyValues.reserveCapacity(candidateNights.count)

        do {
            for night in candidateNights {
                try Task.checkCancellation()
                let result = try await heartbeatService.load(in: night.interval)
                if let rmssd = result.rmssd, rmssd.isFinite, rmssd >= 0 {
                    dailyValues.append(DailyMetricValue(date: night.day, value: rmssd))
                }
            }
            try Task.checkCancellation()
        } catch {
            clear(
                status: error is CancellationError
                    ? "Načítanie RMSSD bolo zrušené"
                    : "RMSSD query error: \(error.localizedDescription)"
            )
            return
        }

        let selectedValue = dailyValues.first {
            calendar.isDate($0.date, inSameDayAs: selected.day)
        }?.value
        nightlyValue = selectedValue
        status = RMSSDStatus.compute(
            value: selectedValue,
            baseline: BaselineTracker.baseline(from: dailyValues, asOf: selected.day)
        )
        history = Array(
            dailyValues
                .prefix(28)
                .map { DatedMetric(date: $0.date, value: $0.value) }
                .reversed()
        )

        if selectedValue == nil {
            statusText = "Nedostatok RMSSD dát pre túto noc"
        } else if status == nil {
            statusText = "RMSSD je dostupné, osobná baseline zatiaľ nie"
        } else {
            statusText = "OK"
        }
    }

    private func clear(status statusText: String) {
        nightlyValue = nil
        status = nil
        history = []
        self.statusText = statusText
    }
}
