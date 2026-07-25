import Foundation
import HealthKit
import MetricsCore

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
    private(set) var statusText = "Not started"
    private(set) var isLoading = false

    /// `referenceDate` picks which night to show (defaults to tonight).
    /// Every date computation below already ran through `BaselineTracker`'s
    /// existing `asOf:` parameter — MetricsCore never called `Date()`
    /// internally. The only real "now" dependency was here, so this is
    /// where a selected historical night gets threaded through.
    func run(referenceDate: Date = Date()) async {
        isLoading = true
        defer { isLoading = false }

        guard HKHealthStore.isHealthDataAvailable() else {
            statusText = "HealthKit not available on this device"
            return
        }

        do {
            try await requestAuthorization()
        } catch {
            statusText = "Authorization error: \(error.localizedDescription)"
            return
        }

        await computeHRVStatus(referenceDate: referenceDate)
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

    private func computeHRVStatus(referenceDate: Date) async {
        let calendar = Calendar.current
        let nightStart = calendar.startOfDay(for: referenceDate)
        guard let nightEnd = calendar.date(byAdding: .day, value: 1, to: nightStart),
              let windowStart = calendar.date(byAdding: .day, value: -28, to: nightStart) else {
            statusText = "Could not compute the 28-day lookback range"
            return
        }

        do {
            let samples = try await fetchSDNNSamples(from: windowStart, to: nightEnd)
            guard !Task.isCancelled else { return }

            guard !samples.isEmpty else {
                statusText = "Nedostatok dát — žiadne SDNN vzorky za posledných 28 dní"
                hrvStatus = nil
                return
            }

            let samplesByDay = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.timestamp) }
            let dailyValues = samplesByDay.map { day, daySamples in
                DailyMetricValue(date: day, value: Self.median(of: daySamples.map(\.value)))
            }

            let baseline = BaselineTracker.baseline(from: dailyValues, asOf: nightStart)
            let nightSamples = samplesByDay[nightStart] ?? []

            guard let status = HRVStatus.compute(from: nightSamples, baseline: baseline) else {
                hrvStatus = nil
                statusText = nightSamples.isEmpty
                    ? "Nedostatok dát pre túto noc"
                    : "Baseline zatiaľ nedostupný — chýba história za 7d aj 28d"
                return
            }

            hrvStatus = status
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

    private static func median(of values: [Double]) -> Double {
        let sorted = values.sorted()
        let count = sorted.count
        if count % 2 == 1 {
            return sorted[count / 2]
        }
        return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
    }
}

private enum HRVIntegrationError: Error {
    case authorizationDenied
}
