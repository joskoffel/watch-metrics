import Foundation
import HealthKit
import MetricsCore
import WatchMetricsSupport

struct HeartbeatNightResult {
    let seriesCount: Int
    let rawIntervals: [RRInterval]
    let acceptedIntervals: [RRInterval]
    let rmssd: Double?
    let unusableSeries: [HeartbeatSeriesFailure]
}

struct HeartbeatSeriesFailure: Identifiable {
    let seriesIndex: Int
    let seriesStart: Date
    let reason: String

    var id: Int { seriesIndex }
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

        var unusableSeries: [HeartbeatSeriesFailure] = []
        for (index, sample) in samples.enumerated() {
            try Task.checkCancellation()
            let events = try await fetchEvents(in: sample)
            do {
                let raw = try HeartbeatEventMapper.intervals(from: events)
                rawSeries.append(raw)
                acceptedSeries.append(RRArtifactFilter.filter(raw))
            } catch let error as HeartbeatEventMappingError {
                unusableSeries.append(
                    HeartbeatSeriesFailure(
                        seriesIndex: index + 1,
                        seriesStart: sample.startDate,
                        reason: error.localizedDescription
                    )
                )
            }
        }

        return HeartbeatNightResult(
            seriesCount: samples.count,
            rawIntervals: rawSeries.flatMap { $0 },
            acceptedIntervals: acceptedSeries.flatMap { $0 },
            rmssd: SeriesRMSSDAggregator.calculate(from: acceptedSeries),
            unusableSeries: unusableSeries
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
                collector.installCompletion { continuation.resume(with: $0) }
                let query = HKHeartbeatSeriesQuery(heartbeatSeries: sample) {
                    _, timeSinceSeriesStart, precededByGap, done, error in
                    let event = error == nil
                        ? HeartbeatEvent(
                            timeSinceSeriesStart: timeSinceSeriesStart,
                            precededByGap: precededByGap
                        )
                        : nil
                    collector.receive(event: event, done: done, error: error)
                }
                cancellation.install(query)
                healthStore.execute(query)
            }
        } onCancel: {
            cancellation.cancel()
            collector.cancel()
        }
    }
}

/// Synchronous callback-boundary state machine. HealthKit callback order is
/// preserved because append and `done` are committed under one lock before
/// the callback returns; no unsequenced Tasks are introduced.
final class HeartbeatEventCollector: @unchecked Sendable {
    typealias Completion = (Result<[HeartbeatEvent], Error>) -> Void

    private let lock = NSLock()
    private var events: [HeartbeatEvent] = []
    private var finished = false
    private var completion: Completion?
    private var pendingResult: Result<[HeartbeatEvent], Error>?

    func installCompletion(_ completion: @escaping Completion) {
        lock.lock()
        if let pendingResult {
            self.pendingResult = nil
            lock.unlock()
            completion(pendingResult)
        } else if finished {
            lock.unlock()
        } else {
            self.completion = completion
            lock.unlock()
        }
    }

    func receive(event: HeartbeatEvent?, done: Bool, error: Error?) {
        var delivery: (Completion, Result<[HeartbeatEvent], Error>)?
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }

        if let error {
            delivery = finishLocked(with: .failure(error))
        } else {
            if let event { events.append(event) }
            if done { delivery = finishLocked(with: .success(events)) }
        }
        lock.unlock()
        if let delivery { delivery.0(delivery.1) }
    }

    func cancel() {
        var delivery: (Completion, Result<[HeartbeatEvent], Error>)?
        lock.lock()
        if !finished { delivery = finishLocked(with: .failure(CancellationError())) }
        lock.unlock()
        if let delivery { delivery.0(delivery.1) }
    }

    private func finishLocked(
        with result: Result<[HeartbeatEvent], Error>
    ) -> (Completion, Result<[HeartbeatEvent], Error>)? {
        finished = true
        guard let completion else {
            pendingResult = result
            return nil
        }
        self.completion = nil
        return (completion, result)
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
