import Foundation
import Testing
@testable import MetricsCore

private func t(_ isoDate: String) -> Date {
    ISO8601DateFormatter().date(from: isoDate)!
}

@Test func mainSleepResolverPicksNightOverAfternoonNap() {
    let nap = SleepSession(
        start: t("2026-07-16T14:00:00Z"),
        end: t("2026-07-16T15:30:00Z"),
        asleepDuration: 1.5 * 60 * 60
    )
    let night = SleepSession(
        start: t("2026-07-15T22:00:00Z"),
        end: t("2026-07-16T06:00:00Z"),
        asleepDuration: 8 * 60 * 60
    )
    let window = DateInterval(start: t("2026-07-15T18:00:00Z"), end: t("2026-07-16T16:00:00Z"))

    let main = MainSleepResolver.resolveMainSleep(sessions: [nap, night], window: window, now: t("2026-07-16T16:00:00Z"))

    #expect(main == night)
}

@Test func mainSleepResolverPicksLongerOfTwoSimilarSessions() {
    let sessionA = SleepSession(
        start: t("2026-07-15T22:00:00Z"),
        end: t("2026-07-16T05:30:00Z"),
        asleepDuration: 7.5 * 60 * 60
    )
    let sessionB = SleepSession(
        start: t("2026-07-16T06:00:00Z"),
        end: t("2026-07-16T13:45:00Z"),
        asleepDuration: 7.75 * 60 * 60
    )
    let window = DateInterval(start: t("2026-07-15T18:00:00Z"), end: t("2026-07-16T14:00:00Z"))

    let main = MainSleepResolver.resolveMainSleep(sessions: [sessionA, sessionB], window: window, now: t("2026-07-16T14:00:00Z"))

    #expect(main == sessionB)
}

@Test func mainSleepResolverRanksCandidatesByAsleepDurationNotSessionBounds() {
    let longerBoundsButLessSleep = SleepSession(
        start: t("2026-07-15T21:00:00Z"),
        end: t("2026-07-16T06:00:00Z"),
        asleepDuration: 3 * 60 * 60
    )
    let shorterBoundsButMoreSleep = SleepSession(
        start: t("2026-07-16T00:00:00Z"),
        end: t("2026-07-16T05:00:00Z"),
        asleepDuration: 4.5 * 60 * 60
    )
    let window = DateInterval(start: t("2026-07-15T18:00:00Z"), end: t("2026-07-16T07:00:00Z"))

    let main = MainSleepResolver.resolveMainSleep(
        sessions: [longerBoundsButLessSleep, shorterBoundsButMoreSleep],
        window: window,
        now: t("2026-07-16T07:00:00Z")
    )

    #expect(main == shorterBoundsButMoreSleep)
}

@Test func mainSleepResolverRejectsSessionShorterThanTwoHours() {
    let shortSession = SleepSession(
        start: t("2026-07-16T04:00:00Z"),
        end: t("2026-07-16T05:30:00Z"),
        asleepDuration: 1.5 * 60 * 60
    )
    let window = DateInterval(start: t("2026-07-15T18:00:00Z"), end: t("2026-07-16T06:00:00Z"))

    let main = MainSleepResolver.resolveMainSleep(sessions: [shortSession], window: window, now: t("2026-07-16T06:00:00Z"))

    #expect(main == nil)
}

@Test func mainSleepResolverReturnsNilWhenCandidateEndedTenMinutesAgo() {
    let now = t("2026-07-16T06:00:00Z")
    let stillAsleepCandidate = SleepSession(
        start: t("2026-07-15T22:00:00Z"),
        end: t("2026-07-16T05:50:00Z"),
        asleepDuration: 7.5 * 60 * 60
    )
    let window = DateInterval(start: t("2026-07-15T18:00:00Z"), end: now)

    let main = MainSleepResolver.resolveMainSleep(sessions: [stillAsleepCandidate], window: window, now: now)

    #expect(main == nil)
}

@Test func mainSleepResolverExcludesSessionsEndingOutsideWindow() {
    let now = t("2026-07-16T06:00:00Z")
    let tooEarly = SleepSession(
        start: t("2026-07-14T22:00:00Z"),
        end: t("2026-07-15T06:00:00Z"),
        asleepDuration: 8 * 60 * 60
    )
    let window = DateInterval(start: t("2026-07-15T18:00:00Z"), end: now)

    let main = MainSleepResolver.resolveMainSleep(sessions: [tooEarly], window: window, now: now)

    #expect(main == nil)
}

@Test func mainSleepResolverNeverTreatsHistoricalSessionAsStillAsleepRegardlessOfWindowEndProximity() {
    // Models the night-picker bug: browsing a night from 3 days ago sets
    // `window.end` to "real now minus 3 days", which can land just minutes
    // after that historical night's main sleep ended purely by wall-clock
    // coincidence. `now` must be the real current instant, never
    // `window.end` — otherwise a 3-day-old session reads as still ongoing.
    let historicalSessionEnd = t("2026-07-13T06:55:00Z")
    let historicalWindowEnd = t("2026-07-13T07:00:00Z") // only 5 min after session end
    let realNow = t("2026-07-16T07:00:00Z") // 3 real days later

    let session = SleepSession(
        start: t("2026-07-12T22:00:00Z"),
        end: historicalSessionEnd,
        asleepDuration: 8.5 * 60 * 60
    )
    let window = DateInterval(start: t("2026-07-12T18:00:00Z"), end: historicalWindowEnd)

    let main = MainSleepResolver.resolveMainSleep(sessions: [session], window: window, now: realNow)

    #expect(main == session)
}

@Test func mainSleepResolverHandlesDaylightSavingFallBackWithinWindow() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Bratislava")!

    // Night of 2026-10-24 -> 2026-10-25: clocks fall back 03:00 CEST -> 02:00 CET,
    // so this 22:00->06:00 local stretch spans a real 9h, not the naive 8h.
    let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 22, minute: 0))!
    let end = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 6, minute: 0))!
    let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 7, minute: 0))!
    let windowStart = calendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 18, minute: 0))!

    let session = SleepSession(start: start, end: end, asleepDuration: 9 * 60 * 60)
    let window = DateInterval(start: windowStart, end: now)

    let main = MainSleepResolver.resolveMainSleep(sessions: [session], window: window, now: now)

    #expect(main == session)
    #expect(main?.elapsedDuration == TimeInterval(9 * 60 * 60))
    #expect(main?.asleepDuration == TimeInterval(9 * 60 * 60))
}
