import Foundation
import Testing
@testable import MetricsCore

private func day(_ isoDate: String) -> Date {
    ISO8601DateFormatter().date(from: isoDate)!
}

private func sdnnSample(_ value: Double, at isoDate: String) -> SensorSample {
    SensorSample(kind: .heartRateVariabilitySDNN, timestamp: day(isoDate), value: value, unit: .milliseconds)
}

@Test func hrvStatusComputesFromDailySamplesAgainstBaseline() {
    // Today's SDNN samples: [30, 32, 28, 31, 29] -> sorted [28,29,30,31,32] -> median 30
    let samples = [30.0, 32.0, 28.0, 31.0, 29.0].enumerated().map {
        sdnnSample($1, at: "2026-07-16T0\($0):00:00Z")
    }
    let baseline = Baseline(
        sevenDay: RollingWindowBaseline(median: 41, confidence: .high, availableDays: 7, windowDays: 7),
        twentyEightDay: RollingWindowBaseline(median: 42, confidence: .high, availableDays: 28, windowDays: 28)
    )

    let status = HRVStatus.compute(from: samples, baseline: baseline)

    // deviation = (30-42)/42 ≈ -28.6%, well past the -10% threshold
    #expect(status?.value == 30)
    #expect(status?.level == .low)
    #expect(status?.confidence == .high)
}

@Test func hrvStatusReturnsNilWhenNoSDNNSamplesForTheDay() {
    let baseline = Baseline(
        sevenDay: RollingWindowBaseline(median: 40, confidence: .high, availableDays: 7, windowDays: 7),
        twentyEightDay: RollingWindowBaseline(median: 40, confidence: .high, availableDays: 28, windowDays: 28)
    )

    #expect(HRVStatus.compute(from: [], baseline: baseline) == nil)
}

@Test func hrvStatusReflectsLowConfidenceFromThinBaseline() {
    let samples = [34.0, 35.0, 36.0].enumerated().map { sdnnSample($1, at: "2026-07-16T0\($0):00:00Z") }
    let baseline = Baseline(
        sevenDay: nil,
        twentyEightDay: RollingWindowBaseline(median: 34, confidence: .low, availableDays: 2, windowDays: 28)
    )

    let status = HRVStatus.compute(from: samples, baseline: baseline)

    // median 35 vs baseline 34 -> deviation ≈ +2.9%, within ±10% -> normal,
    // but confidence must still reflect the thin (2/28-day) baseline behind it
    #expect(status?.value == 35)
    #expect(status?.level == .normal)
    #expect(status?.confidence == .low)
}

@Test func hrvStatusFallsBackToSevenDayBaselineWhenTwentyEightDayMissing() {
    let samples = [24.0, 25.0, 26.0].enumerated().map { sdnnSample($1, at: "2026-07-16T0\($0):00:00Z") }
    let baseline = Baseline(
        sevenDay: RollingWindowBaseline(median: 30, confidence: .medium, availableDays: 5, windowDays: 7),
        twentyEightDay: nil
    )

    let status = HRVStatus.compute(from: samples, baseline: baseline)

    // median 25 vs 7d baseline 30 -> deviation ≈ -16.7%, below -10% -> low
    #expect(status?.value == 25)
    #expect(status?.level == .low)
    #expect(status?.confidence == .medium)
}

@Test func hrvStatusDetectsHighWhenMedianIsWellAboveBaseline() {
    let samples = [49.0, 50.0, 51.0].enumerated().map { sdnnSample($1, at: "2026-07-16T0\($0):00:00Z") }
    let baseline = Baseline(
        sevenDay: nil,
        twentyEightDay: RollingWindowBaseline(median: 40, confidence: .high, availableDays: 28, windowDays: 28)
    )

    let status = HRVStatus.compute(from: samples, baseline: baseline)

    // median 50 vs baseline 40 -> deviation = +25%, above +10% -> high
    // (proves the threshold logic is symmetric, not just "below is low, else normal")
    #expect(status?.value == 50)
    #expect(status?.level == .high)
    #expect(status?.confidence == .high)
}
