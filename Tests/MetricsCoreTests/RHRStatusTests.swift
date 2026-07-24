import Foundation
import Testing
@testable import MetricsCore

private func day(_ isoDate: String) -> Date {
    ISO8601DateFormatter().date(from: isoDate)!
}

private func rhrSample(_ value: Double, at isoDate: String) -> SensorSample {
    SensorSample(kind: .restingHeartRate, timestamp: day(isoDate), value: value, unit: .beatsPerMinute)
}

@Test func rhrStatusIsNormalWhenCloseToBaseline() {
    // Today's RHR samples: [58, 60, 59, 61, 57] -> sorted [57,58,59,60,61] -> median 59
    let samples = [58.0, 60.0, 59.0, 61.0, 57.0].enumerated().map {
        rhrSample($1, at: "2026-07-16T0\($0):00:00Z")
    }
    let baseline = Baseline(
        sevenDay: RollingWindowBaseline(median: 58, confidence: .high, availableDays: 7, windowDays: 7),
        twentyEightDay: RollingWindowBaseline(median: 58, confidence: .high, availableDays: 28, windowDays: 28)
    )

    let status = RHRStatus.compute(from: samples, baseline: baseline)

    // deviation = (59-58)/58 ≈ +1.7%, well within the ±5% band
    #expect(status?.value == 59)
    #expect(status?.level == .normal)
    #expect(status?.confidence == .high)
}

@Test func rhrStatusReturnsNilWhenNoSamplesForTheDay() {
    let baseline = Baseline(
        sevenDay: RollingWindowBaseline(median: 60, confidence: .high, availableDays: 7, windowDays: 7),
        twentyEightDay: RollingWindowBaseline(median: 60, confidence: .high, availableDays: 28, windowDays: 28)
    )

    #expect(RHRStatus.compute(from: [], baseline: baseline) == nil)
}

@Test func rhrStatusReflectsLowConfidenceFromThinBaseline() {
    let samples = [60.0, 61.0, 62.0].enumerated().map { rhrSample($1, at: "2026-07-16T0\($0):00:00Z") }
    let baseline = Baseline(
        sevenDay: nil,
        twentyEightDay: RollingWindowBaseline(median: 60, confidence: .low, availableDays: 2, windowDays: 28)
    )

    let status = RHRStatus.compute(from: samples, baseline: baseline)

    // median 61 vs baseline 60 -> deviation ≈ +1.7%, within ±5% -> normal,
    // but confidence must still reflect the thin (2/28-day) baseline behind it
    #expect(status?.value == 61)
    #expect(status?.level == .normal)
    #expect(status?.confidence == .low)
}

@Test func rhrStatusFallsBackToSevenDayBaselineAndDetectsSuppressed() {
    let samples = [55.0, 56.0, 57.0].enumerated().map { rhrSample($1, at: "2026-07-16T0\($0):00:00Z") }
    let baseline = Baseline(
        sevenDay: RollingWindowBaseline(median: 60, confidence: .medium, availableDays: 5, windowDays: 7),
        twentyEightDay: nil
    )

    let status = RHRStatus.compute(from: samples, baseline: baseline)

    // median 56 vs 7d baseline 60 -> deviation ≈ -6.7%, below -5% -> suppressed
    // (lower-than-baseline RHR — typically good/neutral, not a warning sign)
    #expect(status?.value == 56)
    #expect(status?.level == .suppressed)
    #expect(status?.confidence == .medium)
}

@Test func rhrStatusDetectsElevatedWhenMedianIsWellAboveBaseline() {
    let samples = [71.0, 72.0, 73.0].enumerated().map { rhrSample($1, at: "2026-07-16T0\($0):00:00Z") }
    let baseline = Baseline(
        sevenDay: nil,
        twentyEightDay: RollingWindowBaseline(median: 60, confidence: .high, availableDays: 28, windowDays: 28)
    )

    let status = RHRStatus.compute(from: samples, baseline: baseline)

    // median 72 vs baseline 60 -> deviation = +20%, above +5% -> elevated
    // (higher-than-baseline RHR — the stress/fatigue/illness signal this metric exists to catch)
    #expect(status?.value == 72)
    #expect(status?.level == .elevated)
    #expect(status?.confidence == .high)
}
