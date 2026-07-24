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

    func run() async {
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

        await computeHRVStatus()
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

    private func computeHRVStatus() async {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -28, to: todayStart) else {
            statusText = "Could not compute the 28-day lookback range"
            return
        }

        do {
            let samples = try await fetchSDNNSamples(from: windowStart, to: now)
            guard !samples.isEmpty else {
                statusText = "Nedostatok dát — žiadne SDNN vzorky za posledných 28 dní"
                hrvStatus = nil
                return
            }

            let samplesByDay = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.timestamp) }
            let dailyValues = samplesByDay.map { day, daySamples in
                DailyMetricValue(date: day, value: Self.median(of: daySamples.map(\.value)))
            }

            let baseline = BaselineTracker.baseline(from: dailyValues, asOf: todayStart)
            let todaysSamples = samplesByDay[todayStart] ?? []

            guard let status = HRVStatus.compute(from: todaysSamples, baseline: baseline) else {
                hrvStatus = nil
                statusText = todaysSamples.isEmpty
                    ? "Nedostatok dát pre dnešný deň — žiadna SDNN vzorka dnes"
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
