import Foundation
import HealthKit
import MetricsCore
import WatchMetricsSupport

/// HealthKit -> MetricsCore bridge for SpO2, same shape as `HRVIntegration`.
@MainActor
@Observable
final class SpO2Integration {
    private let healthStore = HKHealthStore()
    private let spo2Type = HKQuantityType(.oxygenSaturation)

    private(set) var spo2Status: SpO2Status?
    private(set) var history: [DatedMetric<SpO2Status>] = []
    private(set) var statusText = "Not started"
    private(set) var isLoading = false

    /// `referenceDate` picks which night to show (defaults to tonight) —
    /// see `HRVIntegration.run(referenceDate:)` for why this is the only
    /// place a "now" dependency exists in this pipeline.
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

        await computeSpO2Status(referenceDate: referenceDate, nights: nights)
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

    private func computeSpO2Status(referenceDate: Date, nights: [ResolvedNight]) async {
        let calendar = Calendar.current
        guard let firstStart = nights.map(\.interval.start).min(),
              let lastEnd = nights.map(\.interval.end).max() else {
            spo2Status = nil
            history = []
            statusText = "Nedostatok dát — chýba hlavný spánok"
            return
        }

        do {
            let samples = try await fetchSpO2Samples(from: firstStart, to: lastEnd)
            guard !Task.isCancelled else { return }

            guard !samples.isEmpty else {
                statusText = "Nedostatok dát — žiadne SpO2 vzorky za posledných 28 dní"
                spo2Status = nil
                return
            }

            let dailyValues = nights.compactMap {
                NightMetricMapper.dailyMedian(samples: samples, kind: .oxygenSaturation, in: $0)
            }
            let selected = nights.first {
                calendar.isDate($0.day, inSameDayAs: referenceDate)
            }
            history = Array(nights.prefix(14).compactMap { night in
                let nightSamples = NightMetricMapper.samples(
                    samples, kind: .oxygenSaturation, in: night
                )
                guard let status = SpO2Status.compute(
                    from: nightSamples,
                    baseline: BaselineTracker.baseline(from: dailyValues, asOf: night.day)
                ) else { return nil }
                return DatedMetric(date: night.day, value: status)
            }.reversed())

            guard let selected else {
                spo2Status = nil
                statusText = "Nedostatok dát — chýba hlavný spánok"
                return
            }
            let nightSamples = NightMetricMapper.samples(samples, kind: .oxygenSaturation, in: selected)
            guard let status = SpO2Status.compute(
                from: nightSamples,
                baseline: BaselineTracker.baseline(from: dailyValues, asOf: selected.day)
            ) else {
                spo2Status = nil
                statusText = "Nedostatok dát pre túto noc"
                return
            }

            spo2Status = status
            statusText = "OK"
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
}

private enum SpO2IntegrationError: Error {
    case authorizationDenied
}
