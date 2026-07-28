import Foundation

/// A future morning-brief time derived from a D1-resolved main sleep.
/// This is deliberately pure: the app shell may use it to arm a local
/// notification fallback, but it carries no notification or storage policy.
public struct BriefFallbackPlan: Equatable {
    public let mainSleep: SleepSession
    public let fireDate: Date

    public init(mainSleep: SleepSession, fireDate: Date) {
        self.mainSleep = mainSleep
        self.fireDate = fireDate
    }

    public var mainSleepEnd: Date { mainSleep.end }
}

/// Exposes the exact D1-safe future delivery time used by the brief policy.
/// It returns `nil` for partial/provisional sleep, after the cutoff, or once
/// the policy-approved delivery time has arrived. Callers must not substitute
/// their own timing when this returns `nil`.
public enum BriefFallbackPlanning {
    public static func futurePlan(now: Date, calendar: Calendar, sessions: [SleepSession]) -> BriefFallbackPlan? {
        let today = calendar.startOfDay(for: now)
        guard
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
            let windowStart = calendar.date(
                bySettingHour: BriefConstants.nightWindowStartHour, minute: 0, second: 0, of: yesterday
            ),
            let latestDelivery = cutoff(now: now, calendar: calendar),
            now < latestDelivery
        else {
            return nil
        }

        let window = DateInterval(start: windowStart, end: max(windowStart, now))
        guard let main = MainSleepResolver.resolveMainSleep(sessions: sessions, window: window, now: now) else {
            return nil
        }
        guard let deliveryTime = deliveryDate(for: main, now: now, calendar: calendar) else { return nil }
        guard deliveryTime > now else { return nil }
        return BriefFallbackPlan(mainSleep: main, fireDate: deliveryTime)
    }

    /// The policy-approved delivery date for an already D1-resolved main
    /// sleep. Unlike `futurePlan`, it may return a time equal to or before
    /// `now`, which is needed by `BriefDeliveryPolicy` to decide delivery.
    public static func deliveryDate(for main: SleepSession, now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        guard
            let earliestDelivery = calendar.date(
                bySettingHour: BriefConstants.earliestDeliveryHour,
                minute: BriefConstants.earliestDeliveryMinute,
                second: 0,
                of: today
            ),
            let latestDelivery = calendar.date(
                bySettingHour: BriefConstants.latestDeliveryHour,
                minute: BriefConstants.latestDeliveryMinute,
                second: 0,
                of: today
            ),
            let afterWake = calendar.date(byAdding: .minute, value: BriefConstants.delayAfterWakeMinutes, to: main.end)
        else {
            return nil
        }
        return min(max(afterWake, earliestDelivery), latestDelivery)
    }

    private static func cutoff(now: Date, calendar: Calendar) -> Date? {
        calendar.date(
            bySettingHour: BriefConstants.latestDeliveryHour,
            minute: BriefConstants.latestDeliveryMinute,
            second: 0,
            of: calendar.startOfDay(for: now)
        )
    }
}
