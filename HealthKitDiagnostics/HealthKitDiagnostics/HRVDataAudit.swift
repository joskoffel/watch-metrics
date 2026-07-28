import Foundation
import HealthKit
import MetricsCore
import WatchMetricsSupport

struct HRVDataAuditNight: Identifiable {
    let day: Date
    let sdnnSampleCount: Int
    let sdnn: Double?
    let heartbeat: HeartbeatNightResult
    let heartRate: NightHeartRateAudit?

    var id: Date { day }

    var facts: NightAuditFacts {
        NightAuditFacts(
            sdnnSampleCount: sdnnSampleCount,
            heartbeatSeriesCount: heartbeat.seriesCount,
            rawRRCount: heartbeat.rawIntervals.count,
            acceptedRRCount: heartbeat.acceptedIntervals.count,
            hasRMSSD: heartbeat.rmssd != nil,
            hasUnusableHeartbeatSeries: !heartbeat.unusableSeries.isEmpty
        )
    }
}

@MainActor
@Observable
final class HRVDataAuditStore {
    private let sleepIntegration = SleepIntegration()
    private let heartbeatService = HeartbeatSeriesService()
    private let healthStore = HKHealthStore()
    private let sdnnType = HKQuantityType(.heartRateVariabilitySDNN)
    private let heartRateType = HKQuantityType(.heartRate)
    @ObservationIgnored private var auditTask: Task<Void, Never>?

    private(set) var nights: [HRVDataAuditNight] = []
    private(set) var summary: HRVDataAuditSummary?
    private(set) var completedNightCount = 0
    private(set) var totalNightCount = 0
    private(set) var isLoading = false
    private(set) var errorText: String?

    var progress: Double {
        totalNightCount > 0 ? Double(completedNightCount) / Double(totalNightCount) : 0
    }

    func start(days: Int = 28) {
        cancel()
        auditTask = Task { await run(days: days) }
    }

    func cancel() {
        auditTask?.cancel()
        auditTask = nil
        if isLoading {
            isLoading = false
            errorText = "Audit bol zrušený"
        }
    }

    private func run(days: Int) async {
        isLoading = true
        errorText = nil
        nights = []
        summary = nil
        completedNightCount = 0
        totalNightCount = 0
        defer { isLoading = false }

        guard HKHealthStore.isHealthDataAvailable() else {
            errorText = "HealthKit nie je na tomto zariadení dostupný"
            return
        }

        do {
            try await requestAuthorization()
            await sleepIntegration.run(historyDays: days, requestAccess: false)
            try Task.checkCancellation()
            let resolved = Array(sleepIntegration.resolvedNights.prefix(days))
            guard let firstStart = resolved.map(\.interval.start).min(),
                  let lastEnd = resolved.map(\.interval.end).max() else {
                errorText = "Za zvolené obdobie sa nenašiel hlavný spánok"
                return
            }

            let sdnnSamples = try await fetchQuantitySamples(
                type: sdnnType, from: firstStart, to: lastEnd
            )
            let heartRateSamples = try await fetchQuantitySamples(
                type: heartRateType, from: firstStart, to: lastEnd
            )
            totalNightCount = resolved.count

            for night in resolved {
                try Task.checkCancellation()
                let heartbeat = try await heartbeatService.load(in: night.interval)
                let nightSDNN = sdnnSamples.filter { night.interval.contains($0.startDate) }
                let sdnnValues = nightSDNN.map {
                    $0.quantity.doubleValue(for: .secondUnit(with: .milli))
                }
                let timedHeartRates = heartRateSamples.map {
                    TimedHeartRate(
                        timestamp: $0.startDate,
                        beatsPerMinute: $0.quantity.doubleValue(
                            for: .count().unitDivided(by: .minute())
                        )
                    )
                }
                nights.append(
                    HRVDataAuditNight(
                        day: night.day,
                        sdnnSampleCount: nightSDNN.count,
                        sdnn: Self.median(sdnnValues),
                        heartbeat: heartbeat,
                        heartRate: NightHeartRateAnalyzer.analyze(
                            samples: timedHeartRates, interval: night.interval
                        )
                    )
                )
                completedNightCount += 1
            }
            summary = HRVDataAuditSummary.compute(from: nights.map(\.facts))
        } catch {
            errorText = Task.isCancelled || error is CancellationError
                ? "Audit bol zrušený"
                : "Audit zlyhal: \(error.localizedDescription)"
        }
    }

    private func requestAuthorization() async throws {
        var readTypes = HeartbeatHealthKitTypes.requiredReadTypes
        readTypes.formUnion([
            HKCategoryType(.sleepAnalysis),
            heartRateType
        ])
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: nil, read: readTypes) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if granted {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HRVDataAuditError.authorizationDenied)
                }
            }
        }
    }

    private func fetchQuantitySamples(
        type: HKQuantityType,
        from start: Date,
        to end: Date
    ) async throws -> [HKQuantitySample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: HKQuery.predicateForSamples(
                    withStart: start, end: end, options: .strictStartDate
                ),
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [
                    NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
                ]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
                }
            }
            healthStore.execute(query)
        }
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted.count.isMultiple(of: 2)
            ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
            : sorted[sorted.count / 2]
    }
}

private enum HRVDataAuditError: Error {
    case authorizationDenied
}
