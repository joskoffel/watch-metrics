import Foundation
import Testing
@testable import WatchMetricsSupport

private let auditStart = ISO8601DateFormatter().date(from: "2026-07-25T22:00:00Z")!

@Test func heartRateAuditUsesRobustLowAndReportsThirdCoverage() {
    let samples = [
        TimedHeartRate(timestamp: auditStart.addingTimeInterval(600), beatsPerMinute: 39),
        TimedHeartRate(timestamp: auditStart.addingTimeInterval(1200), beatsPerMinute: 52),
        TimedHeartRate(timestamp: auditStart.addingTimeInterval(1800), beatsPerMinute: 53),
        TimedHeartRate(timestamp: auditStart.addingTimeInterval(3 * 3600), beatsPerMinute: 55),
        TimedHeartRate(timestamp: auditStart.addingTimeInterval(5 * 3600), beatsPerMinute: 57),
        TimedHeartRate(timestamp: auditStart.addingTimeInterval(7 * 3600), beatsPerMinute: 58)
    ]

    let result = NightHeartRateAnalyzer.analyze(
        samples: samples,
        interval: DateInterval(start: auditStart, end: auditStart.addingTimeInterval(8 * 3600))
    )

    #expect(result?.sampleCount == 6)
    #expect(result?.median == 54)
    #expect(result?.robustLow != 39)
    #expect(result?.coverage == NightThirdCoverage(first: true, middle: true, last: true))
    #expect(result?.supportsSettlingTrend == true)
}

@Test func sparseHeartRateDoesNotClaimRobustLowOrSettlingTrend() {
    let result = NightHeartRateAnalyzer.analyze(
        samples: [TimedHeartRate(timestamp: auditStart.addingTimeInterval(60), beatsPerMinute: 48)],
        interval: DateInterval(start: auditStart, end: auditStart.addingTimeInterval(8 * 3600))
    )

    #expect(result?.robustLow == nil)
    #expect(result?.supportsSettlingTrend == false)
}
