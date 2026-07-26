import Foundation

/// When to arm the next `WKApplication.scheduleBackgroundRefresh` call,
/// given the most recent `BriefDeliveryPolicy` decision. Kept separate from
/// `BriefDeliveryPolicy` itself since it answers a different question ("when
/// should the *next background task* fire") from the policy's ("what should
/// happen *right now*").
public enum BriefScheduling {
    /// - Parameters:
    ///   - now: current time.
    ///   - calendar: must carry the local time zone, same DST-safety
    ///     requirement as `BriefDeliveryPolicy.evaluate`.
    ///   - decision: the result of the most recent `BriefDeliveryPolicy`
    ///     evaluation, or `nil` if there isn't one yet (e.g. scheduling the
    ///     very first background task at app launch).
    public static func nextRefreshDate(now: Date, calendar: Calendar, decision: BriefDecision?) -> Date {
        switch decision {
        case .retry(let after):
            return now.addingTimeInterval(after)
        case .deliver, .skip:
            // Today's cycle is over (delivered, or given up on for today) —
            // nothing to check again until tomorrow's earliest possible
            // delivery; waking any earlier would just retry into the same
            // "no main sleep yet" or "already delivered" result.
            return tomorrowsEarliestDelivery(from: now, calendar: calendar)
        case nil:
            // No prior decision to react to — check again soon and let that
            // first real evaluation drive the retry ladder from there,
            // rather than trying to guess today-vs-tomorrow here.
            return now.addingTimeInterval(BriefConstants.retryInterval)
        }
    }

    private static func tomorrowsEarliestDelivery(from now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        guard
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
            let next = calendar.date(
                bySettingHour: BriefConstants.earliestDeliveryHour,
                minute: BriefConstants.earliestDeliveryMinute,
                second: 0,
                of: tomorrow
            )
        else {
            return now.addingTimeInterval(BriefConstants.retryInterval)
        }
        return next
    }
}
