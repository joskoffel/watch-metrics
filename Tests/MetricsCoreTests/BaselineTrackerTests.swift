import Foundation
import Testing
@testable import MetricsCore

private func day(_ isoDate: String) -> Date {
    ISO8601DateFormatter().date(from: isoDate)!
}

@Test func rollingWindowComputesMedianAndHighConfidenceForCompleteSevenDaySeries() {
    let target = day("2026-07-16T00:00:00Z")
    let dailyValues = [
        // 8 days before target — outside the 7d window, must be excluded
        DailyMetricValue(date: day("2026-07-08T00:00:00Z"), value: 999),
        DailyMetricValue(date: day("2026-07-10T00:00:00Z"), value: 40),
        DailyMetricValue(date: day("2026-07-11T00:00:00Z"), value: 42),
        DailyMetricValue(date: day("2026-07-12T00:00:00Z"), value: 38),
        DailyMetricValue(date: day("2026-07-13T00:00:00Z"), value: 45),
        DailyMetricValue(date: day("2026-07-14T00:00:00Z"), value: 41),
        DailyMetricValue(date: day("2026-07-15T00:00:00Z"), value: 39),
        DailyMetricValue(date: target, value: 43)
    ]

    let result = BaselineTracker.rollingWindow(dailyValues: dailyValues, asOf: target, windowDays: 7)

    #expect(result?.median == 41)
    #expect(result?.confidence == .high)
    #expect(result?.availableDays == 7)
    #expect(result?.windowDays == 7)
}

@Test func rollingWindowReturnsValueWithLowerConfidenceWhenDaysAreMissing() {
    let target = day("2026-07-16T00:00:00Z")
    let dailyValues = [
        DailyMetricValue(date: day("2026-07-10T00:00:00Z"), value: 40),
        DailyMetricValue(date: day("2026-07-11T00:00:00Z"), value: 42),
        DailyMetricValue(date: day("2026-07-13T00:00:00Z"), value: 45),
        DailyMetricValue(date: day("2026-07-15T00:00:00Z"), value: 39),
        DailyMetricValue(date: target, value: 43)
    ]

    let result = BaselineTracker.rollingWindow(dailyValues: dailyValues, asOf: target, windowDays: 7)

    #expect(result?.median == 42)
    #expect(result?.availableDays == 5)
    #expect(result?.confidence == .medium)
    #expect(result?.confidence != .high)
}

@Test func rollingWindowHasLowConfidenceForSingleDayInTwentyEightDayWindow() {
    let target = day("2026-07-16T00:00:00Z")
    let dailyValues = [DailyMetricValue(date: target, value: 50)]

    let result = BaselineTracker.rollingWindow(dailyValues: dailyValues, asOf: target, windowDays: 28)

    #expect(result?.median == 50)
    #expect(result?.availableDays == 1)
    #expect(result?.windowDays == 28)
    #expect(result?.confidence == .low)
}

@Test func rollingWindowReturnsNilForEmptyInput() {
    let target = day("2026-07-16T00:00:00Z")
    #expect(BaselineTracker.rollingWindow(dailyValues: [], asOf: target, windowDays: 7) == nil)
}

@Test func baselineComputesBothSevenDayAndTwentyEightDayWindows() {
    let target = day("2026-07-16T00:00:00Z")
    let dailyValues = (0..<28).map { offset -> DailyMetricValue in
        DailyMetricValue(date: target.addingTimeInterval(-Double(offset) * 86400), value: 40 + Double(offset % 5))
    }

    let baseline = BaselineTracker.baseline(from: dailyValues, asOf: target)

    #expect(baseline.sevenDay?.availableDays == 7)
    #expect(baseline.sevenDay?.confidence == .high)
    #expect(baseline.twentyEightDay?.availableDays == 28)
    #expect(baseline.twentyEightDay?.confidence == .high)
}
