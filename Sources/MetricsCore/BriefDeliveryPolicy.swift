import Foundation

/// Why the morning brief was not delivered.
///
/// `.pastCutoff` is produced whenever evaluation happens after the local
/// delivery window has closed. Exactly at the cutoff is still eligible.
public enum SkipReason: Equatable {
    case alreadyDelivered
    case noMainSleep
    case pastCutoff
}

public enum BriefDecision: Equatable {
    case deliver(NightSummary)
    case retry(after: TimeInterval)
    case skip(SkipReason)
}

/// Decides whether, right now, the morning brief should be delivered,
/// retried later, or skipped — see the architecture doc's D1/D2 for why
/// this can't just fire the instant sleep ends.
public enum BriefDeliveryPolicy {
    /// - Parameters:
    ///   - now: current time.
    ///   - calendar: must carry the local time zone — every hour/minute
    ///     boundary below is computed through it, never via
    ///     `addingTimeInterval`, so DST transitions don't shift them.
    ///   - sessions: candidate sleep sessions covering at least the last
    ///     two calendar days.
    ///   - hrv/rhr/spo2: metrics for tonight, computed by the shell for the
    ///     calendar day `now` falls on.
    ///   - isAlreadyDelivered: dedupe check owned by the shell's
    ///     `BriefStore`, called with the resolved main sleep's `end` — never
    ///     with `now`. Main sleep can end just before midnight, putting it
    ///     on a different calendar day than the morning `now` it gets
    ///     checked from; keying dedupe off `now` would then miss a delivery
    ///     that already happened and re-send it. The shell may still do a
    ///     cheap pre-check against `now` *before* calling `evaluate` to
    ///     skip an unnecessary HealthKit fetch — that's a shortcut, not the
    ///     authoritative check, which only happens here, after `main.end`
    ///     is known.
    public static func evaluate(
        now: Date,
        calendar: Calendar,
        sessions: [SleepSession],
        hrv: HRVStatus?,
        rhr: RHRStatus?,
        spo2: SpO2Status?,
        isAlreadyDelivered: (Date) -> Bool
    ) -> BriefDecision {
        let today = calendar.startOfDay(for: now)
        guard
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
            let windowStart = calendar.date(
                bySettingHour: BriefConstants.nightWindowStartHour, minute: 0, second: 0, of: yesterday
            ),
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
            )
        else {
            return .retry(after: BriefConstants.retryInterval)
        }

        guard now <= latestDelivery else {
            return .skip(.pastCutoff)
        }

        let window = DateInterval(start: windowStart, end: max(windowStart, now))

        guard let main = MainSleepResolver.resolveMainSleep(sessions: sessions, window: window, now: now) else {
            return now >= latestDelivery ? .skip(.noMainSleep) : .retry(after: BriefConstants.retryInterval)
        }

        if isAlreadyDelivered(main.end) {
            return .skip(.alreadyDelivered)
        }

        guard let afterWake = calendar.date(
            byAdding: .minute, value: BriefConstants.delayAfterWakeMinutes, to: main.end
        ) else {
            return .retry(after: BriefConstants.retryInterval)
        }
        let deliveryTime = min(max(afterWake, earliestDelivery), latestDelivery)

        if now < deliveryTime {
            return .retry(after: deliveryTime.timeIntervalSince(now))
        }

        if hrv == nil, rhr == nil, spo2 == nil, now < latestDelivery {
            return .retry(after: BriefConstants.retryInterval)
        }

        return .deliver(NightSummary(sleep: main, hrv: hrv, rhr: rhr, spo2: spo2))
    }
}
