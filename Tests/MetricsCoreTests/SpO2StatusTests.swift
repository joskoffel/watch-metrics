import Foundation
import Testing
@testable import MetricsCore

private func day(_ isoDate: String) -> Date {
    ISO8601DateFormatter().date(from: isoDate)!
}

private func spo2Sample(_ value: Double, at isoDate: String) -> SensorSample {
    SensorSample(kind: .oxygenSaturation, timestamp: day(isoDate), value: value, unit: .percent)
}

@Test func spo2StatusIsNormalWhenValueIsWithinNormalRange() {
    let samples = [96.5, 97.0, 97.5].enumerated().map { spo2Sample($1, at: "2026-07-16T0\($0):00:00Z") }
    let baseline = Baseline(
        sevenDay: RollingWindowBaseline(median: 96, confidence: .high, availableDays: 7, windowDays: 7),
        twentyEightDay: RollingWindowBaseline(median: 96, confidence: .high, availableDays: 28, windowDays: 28)
    )

    let status = SpO2Status.compute(from: samples, baseline: baseline)

    #expect(status?.value == 97.0)
    #expect(status?.level == .normal)
    #expect(status?.confidence == .high)
}

@Test func spo2StatusIsLowWhenValueIsBetweenNinetyAndNinetyFivePercent() {
    let samples = [91.5, 92.0, 92.5].enumerated().map { spo2Sample($1, at: "2026-07-16T0\($0):00:00Z") }
    let baseline = Baseline(
        sevenDay: RollingWindowBaseline(median: 96, confidence: .high, availableDays: 7, windowDays: 7),
        twentyEightDay: RollingWindowBaseline(median: 96, confidence: .high, availableDays: 28, windowDays: 28)
    )

    let status = SpO2Status.compute(from: samples, baseline: baseline)

    #expect(status?.value == 92.0)
    #expect(status?.level == .low)
}

@Test func spo2StatusIsCriticalWhenValueIsBelowNinetyPercent() {
    let samples = [86.5, 87.0, 87.5].enumerated().map { spo2Sample($1, at: "2026-07-16T0\($0):00:00Z") }
    let baseline = Baseline(
        sevenDay: RollingWindowBaseline(median: 96, confidence: .high, availableDays: 7, windowDays: 7),
        twentyEightDay: RollingWindowBaseline(median: 96, confidence: .high, availableDays: 28, windowDays: 28)
    )

    let status = SpO2Status.compute(from: samples, baseline: baseline)

    #expect(status?.value == 87.0)
    #expect(status?.level == .critical)
}

@Test func spo2StatusBoundaryAtNinetyFivePercentIsNormal() {
    let samples = [95.0, 95.0, 95.0].enumerated().map { spo2Sample($1, at: "2026-07-16T0\($0):00:00Z") }
    let baseline = Baseline(
        sevenDay: nil,
        twentyEightDay: RollingWindowBaseline(median: 96, confidence: .high, availableDays: 28, windowDays: 28)
    )

    let status = SpO2Status.compute(from: samples, baseline: baseline)

    #expect(status?.value == 95.0)
    #expect(status?.level == .normal)
}

@Test func spo2StatusBoundaryAtNinetyPercentIsLowNotCritical() {
    let samples = [90.0, 90.0, 90.0].enumerated().map { spo2Sample($1, at: "2026-07-16T0\($0):00:00Z") }
    let baseline = Baseline(
        sevenDay: nil,
        twentyEightDay: RollingWindowBaseline(median: 96, confidence: .high, availableDays: 28, windowDays: 28)
    )

    let status = SpO2Status.compute(from: samples, baseline: baseline)

    #expect(status?.value == 90.0)
    #expect(status?.level == .low)
}

@Test func spo2StatusJustBelowNinetyFivePercentIsLow() {
    let samples = [94.9, 94.9, 94.9].enumerated().map { spo2Sample($1, at: "2026-07-16T0\($0):00:00Z") }
    let baseline = Baseline(
        sevenDay: nil,
        twentyEightDay: RollingWindowBaseline(median: 96, confidence: .high, availableDays: 28, windowDays: 28)
    )

    let status = SpO2Status.compute(from: samples, baseline: baseline)

    #expect(status?.value == 94.9)
    #expect(status?.level == .low)
}

@Test func spo2StatusJustBelowNinetyPercentIsCritical() {
    let samples = [89.9, 89.9, 89.9].enumerated().map { spo2Sample($1, at: "2026-07-16T0\($0):00:00Z") }
    let baseline = Baseline(
        sevenDay: nil,
        twentyEightDay: RollingWindowBaseline(median: 96, confidence: .high, availableDays: 28, windowDays: 28)
    )

    let status = SpO2Status.compute(from: samples, baseline: baseline)

    #expect(status?.value == 89.9)
    #expect(status?.level == .critical)
}

@Test func spo2StatusReturnsNilWhenNoSamplesForTheDay() {
    let baseline = Baseline(
        sevenDay: RollingWindowBaseline(median: 96, confidence: .high, availableDays: 7, windowDays: 7),
        twentyEightDay: RollingWindowBaseline(median: 96, confidence: .high, availableDays: 28, windowDays: 28)
    )

    #expect(SpO2Status.compute(from: [], baseline: baseline) == nil)
}

@Test func spo2StatusReflectsLowConfidenceFromThinBaseline() {
    let samples = [91.5, 92.0, 92.5].enumerated().map { spo2Sample($1, at: "2026-07-16T0\($0):00:00Z") }
    let baseline = Baseline(
        sevenDay: nil,
        twentyEightDay: RollingWindowBaseline(median: 95, confidence: .low, availableDays: 2, windowDays: 28)
    )

    let status = SpO2Status.compute(from: samples, baseline: baseline)

    // level comes from the absolute value (92% -> low), independent of the
    // baseline's own median or confidence; confidence just reflects the
    // thin (2/28-day) baseline behind the trend context, not the level.
    #expect(status?.value == 92.0)
    #expect(status?.level == .low)
    #expect(status?.confidence == .low)
}

@Test func spo2StatusComputesLevelEvenWithoutAnyBaselineHistory() {
    let samples = [86.5, 87.0, 87.5].enumerated().map { spo2Sample($1, at: "2026-07-16T0\($0):00:00Z") }
    let baseline = Baseline(sevenDay: nil, twentyEightDay: nil)

    let status = SpO2Status.compute(from: samples, baseline: baseline)

    // No baseline at all (brand-new user) must NOT suppress a clinically
    // meaningful critical reading — level is absolute, not baseline-relative.
    #expect(status?.value == 87.0)
    #expect(status?.level == .critical)
    #expect(status?.confidence == .low)
}
