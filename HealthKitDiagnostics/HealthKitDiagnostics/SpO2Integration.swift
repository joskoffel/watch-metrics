import Foundation
import HealthKit
import MetricsCore

/// HealthKit -> MetricsCore bridge for SpO2, same shape as `HRVIntegration`.
@MainActor
@Observable
final class SpO2Integration {
    private let healthStore = HKHealthStore()
    private let spo2Type = HKQuantityType(.oxygenSaturation)

    private(set) var spo2Status: SpO2Status?
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

        await computeSpO2Status()
    }

    private func requestAuthorization() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: nil, read: [spo2Type]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if !granted {
                    continuation.resume(throwing: SpO2IntegrationError.authorizationDenied)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func computeSpO2Status() async {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -28, to: todayStart) else {
            statusText = "Could not compute the 28-day lookback range"
            return
        }

        do {
            let samples = try await fetchSpO2Samples(from: windowStart, to: now)
            guard !samples.isEmpty else {
                statusText = "Nedostatok dát — žiadne SpO2 vzorky za posledných 28 dní"
                spo2Status = nil
                return
            }

            let samplesByDay = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.timestamp) }
            let dailyValues = samplesByDay.map { day, daySamples in
                DailyMetricValue(date: day, value: Self.median(of: daySamples.map(\.value)))
            }

            let baseline = BaselineTracker.baseline(from: dailyValues, asOf: todayStart)
            let todaysSamples = samplesByDay[todayStart] ?? []

            guard let status = SpO2Status.compute(from: todaysSamples, baseline: baseline) else {
                spo2Status = nil
                statusText = "Nedostatok dát pre dnešný deň — žiadna SpO2 vzorka dnes"
                return
            }

            spo2Status = status
        } catch {
            statusText = "Query error: \(error.localizedDescription)"
        }
    }

    /// Maps HealthKit's oxygen saturation samples onto MetricsCore's
    /// `SensorSample`. `HKUnit.percent()` returns a 0.0-1.0 fraction, not
    /// 0-100 — must be scaled by 100 to match SensorSample's percent scale
    /// (and SpO2Status's 95.0/90.0 thresholds).
    private func fetchSpO2Samples(from start: Date, to end: Date) async throws -> [SensorSample] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sortByStartDate = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(
                sampleType: spo2Type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortByStartDate]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let mapped = ((samples as? [HKQuantitySample]) ?? []).map { sample in
                    SensorSample(
                        kind: .oxygenSaturation,
                        timestamp: sample.startDate,
                        value: sample.quantity.doubleValue(for: .percent()) * 100,
                        unit: .percent
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

private enum SpO2IntegrationError: Error {
    case authorizationDenied
}
