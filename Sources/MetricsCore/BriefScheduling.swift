import Foundation

/// When to arm the next `WKApplication.scheduleBackgroundRefresh` call,
/// given the complete result of the most recent attempt. Kept separate from
/// `BriefDeliveryPolicy` because notification delivery can fail after a
/// `.deliver` decision and must still schedule a retry.
public enum BriefScheduling {
    /// Whether activating the app should immediately run the authoritative
    /// scheduled brief pipeline. This deliberately shares the delivery
    /// window with `BriefDeliveryPolicy`: foreground is a fallback attempt,
    /// never a second notification mechanism.
    public static func shouldAttemptOnForegroundActivation(now: Date, calendar: Calendar) -> Bool {
        let today = calendar.startOfDay(for: now)
        guard
            let earliest = calendar.date(
                bySettingHour: BriefConstants.earliestDeliveryHour,
                minute: BriefConstants.earliestDeliveryMinute,
                second: 0,
                of: today
            ),
            let latest = calendar.date(
                bySettingHour: BriefConstants.latestDeliveryHour,
                minute: BriefConstants.latestDeliveryMinute,
                second: 0,
                of: today
            )
        else {
            return false
        }
        return now >= earliest && now <= latest
    }

    /// - Parameters:
    ///   - now: current time.
    ///   - calendar: must carry the local time zone, same DST-safety
    ///     requirement as `BriefDeliveryPolicy.evaluate`.
    ///   - result: the result of the complete most recent attempt, or `nil`
    ///     if there isn't one yet (e.g. scheduling the first background task
    ///     at app launch).
    public static func nextRefreshDate(now: Date, calendar: Calendar, result: BriefRunResult?) -> Date {
        switch result {
        case .policyRetry(let after), .notificationFailed(let after):
            return retryDate(now: now, calendar: calendar, after: after)
        case .delivered, .policySkip:
            // Today's cycle is over (delivered, or given up on for today) —
            // nothing to check again until tomorrow's earliest possible
            // delivery; waking any earlier would just retry into the same
            // "no main sleep yet" or "already delivered" result.
            return tomorrowsEarliestDelivery(from: now, calendar: calendar)
        case nil:
            return firstRefreshDate(from: now, calendar: calendar)
        }
    }

    private static func retryDate(now: Date, calendar: Calendar, after: TimeInterval) -> Date {
        let proposed = now.addingTimeInterval(after)
        let today = calendar.startOfDay(for: now)
        guard let cutoff = calendar.date(
            bySettingHour: BriefConstants.latestDeliveryHour,
            minute: BriefConstants.latestDeliveryMinute,
            second: 0,
            of: today
        ) else {
            return proposed
        }

        return proposed <= cutoff
            ? proposed
            : tomorrowsEarliestDelivery(from: now, calendar: calendar)
    }

    private static func firstRefreshDate(from now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        guard
            let earliest = calendar.date(bySettingHour: BriefConstants.earliestDeliveryHour, minute: BriefConstants.earliestDeliveryMinute, second: 0, of: today),
            let latest = calendar.date(bySettingHour: BriefConstants.latestDeliveryHour, minute: BriefConstants.latestDeliveryMinute, second: 0, of: today)
        else {
            return now.addingTimeInterval(BriefConstants.retryInterval)
        }
        if now < earliest { return earliest }
        if now > latest { return tomorrowsEarliestDelivery(from: now, calendar: calendar) }
        return retryDate(now: now, calendar: calendar, after: BriefConstants.retryInterval)
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
