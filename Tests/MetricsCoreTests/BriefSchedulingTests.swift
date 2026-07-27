import Foundation
import Testing
@testable import MetricsCore

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

private func at(_ calendar: Calendar, year: Int = 2026, month: Int = 7, day: Int, hour: Int, minute: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

@Test func briefSchedulingRetryDecisionSchedulesAfterTheGivenDelay() {
    let calendar = utcCalendar()
    let now = at(calendar, day: 16, hour: 6, minute: 0)

    let next = BriefScheduling.nextRefreshDate(
        now: now,
        calendar: calendar,
        result: .policyRetry(after: 30 * 60)
    )

    #expect(next == at(calendar, day: 16, hour: 6, minute: 30))
}

@Test func briefSchedulingNotificationFailureRetriesWithinTodaysWindow() {
    let calendar = utcCalendar()
    let now = at(calendar, day: 16, hour: 9, minute: 0)

    let next = BriefScheduling.nextRefreshDate(
        now: now,
        calendar: calendar,
        result: .notificationFailed(retryAfter: 30 * 60)
    )

    #expect(next == at(calendar, day: 16, hour: 9, minute: 30))
}

@Test func briefSchedulingNotificationFailureDoesNotRetryPastCutoff() {
    let calendar = utcCalendar()
    let now = at(calendar, day: 16, hour: 9, minute: 45)

    let next = BriefScheduling.nextRefreshDate(
        now: now,
        calendar: calendar,
        result: .notificationFailed(retryAfter: 30 * 60)
    )

    #expect(next == at(calendar, day: 17, hour: 6, minute: 30))
}

@Test func briefSchedulingPolicyRetryDoesNotCrossCutoff() {
    let calendar = utcCalendar()
    let now = at(calendar, day: 16, hour: 9, minute: 45)

    let next = BriefScheduling.nextRefreshDate(
        now: now,
        calendar: calendar,
        result: .policyRetry(after: 30 * 60)
    )

    #expect(next == at(calendar, day: 17, hour: 6, minute: 30))
}

@Test func briefSchedulingDeliverDecisionSchedulesTomorrowsEarliestDelivery() {
    let calendar = utcCalendar()
    let now = at(calendar, day: 16, hour: 7, minute: 30)

    let next = BriefScheduling.nextRefreshDate(now: now, calendar: calendar, result: .delivered)

    #expect(next == at(calendar, day: 17, hour: 6, minute: 30))
}

@Test func briefSchedulingSkipDecisionSchedulesTomorrowsEarliestDeliveryRegardlessOfReason() {
    let calendar = utcCalendar()
    let now = at(calendar, day: 16, hour: 10, minute: 0)

    let next = BriefScheduling.nextRefreshDate(
        now: now,
        calendar: calendar,
        result: .policySkip(.noMainSleep)
    )

    #expect(next == at(calendar, day: 17, hour: 6, minute: 30))
}

@Test func briefSchedulingFirstRefreshBeforeMorningWindowUsesTodaysEarliestDelivery() {
    let calendar = utcCalendar()
    let now = at(calendar, day: 16, hour: 3, minute: 0)

    let next = BriefScheduling.nextRefreshDate(now: now, calendar: calendar, result: nil)

    #expect(next == at(calendar, day: 16, hour: 6, minute: 30))
}

@Test func briefSchedulingFirstRefreshDuringMorningWindowUsesSafeRetry() {
    let calendar = utcCalendar()
    let now = at(calendar, day: 16, hour: 7, minute: 0)

    let next = BriefScheduling.nextRefreshDate(now: now, calendar: calendar, result: nil)

    #expect(next == at(calendar, day: 16, hour: 7, minute: 30))
}

@Test func briefSchedulingFirstRefreshAfterCutoffUsesTomorrowsEarliestDelivery() {
    let calendar = utcCalendar()
    let now = at(calendar, day: 16, hour: 10, minute: 1)

    let next = BriefScheduling.nextRefreshDate(now: now, calendar: calendar, result: nil)

    #expect(next == at(calendar, day: 17, hour: 6, minute: 30))
}

@Test func foregroundActivationAttemptsOnlyDuringTheMorningDeliveryWindow() {
    let calendar = utcCalendar()

    #expect(BriefScheduling.shouldAttemptOnForegroundActivation(
        now: at(calendar, day: 16, hour: 6, minute: 30), calendar: calendar
    ))
    #expect(BriefScheduling.shouldAttemptOnForegroundActivation(
        now: at(calendar, day: 16, hour: 10, minute: 0), calendar: calendar
    ))
    #expect(!BriefScheduling.shouldAttemptOnForegroundActivation(
        now: at(calendar, day: 16, hour: 6, minute: 29), calendar: calendar
    ))
    #expect(!BriefScheduling.shouldAttemptOnForegroundActivation(
        now: at(calendar, day: 16, hour: 10, minute: 1), calendar: calendar
    ))
}

@Test func foregroundAndBackgroundAttemptsUseTheSameNextRefreshRule() {
    let calendar = utcCalendar()
    let now = at(calendar, day: 16, hour: 7, minute: 0)

    let foregroundNext = BriefScheduling.nextRefreshDate(now: now, calendar: calendar, result: .delivered)
    let backgroundNext = BriefScheduling.nextRefreshDate(now: now, calendar: calendar, result: .delivered)

    #expect(foregroundNext == at(calendar, day: 17, hour: 6, minute: 30))
    #expect(backgroundNext == foregroundNext)
}

@Test func briefSchedulingTomorrowsEarliestDeliverySurvivesDaylightSavingSpringForward() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Bratislava")!

    // Clocks spring forward 02:00 -> 03:00 on 2027-03-28 (last Sunday of March).
    let now = calendar.date(from: DateComponents(year: 2027, month: 3, day: 27, hour: 10, minute: 0))!

    let next = BriefScheduling.nextRefreshDate(
        now: now,
        calendar: calendar,
        result: .policySkip(.noMainSleep)
    )

    let expected = calendar.date(from: DateComponents(year: 2027, month: 3, day: 28, hour: 6, minute: 30))!
    #expect(next == expected)
}
