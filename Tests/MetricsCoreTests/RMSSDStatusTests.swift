import Testing
@testable import MetricsCore

private func rollingBaseline(
    median: Double,
    confidence: ConfidenceLevel,
    availableDays: Int,
    windowDays: Int
) -> RollingWindowBaseline {
    RollingWindowBaseline(
        median: median,
        confidence: confidence,
        availableDays: availableDays,
        windowDays: windowDays
    )
}

@Test func rmssdStatusPrefersTwentyEightDayBaseline() {
    let baseline = Baseline(
        sevenDay: rollingBaseline(median: 100, confidence: .medium, availableDays: 6, windowDays: 7),
        twentyEightDay: rollingBaseline(median: 60, confidence: .high, availableDays: 25, windowDays: 28)
    )

    let status = RMSSDStatus.compute(value: 80, baseline: baseline)

    #expect(status == RMSSDStatus(value: 80, level: .high, confidence: .high))
}

@Test func rmssdStatusFallsBackToSevenDayBaseline() {
    let baseline = Baseline(
        sevenDay: rollingBaseline(median: 60, confidence: .medium, availableDays: 5, windowDays: 7),
        twentyEightDay: nil
    )

    let status = RMSSDStatus.compute(value: 50, baseline: baseline)

    #expect(status == RMSSDStatus(value: 50, level: .low, confidence: .medium))
}

@Test func rmssdStatusUsesExistingHRVRelativeConvention() {
    let baseline = Baseline(
        sevenDay: nil,
        twentyEightDay: rollingBaseline(median: 100, confidence: .high, availableDays: 28, windowDays: 28)
    )

    let cases: [(Double, HRVStatusLevel)] = [
        (89, .low),
        (95, .normal),
        (111, .high)
    ]
    for (value, expected) in cases {
        #expect(RMSSDStatus.compute(value: value, baseline: baseline)?.level == expected)
    }
}

@Test func rmssdStatusRequiresNightlyValueAndPersonalBaseline() {
    let baseline = Baseline(
        sevenDay: rollingBaseline(median: 60, confidence: .low, availableDays: 2, windowDays: 7),
        twentyEightDay: nil
    )

    #expect(RMSSDStatus.compute(value: nil, baseline: baseline) == nil)
    #expect(RMSSDStatus.compute(value: 60, baseline: Baseline(sevenDay: nil, twentyEightDay: nil)) == nil)
}

@Test func hrvAgreementMapsSDNNAndRMSSD() {
    let cases: [(HRVStatusLevel, HRVStatusLevel, HRVAgreementInsight)] = [
        (.low, .low, .bothLower),
        (.normal, .normal, .bothTypicalOrHigher),
        (.high, .normal, .bothTypicalOrHigher),
        (.low, .normal, .mixed),
        (.high, .low, .mixed)
    ]

    for (sdnn, rmssd, expected) in cases {
        let sdnnStatus = HRVStatus(value: 50, level: sdnn, confidence: .high)
        let rmssdStatus = RMSSDStatus(value: 50, level: rmssd, confidence: .high)
        #expect(HRVAgreementInsight.evaluate(sdnn: sdnnStatus, rmssd: rmssdStatus) == expected)
    }
}

@Test func hrvAgreementIsInsufficientWithoutComparableRMSSD() {
    let sdnn = HRVStatus(value: 50, level: .normal, confidence: .high)

    #expect(HRVAgreementInsight.evaluate(sdnn: sdnn, rmssd: nil) == .insufficientRMSSD)
}

@Test func rmssdCompositionDoesNotMutateSDNNStatus() {
    let sdnn = HRVStatus(value: 42, level: .low, confidence: .medium)
    let rmssd = RMSSDStatus(value: 38, level: .high, confidence: .high)

    _ = HRVAgreementInsight.evaluate(sdnn: sdnn, rmssd: rmssd)

    #expect(sdnn == HRVStatus(value: 42, level: .low, confidence: .medium))
}
