import Foundation
import HealthKit

/// Gate G0.2: checks whether this watch actually exposes raw RR intervals
/// via HKHeartbeatSeriesQuery — the Health app export does not contain
/// them (see docs/data-availability-report.md), so this has to be verified
/// live, on-device, through HealthKit directly.
///
/// HealthKit's completion-handler APIs here are `@Sendable`, so their
/// closures can't capture `self` (this class holds UI state and isn't
/// Sendable) — each call is bridged into async/await via
/// withCheckedContinuation instead, capturing only the continuation and
/// primitive values. HKHeartbeatSeriesQuery's handler fires once per
/// heartbeat, so the running count is held in a small actor rather than a
/// captured `var`, since mutating a captured var from a `@Sendable` closure
/// isn't allowed under Swift 6 strict concurrency.
@MainActor
@Observable
final class HeartbeatSeriesDiagnostics {
    private let healthStore = HKHealthStore()

    private let heartbeatSeriesType = HKSeriesType.heartbeat()
    private let sdnnType = HKQuantityType(.heartRateVariabilitySDNN)

    private(set) var statusText = "Not started"

    func run() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            statusText = "HealthKit not available on this device"
            return
        }

        let typesToRead: Set<HKObjectType> = [heartbeatSeriesType, sdnnType]

        do {
            try await requestAuthorization(read: typesToRead)
        } catch {
            statusText = "Authorization error: \(error.localizedDescription)"
            return
        }

        await queryHeartbeatSeries()
    }

    private func requestAuthorization(read types: Set<HKObjectType>) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: nil, read: types) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if !granted {
                    continuation.resume(throwing: DiagnosticsError.authorizationDenied)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func queryHeartbeatSeries() async {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: now, options: .strictStartDate)

        do {
            let series = try await fetchHeartbeatSeries(matching: predicate)
            guard !series.isEmpty else {
                statusText = "0 series found"
                return
            }
            let beatCount = await countHeartbeats(in: series[0])
            statusText = "\(series.count) series found\nFirst series: \(beatCount) RR intervals"
        } catch {
            statusText = "Series query error: \(error.localizedDescription)"
        }
    }

    private func fetchHeartbeatSeries(matching predicate: NSPredicate) async throws -> [HKHeartbeatSeriesSample] {
        try await withCheckedThrowingContinuation { continuation in
            let sortByStartDateDescending = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let sampleQuery = HKSampleQuery(
                sampleType: heartbeatSeriesType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortByStartDateDescending]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKHeartbeatSeriesSample]) ?? [])
            }
            healthStore.execute(sampleQuery)
        }
    }

    private func countHeartbeats(in series: HKHeartbeatSeriesSample) async -> Int {
        let counter = HeartbeatSeriesCounter()
        return await withCheckedContinuation { continuation in
            let query = HKHeartbeatSeriesQuery(heartbeatSeries: series) { _, _, _, done, error in
                Task {
                    if error != nil {
                        if let finalCount = await counter.finish() {
                            continuation.resume(returning: finalCount)
                        }
                        return
                    }
                    await counter.increment()
                    if done {
                        if let finalCount = await counter.finish() {
                            continuation.resume(returning: finalCount)
                        }
                    }
                }
            }
            healthStore.execute(query)
        }
    }
}

/// Serializes access to the running heartbeat count — HKHeartbeatSeriesQuery
/// fires its handler once per heartbeat, so this can't just be a captured
/// `var`. `finish()` returns nil on a second call so a late error callback
/// can never resume an already-resumed continuation.
private actor HeartbeatSeriesCounter {
    private var count = 0
    private var hasFinished = false

    func increment() {
        guard !hasFinished else { return }
        count += 1
    }

    func finish() -> Int? {
        guard !hasFinished else { return nil }
        hasFinished = true
        return count
    }
}

private enum DiagnosticsError: Error {
    case authorizationDenied
}
