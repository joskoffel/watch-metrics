import Foundation
import MetricsCore
import Testing
@testable import WatchMetricsSupport

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func date(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
}

@Test func resolvedNightBelongsToMorningWhenSleepEnds() {
    let calendar = utcCalendar()
    let sleep = SleepSession(
        start: date("2026-07-25T22:30:00Z"),
        end: date("2026-07-26T06:30:00Z"),
        asleepDuration: 7.5 * 3600
    )

    let night = ResolvedNight(sleep: sleep, calendar: calendar)

    #expect(night.day == date("2026-07-26T00:00:00Z"))
    #expect(night.interval == DateInterval(start: sleep.start, end: sleep.end))
}

@Test func nightFilteringUsesExactMainSleepIntervalForSDNNAndSpO2() {
    let calendar = utcCalendar()
    let night = ResolvedNight(
        sleep: SleepSession(
            start: date("2026-07-25T22:30:00Z"),
            end: date("2026-07-26T06:30:00Z"),
            asleepDuration: 7.5 * 3600
        ),
        calendar: calendar
    )
    let samples = [
        SensorSample(kind: .heartRateVariabilitySDNN, timestamp: date("2026-07-25T21:00:00Z"), value: 30, unit: .milliseconds),
        SensorSample(kind: .heartRateVariabilitySDNN, timestamp: date("2026-07-25T23:00:00Z"), value: 50, unit: .milliseconds),
        SensorSample(kind: .heartRateVariabilitySDNN, timestamp: date("2026-07-26T05:00:00Z"), value: 70, unit: .milliseconds),
        SensorSample(kind: .oxygenSaturation, timestamp: date("2026-07-26T02:00:00Z"), value: 96, unit: .percent),
        SensorSample(kind: .oxygenSaturation, timestamp: date("2026-07-26T08:00:00Z"), value: 88, unit: .percent)
    ]

    #expect(NightMetricMapper.samples(samples, kind: .heartRateVariabilitySDNN, in: night).map(\.value) == [50, 70])
    #expect(NightMetricMapper.samples(samples, kind: .oxygenSaturation, in: night).map(\.value) == [96])
}

@Test func historicalNightsKeepTheirOwnIntervals() {
    let calendar = utcCalendar()
    let sessions = [
        SleepSession(
            start: date("2026-07-24T22:00:00Z"),
            end: date("2026-07-25T06:00:00Z"),
            asleepDuration: 8 * 3600
        ),
        SleepSession(
            start: date("2026-07-25T23:00:00Z"),
            end: date("2026-07-26T07:00:00Z"),
            asleepDuration: 8 * 3600
        )
    ]

    let first = NightWindowResolver.resolve(
        referenceDate: date("2026-07-25T10:00:00Z"),
        sessions: sessions,
        calendar: calendar,
        now: date("2026-07-27T12:00:00Z")
    )
    let second = NightWindowResolver.resolve(
        referenceDate: date("2026-07-26T10:00:00Z"),
        sessions: sessions,
        calendar: calendar,
        now: date("2026-07-27T12:00:00Z")
    )

    #expect(first?.sleep == sessions[0])
    #expect(second?.sleep == sessions[1])
}

@Test func nightResolutionHandlesDSTSpringForwardWithExplicitCalendar() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let formatter = ISO8601DateFormatter()
    let sleep = SleepSession(
        start: formatter.date(from: "2026-03-08T04:30:00Z")!,
        end: formatter.date(from: "2026-03-08T11:30:00Z")!,
        asleepDuration: 6.5 * 3600
    )

    let night = NightWindowResolver.resolve(
        referenceDate: formatter.date(from: "2026-03-08T14:00:00Z")!,
        sessions: [sleep],
        calendar: calendar,
        now: formatter.date(from: "2026-03-09T14:00:00Z")!
    )

    #expect(night?.sleep == sleep)
    #expect(calendar.component(.day, from: night!.day) == 8)
}
