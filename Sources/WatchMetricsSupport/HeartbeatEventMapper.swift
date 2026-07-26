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

public enum HeartbeatEventMappingError: Error, Equatable {
    case invalidTime
    case nonIncreasingTime
}

public enum HeartbeatEventMapper {
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
}
