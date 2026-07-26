import Foundation
import Testing
@testable import MetricsCore

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

/// `day` is the day-of-month in July 2026; `today` in every test is July 16.
private func at(_ calendar: Calendar, day: Int, hour: Int, minute: Int) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour, minute: minute))!
}

@Test func briefDeliveryPolicySkipsWhenAlreadyDelivered() {
    let calendar = utcCalendar()
    let main = SleepSession(
        start: at(calendar, day: 15, hour: 22, minute: 0),
        end: at(calendar, day: 16, hour: 5, minute: 0),
        asleepDuration: 7 * 60 * 60
    )
    let now = at(calendar, day: 16, hour: 7, minute: 0)

    let decision = BriefDeliveryPolicy.evaluate(
        now: now, calendar: calendar, sessions: [main], hrv: nil, rhr: nil, spo2: nil,
        isAlreadyDelivered: { _ in true }
    )

    #expect(decision == .skip(.alreadyDelivered))
}

@Test func briefDeliveryPolicyDedupeChecksMainSleepEndNotNow() {
    // Main sleep ends 23:15 on day 16 (before midnight); a prior run already
    // delivered for that day. The next morning's check runs with `now` on
    // day 17 — a naive dedupe keyed on `now`'s calendar day would miss the
    // stored "day 16" key and re-deliver. The authoritative check must key
    // off `main.end`, which is still day 16, regardless of `now`.
    let calendar = utcCalendar()
    let mainSleepEnd = at(calendar, day: 16, hour: 23, minute: 15)
    let main = SleepSession(
        start: at(calendar, day: 16, hour: 21, minute: 0),
        end: mainSleepEnd,
        asleepDuration: 2.25 * 60 * 60
    )
    let deliveredDay = calendar.dateComponents([.year, .month, .day], from: mainSleepEnd)

    let now = at(calendar, day: 17, hour: 6, minute: 30)

    let decision = BriefDeliveryPolicy.evaluate(
        now: now, calendar: calendar, sessions: [main], hrv: nil, rhr: nil, spo2: nil,
        isAlreadyDelivered: { date in calendar.dateComponents([.year, .month, .day], from: date) == deliveredDay }
    )

    #expect(decision == .skip(.alreadyDelivered))
}

@Test func briefDeliveryPolicyRetriesBeforeDeliveryTime() {
    let calendar = utcCalendar()
    let main = SleepSession(
        start: at(calendar, day: 15, hour: 22, minute: 0),
        end: at(calendar, day: 16, hour: 5, minute: 0),
        asleepDuration: 7 * 60 * 60
    )
    let now = at(calendar, day: 16, hour: 6, minute: 0) // main.end + 1h, still before 06:30 floor

    let decision = BriefDeliveryPolicy.evaluate(
        now: now, calendar: calendar, sessions: [main], hrv: nil, rhr: nil, spo2: nil,
        isAlreadyDelivered: { _ in false }
    )

    #expect(decision == .retry(after: 30 * 60))
}

@Test func briefDeliveryPolicySkipsWhenNoMainSleepPastCutoff() {
    let calendar = utcCalendar()
    let now = at(calendar, day: 16, hour: 10, minute: 0)

    let decision = BriefDeliveryPolicy.evaluate(
        now: now, calendar: calendar, sessions: [], hrv: nil, rhr: nil, spo2: nil,
        isAlreadyDelivered: { _ in false }
    )

    #expect(decision == .skip(.noMainSleep))
}

@Test func briefDeliveryPolicyRetriesWhenNoMainSleepBeforeCutoff() {
    let calendar = utcCalendar()
    let now = at(calendar, day: 16, hour: 8, minute: 0)

    let decision = BriefDeliveryPolicy.evaluate(
        now: now, calendar: calendar, sessions: [], hrv: nil, rhr: nil, spo2: nil,
        isAlreadyDelivered: { _ in false }
    )

    #expect(decision == .retry(after: 30 * 60))
}

@Test func briefDeliveryPolicyDeliversPartialSummaryExactlyAtCutoff() {
    let calendar = utcCalendar()
    let main = SleepSession(
        start: at(calendar, day: 15, hour: 22, minute: 0),
        end: at(calendar, day: 16, hour: 5, minute: 0),
        asleepDuration: 7 * 60 * 60
    )
    let now = at(calendar, day: 16, hour: 10, minute: 0)

    let decision = BriefDeliveryPolicy.evaluate(
        now: now, calendar: calendar, sessions: [main],
        hrv: HRVStatus(value: 48, level: .normal, confidence: .high), rhr: nil, spo2: nil,
        isAlreadyDelivered: { _ in false }
    )

    #expect(decision == .deliver(NightSummary(sleep: main, hrv: HRVStatus(value: 48, level: .normal, confidence: .high), rhr: nil, spo2: nil)))
}

@Test func briefDeliveryPolicyEarlyWakeWaitsUntilSixThirty() {
    let calendar = utcCalendar()
    let main = SleepSession(
        start: at(calendar, day: 15, hour: 21, minute: 0),
        end: at(calendar, day: 16, hour: 5, minute: 0),
        asleepDuration: 8 * 60 * 60
    )

    let beforeFloor = at(calendar, day: 16, hour: 6, minute: 0)
    let retryDecision = BriefDeliveryPolicy.evaluate(
        now: beforeFloor, calendar: calendar, sessions: [main], hrv: nil, rhr: nil, spo2: nil,
        isAlreadyDelivered: { _ in false }
    )
    #expect(retryDecision == .retry(after: 30 * 60)) // 06:30 - 06:00

    let atFloor = at(calendar, day: 16, hour: 6, minute: 30)
    let deliverDecision = BriefDeliveryPolicy.evaluate(
        now: atFloor, calendar: calendar, sessions: [main],
        hrv: HRVStatus(value: 48, level: .normal, confidence: .high), rhr: nil, spo2: nil,
        isAlreadyDelivered: { _ in false }
    )
    #expect(deliverDecision == .deliver(NightSummary(sleep: main, hrv: HRVStatus(value: 48, level: .normal, confidence: .high), rhr: nil, spo2: nil)))
}

@Test func briefDeliveryPolicyLateWakeNeverDeliversAfterTen() {
    let calendar = utcCalendar()
    // Wakes at 09:45, so naive "end + 30min" would be 10:15 — must clamp to 10:00.
    let main = SleepSession(
        start: at(calendar, day: 15, hour: 22, minute: 0),
        end: at(calendar, day: 16, hour: 9, minute: 45),
        asleepDuration: 11.75 * 60 * 60
    )
    let now = at(calendar, day: 16, hour: 10, minute: 0) // exactly 15 min after end: no longer "still asleep"

    let decision = BriefDeliveryPolicy.evaluate(
        now: now, calendar: calendar, sessions: [main],
        hrv: HRVStatus(value: 48, level: .normal, confidence: .high), rhr: nil, spo2: nil,
        isAlreadyDelivered: { _ in false }
    )

    #expect(decision == .deliver(NightSummary(sleep: main, hrv: HRVStatus(value: 48, level: .normal, confidence: .high), rhr: nil, spo2: nil)))
}

@Test func briefDeliveryPolicySkipsExistingMainSleepAfterCutoff() {
    let calendar = utcCalendar()
    let main = SleepSession(
        start: at(calendar, day: 15, hour: 22, minute: 0),
        end: at(calendar, day: 16, hour: 6, minute: 0),
        asleepDuration: 8 * 60 * 60
    )
    let now = at(calendar, day: 16, hour: 10, minute: 1)

    let decision = BriefDeliveryPolicy.evaluate(
        now: now,
        calendar: calendar,
        sessions: [main],
        hrv: HRVStatus(value: 48, level: .normal, confidence: .high),
        rhr: nil,
        spo2: nil,
        isAlreadyDelivered: { _ in false }
    )

    #expect(decision == .skip(.pastCutoff))
}
