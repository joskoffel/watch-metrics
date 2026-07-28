import Foundation
import Testing
@testable import MetricsCore

private func fallbackCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

private func fallbackDate(_ calendar: Calendar, day: Int, hour: Int, minute: Int) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour, minute: minute))!
}

@Test func partialSleepNeverProducesFallbackPlan() {
    let calendar = fallbackCalendar()
    let now = fallbackDate(calendar, day: 16, hour: 6, minute: 30)
    let partial = SleepSession(
        start: fallbackDate(calendar, day: 15, hour: 23, minute: 0),
        end: fallbackDate(calendar, day: 16, hour: 6, minute: 25),
        asleepDuration: 7 * 60 * 60
    )

    #expect(BriefFallbackPlanning.futurePlan(now: now, calendar: calendar, sessions: [partial]) == nil)
}

@Test func resolvedSleepProducesOnlyPolicyApprovedFutureDeliveryTime() {
    let calendar = fallbackCalendar()
    let now = fallbackDate(calendar, day: 16, hour: 6, minute: 30)
    let main = SleepSession(
        start: fallbackDate(calendar, day: 15, hour: 22, minute: 0),
        end: fallbackDate(calendar, day: 16, hour: 6, minute: 10),
        asleepDuration: 8 * 60 * 60
    )

    let plan = BriefFallbackPlanning.futurePlan(now: now, calendar: calendar, sessions: [main])

    #expect(plan?.mainSleepEnd == main.end)
    #expect(plan?.fireDate == fallbackDate(calendar, day: 16, hour: 6, minute: 40))
}

@Test func fallbackPlanDoesNotExistAtOrAfterCutoff() {
    let calendar = fallbackCalendar()
    let main = SleepSession(
        start: fallbackDate(calendar, day: 15, hour: 22, minute: 0),
        end: fallbackDate(calendar, day: 16, hour: 5, minute: 0),
        asleepDuration: 7 * 60 * 60
    )

    #expect(BriefFallbackPlanning.futurePlan(
        now: fallbackDate(calendar, day: 16, hour: 10, minute: 0), calendar: calendar, sessions: [main]
    ) == nil)
}
