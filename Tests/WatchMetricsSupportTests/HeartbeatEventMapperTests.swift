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
    #expect(throws: HeartbeatEventMappingError.nonIncreasingTime) {
        try HeartbeatEventMapper.intervals(from: [
            HeartbeatEvent(timeSinceSeriesStart: 1.0, precededByGap: false),
            HeartbeatEvent(timeSinceSeriesStart: 0.8, precededByGap: false)
        ])
    }
}

@Test func malformedSeriesDoesNotEraseIntervalsFromOtherSeries() {
    let result = HeartbeatEventMapper.mapIndependently([
        [
            HeartbeatEvent(timeSinceSeriesStart: 0.1, precededByGap: false),
            HeartbeatEvent(timeSinceSeriesStart: 0.9, precededByGap: false),
            HeartbeatEvent(timeSinceSeriesStart: 1.75, precededByGap: false)
        ],
        [
            HeartbeatEvent(timeSinceSeriesStart: 0.8, precededByGap: false),
            HeartbeatEvent(timeSinceSeriesStart: 0.7, precededByGap: false)
        ]
    ])

    #expect(result.usableSeries.count == 1)
    #expect(result.usableSeries[0].seriesIndex == 0)
    #expect(result.usableSeries[0].intervals.map(\.milliseconds) == [800, 850])
    #expect(result.failures.count == 1)
    #expect(result.failures[0].seriesIndex == 1)
    #expect(result.failures[0].reason == .nonIncreasingTime)
    #expect(
        SeriesRMSSDAggregator.calculate(
            from: result.usableSeries.map(\.intervals)
        ) == 50
    )
}
