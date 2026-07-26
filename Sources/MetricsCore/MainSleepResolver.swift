import Foundation

/// Picks tonight's "main sleep" — the longest session that finished inside
/// the night window — out of all sessions `SleepSessionBuilder` produced.
public enum MainSleepResolver {
    /// - Parameters:
    ///   - sessions: candidate sessions, any night.
    ///   - window: the night window to consider (e.g. yesterday 18:00 → now).
    ///   - now: current time, used only for the still-asleep check below.
    /// - Returns: the longest eligible session, or `nil` if none qualify or
    ///   the longest candidate looks like it hasn't ended yet (its `end`
    ///   falls within `stillAsleepThreshold` of `now`).
    public static func resolveMainSleep(
        sessions: [SleepSession],
        window: DateInterval,
        now: Date,
        minDuration: TimeInterval = BriefConstants.minMainSleepDuration,
        stillAsleepThreshold: TimeInterval = BriefConstants.stillAsleepThreshold
    ) -> SleepSession? {
        let candidates = sessions
            .filter { $0.end >= window.start && $0.end <= window.end }
            .filter { $0.duration >= minDuration }

        guard let longest = candidates.max(by: { $0.duration < $1.duration }) else {
            return nil
        }

        if now.timeIntervalSince(longest.end) < stillAsleepThreshold {
            return nil
        }

        return longest
    }
}
