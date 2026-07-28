import Foundation
import MetricsCore

/// HealthKit-independent heartbeat callback value. `timeSinceSeriesStart` is
/// cumulative seconds, matching HKHeartbeatSeriesQuery.
public struct HeartbeatEvent: Equatable, Sendable {
    public let timeSinceSeriesStart: TimeInterval
    public let precededByGap: Bool

    public init(timeSinceSeriesStart: TimeInterval, precededByGap: Bool) {
        self.timeSinceSeriesStart = timeSinceSeriesStart
        self.precededByGap = precededByGap
    }
}

public enum HeartbeatEventMappingError: LocalizedError, Equatable {
    case invalidTime
    case nonIncreasingTime

    public var errorDescription: String? {
        switch self {
        case .invalidTime:
            "neplatná kumulatívna časová hodnota heartbeat eventu"
        case .nonIncreasingTime:
            "heartbeat časy nie sú striktne rastúce"
        }
    }
}

public enum HeartbeatEventMapper {
    public struct UsableSeries: Equatable {
        public let seriesIndex: Int
        public let intervals: [RRInterval]

        public init(seriesIndex: Int, intervals: [RRInterval]) {
            self.seriesIndex = seriesIndex
            self.intervals = intervals
        }
    }

    public struct SeriesFailure: Equatable {
        public let seriesIndex: Int
        public let reason: HeartbeatEventMappingError

        public init(seriesIndex: Int, reason: HeartbeatEventMappingError) {
            self.seriesIndex = seriesIndex
            self.reason = reason
        }
    }

    public struct IndependentMappingResult: Equatable {
        public let usableSeries: [UsableSeries]
        public let failures: [SeriesFailure]

        public init(usableSeries: [UsableSeries], failures: [SeriesFailure]) {
            self.usableSeries = usableSeries
            self.failures = failures
        }
    }

    public static func intervals(from events: [HeartbeatEvent]) throws -> [RRInterval] {
        var previousTime: TimeInterval?
        var intervals: [RRInterval] = []

        for event in events {
            guard event.timeSinceSeriesStart.isFinite, event.timeSinceSeriesStart >= 0 else {
                throw HeartbeatEventMappingError.invalidTime
            }
            if let previousTime {
                guard event.timeSinceSeriesStart > previousTime else {
                    throw HeartbeatEventMappingError.nonIncreasingTime
                }
                if !event.precededByGap {
                    let milliseconds = ((event.timeSinceSeriesStart - previousTime) * 1_000_000).rounded() / 1_000
                    intervals.append(RRInterval(milliseconds: milliseconds))
                }
            }
            previousTime = event.timeSinceSeriesStart
        }
        return intervals
    }

    public static func intervals(fromSeries series: [[HeartbeatEvent]]) throws -> [RRInterval] {
        try series.flatMap(intervals(from:))
    }

    /// Maps every series in isolation. A malformed series is transparent in
    /// `failures` and cannot erase or bridge the valid intervals of another
    /// series.
    public static func mapIndependently(_ series: [[HeartbeatEvent]]) -> IndependentMappingResult {
        var usableSeries: [UsableSeries] = []
        var failures: [SeriesFailure] = []

        for (seriesIndex, events) in series.enumerated() {
            do {
                usableSeries.append(
                    UsableSeries(
                        seriesIndex: seriesIndex,
                        intervals: try intervals(from: events)
                    )
                )
            } catch let reason as HeartbeatEventMappingError {
                failures.append(SeriesFailure(seriesIndex: seriesIndex, reason: reason))
            } catch {
                assertionFailure("HeartbeatEventMapper emitted an unexpected error: \(error)")
            }
        }

        return IndependentMappingResult(usableSeries: usableSeries, failures: failures)
    }
}
