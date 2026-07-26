import Foundation
import Testing
@testable import WatchMetricsSupport

@Test func auditSummaryCountsCoverageAndUsesRobustMedians() {
    let records = [
        NightAuditFacts(sdnnSampleCount: 2, heartbeatSeriesCount: 3, rawRRCount: 30, acceptedRRCount: 27, hasRMSSD: true),
        NightAuditFacts(sdnnSampleCount: 0, heartbeatSeriesCount: 1, rawRRCount: 4, acceptedRRCount: 2, hasRMSSD: true),
        NightAuditFacts(sdnnSampleCount: 1, heartbeatSeriesCount: 0, rawRRCount: 0, acceptedRRCount: 0, hasRMSSD: false)
    ]

    let summary = HRVDataAuditSummary.compute(from: records)

    #expect(summary?.sleepNightCount == 3)
    #expect(summary?.sdnnNightCount == 2)
    #expect(summary?.rmssdNightCount == 2)
    #expect(summary?.medianSeriesPerNight == 1)
    #expect(summary?.medianAcceptedRRPerNight == 2)
}

@Test func auditSummaryIsNilWithoutResolvedNights() {
    #expect(HRVDataAuditSummary.compute(from: []) == nil)
}
