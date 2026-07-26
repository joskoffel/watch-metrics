import Foundation
import HealthKit
import MetricsCore
import WatchMetricsSupport

/// First real bridge between HealthKit and MetricsCore: reads HRV SDNN
/// samples, reduces them to the daily/baseline shape MetricsCore expects,
/// and calls the same pure `BaselineTracker`/`HRVStatus` functions already
/// verified by MetricsCoreTests — no HealthKit-specific logic lives in
/// MetricsCore itself, only here at the boundary.
@MainActor
@Observable
final class HRVIntegration {
    private let healthStore = HKHealthStore()
    private let sdnnType = HKQuantityType(.heartRateVariabilitySDNN)

    private(set) var hrvStatus: HRVStatus?
    private(set) var history: [DatedMetric<HRVStatus>] = []
    private(set) var statusText = "Not started"
    private(set) var isLoading = false

    /// `referenceDate` picks which night to show (defaults to tonight).
    /// Every date computation below already ran through `BaselineTracker`'s
    /// existing `asOf:` parameter — MetricsCore never called `Date()`
    /// internally. The only real "now" dependency was here, so this is
    /// where a selected historical night gets threaded through.
    func run(
        referenceDate: Date = Date(),
        nights: [ResolvedNight],
        requestAccess: Bool = true
    ) async {
        isLoading = true
        defer { isLoading = false }

        guard HKHealthStore.isHealthDataAvailable() else {
            statusText = "HealthKit not available on this device"
            return
        }

        if requestAccess {
            do {
                try await requestAuthorization()
            } catch {
                statusText = "Authorization error: \(error.localizedDescription)"
                return
            }
        }

        await computeHRVStatus(referenceDate: referenceDate, nights: nights)
    }

    private func requestAuthorization() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: nil, read: [sdnnType]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if !granted {
                    continuation.resume(throwing: HRVIntegrationError.authorizationDenied)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func computeHRVStatus(referenceDate: Date, nights: [ResolvedNight]) async {
        let calendar = Calendar.current
        guard let firstStart = nights.map(\.interval.start).min(),
              let lastEnd = nights.map(\.interval.end).max() else {
            hrvStatus = nil
            history = []
            statusText = "Nedostatok dát — chýba hlavný spánok"
            return
        }

        do {
            let samples = try await fetchSDNNSamples(from: firstStart, to: lastEnd)
            guard !Task.isCancelled else { return }

            guard !samples.isEmpty else {
                statusText = "Nedostatok dát — žiadne SDNN vzorky za posledných 28 dní"
                hrvStatus = nil
                return
            }

            let dailyValues = nights.compactMap {
                NightMetricMapper.dailyMedian(
                    samples: samples, kind: .heartRateVariabilitySDNN, in: $0
                )
            }
            let selected = nights.first {
                calendar.isDate($0.day, inSameDayAs: referenceDate)
            }
            history = Array(nights.prefix(14).compactMap { night in
                let nightSamples = NightMetricMapper.samples(
                    samples, kind: .heartRateVariabilitySDNN, in: night
                )
                guard let status = HRVStatus.compute(
                    from: nightSamples,
                    baseline: BaselineTracker.baseline(from: dailyValues, asOf: night.day)
                ) else { return nil }
                return DatedMetric(date: night.day, value: status)
            }.reversed())

            guard let selected else {
                hrvStatus = nil
                statusText = "Nedostatok dát — chýba hlavný spánok"
                return
            }
            let nightSamples = NightMetricMapper.samples(
                samples, kind: .heartRateVariabilitySDNN, in: selected
            )
            guard let status = HRVStatus.compute(
                from: nightSamples,
                baseline: BaselineTracker.baseline(from: dailyValues, asOf: selected.day)
            ) else {
                hrvStatus = nil
                statusText = "Nedostatok dát pre túto noc"
                return
            }

            hrvStatus = status
            statusText = "OK"
        } catch {
            statusText = "Query error: \(error.localizedDescription)"
        }
    }

    /// Maps HealthKit's raw HRV SDNN samples onto MetricsCore's `SensorSample`.
    /// SDNN quantities must be read in milliseconds via
    /// `HKUnit.secondUnit(with: .milli)` — reading with `HKUnit.second()`
    /// would silently return values 1000x too small.
    private func fetchSDNNSamples(from start: Date, to end: Date) async throws -> [SensorSample] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sortByStartDate = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(
                sampleType: sdnnType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortByStartDate]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let millisecondUnit = HKUnit.secondUnit(with: .milli)
                let mapped = ((samples as? [HKQuantitySample]) ?? []).map { sample in
                    SensorSample(
                        kind: .heartRateVariabilitySDNN,
                        timestamp: sample.startDate,
                        value: sample.quantity.doubleValue(for: millisecondUnit),
                        unit: .milliseconds
                    )
                }
                continuation.resume(returning: mapped)
            }

            healthStore.execute(query)
        }
    }
}

private enum HRVIntegrationError: Error {
    case authorizationDenied
}
