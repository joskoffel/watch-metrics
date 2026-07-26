import MetricsCore
import Testing
@testable import WatchMetricsSupport

@Test func heartbeatEventsMapCumulativeTimesToSuccessiveRRIntervals() throws {
    let events = [
        HeartbeatEvent(timeSinceSeriesStart: 0.10, precededByGap: false),
        HeartbeatEvent(timeSinceSeriesStart: 0.92, precededByGap: false),
        HeartbeatEvent(timeSinceSeriesStart: 1.78, precededByGap: false)
    ]

    let intervals = try HeartbeatEventMapper.intervals(from: events)

    #expect(intervals.map(\.milliseconds) == [820, 860])
}

@Test func heartbeatGapDoesNotCreateIntervalAcrossMissingData() throws {
    let events = [
        HeartbeatEvent(timeSinceSeriesStart: 0.1, precededByGap: false),
        HeartbeatEvent(timeSinceSeriesStart: 0.9, precededByGap: false),
        HeartbeatEvent(timeSinceSeriesStart: 4.2, precededByGap: true),
        HeartbeatEvent(timeSinceSeriesStart: 5.1, precededByGap: false)
    ]

    let intervals = try HeartbeatEventMapper.intervals(from: events)

    #expect(intervals.map(\.milliseconds) == [800, 900])
}

@Test func separateSeriesNeverCreateAnIntervalAcrossSeriesBoundary() throws {
    let series = [
        [
            HeartbeatEvent(timeSinceSeriesStart: 0.1, precededByGap: false),
            HeartbeatEvent(timeSinceSeriesStart: 0.9, precededByGap: false)
        ],
        [
            HeartbeatEvent(timeSinceSeriesStart: 0.2, precededByGap: false),
            HeartbeatEvent(timeSinceSeriesStart: 1.1, precededByGap: false)
        ]
    ]

    let intervals = try HeartbeatEventMapper.intervals(fromSeries: series)

    #expect(intervals.map(\.milliseconds) == [800, 900])
}

@Test func sparseSeriesProducesNoInventedInterval() throws {
    let intervals = try HeartbeatEventMapper.intervals(
        from: [HeartbeatEvent(timeSinceSeriesStart: 0.4, precededByGap: false)]
    )

    #expect(intervals.isEmpty)
}

@Test func malformedHeartbeatOrderThrowsInsteadOfProducingNegativeRR() {
    #expect(throws: HeartbeatEventMappingError.self) {
        try HeartbeatEventMapper.intervals(from: [
            HeartbeatEvent(timeSinceSeriesStart: 1.0, precededByGap: false),
            HeartbeatEvent(timeSinceSeriesStart: 0.8, precededByGap: false)
        ])
    }
}
