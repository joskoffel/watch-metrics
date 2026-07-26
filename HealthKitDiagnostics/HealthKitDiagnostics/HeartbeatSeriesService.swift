import Foundation
import HealthKit
import MetricsCore
import WatchMetricsSupport

struct HeartbeatNightResult {
    let seriesCount: Int
    let rawIntervals: [RRInterval]
    let acceptedIntervals: [RRInterval]
    let rmssd: Double?
}

@MainActor
final class HeartbeatSeriesService {
    private let healthStore: HKHealthStore
    private let heartbeatType = HKSeriesType.heartbeat()

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    func requestAuthorization() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: nil, read: [heartbeatType]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if granted {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HeartbeatSeriesServiceError.authorizationDenied)
                }
            }
        }
    }

    func load(in interval: DateInterval) async throws -> HeartbeatNightResult {
        try Task.checkCancellation()
        let samples = try await fetchSeries(in: interval)
        var rawSeries: [[RRInterval]] = []
        var acceptedSeries: [[RRInterval]] = []

        for sample in samples {
            try Task.checkCancellation()
            let events = try await fetchEvents(in: sample)
            let raw = try HeartbeatEventMapper.intervals(from: events)
            rawSeries.append(raw)
            acceptedSeries.append(RRArtifactFilter.filter(raw))
        }

        return HeartbeatNightResult(
            seriesCount: samples.count,
            rawIntervals: rawSeries.flatMap { $0 },
            acceptedIntervals: acceptedSeries.flatMap { $0 },
            rmssd: SeriesRMSSDAggregator.calculate(from: acceptedSeries)
        )
    }

    private func fetchSeries(in interval: DateInterval) async throws -> [HKHeartbeatSeriesSample] {
        let cancellation = HealthQueryCancellation(healthStore: healthStore)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let predicate = HKQuery.predicateForSamples(
                    withStart: interval.start,
                    end: interval.end,
                    options: [.strictStartDate, .strictEndDate]
                )
                let query = HKSampleQuery(
                    sampleType: heartbeatType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [
                        NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
                    ]
                ) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(
                            returning: (samples as? [HKHeartbeatSeriesSample]) ?? []
                        )
                    }
                }
                cancellation.install(query)
                healthStore.execute(query)
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    private func fetchEvents(in sample: HKHeartbeatSeriesSample) async throws -> [HeartbeatEvent] {
        let collector = HeartbeatEventCollector()
        let cancellation = HealthQueryCancellation(healthStore: healthStore)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let query = HKHeartbeatSeriesQuery(heartbeatSeries: sample) {
                    _, timeSinceSeriesStart, precededByGap, done, error in
                    Task {
                        if let error {
                            if let result = await collector.finish(with: .failure(error)) {
                                continuation.resume(with: result)
                            }
                            return
                        }
                        await collector.append(
                            HeartbeatEvent(
                                timeSinceSeriesStart: timeSinceSeriesStart,
                                precededByGap: precededByGap
                            )
                        )
                        if done, let result = await collector.finishSuccessfully() {
                            continuation.resume(with: result)
                        }
                    }
                }
                cancellation.install(query)
                healthStore.execute(query)
            }
        } onCancel: {
            cancellation.cancel()
        }
    }
}

private actor HeartbeatEventCollector {
    private var events: [HeartbeatEvent] = []
    private var finished = false

    func append(_ event: HeartbeatEvent) {
        guard !finished else { return }
        events.append(event)
    }

    func finishSuccessfully() -> Result<[HeartbeatEvent], Error>? {
        finish(with: .success(events))
    }

    func finish(with result: Result<[HeartbeatEvent], Error>) -> Result<[HeartbeatEvent], Error>? {
        guard !finished else { return nil }
        finished = true
        return result
    }
}

private final class HealthQueryCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private let healthStore: HKHealthStore
    private var query: HKQuery?
    private var cancelled = false

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    func install(_ query: HKQuery) {
        lock.lock()
        self.query = query
        let shouldStop = cancelled
        lock.unlock()
        if shouldStop { healthStore.stop(query) }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let query = query
        lock.unlock()
        if let query { healthStore.stop(query) }
    }
}

private enum HeartbeatSeriesServiceError: Error {
    case authorizationDenied
}
