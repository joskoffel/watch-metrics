import Foundation

/// Every tunable constant for the morning brief pipeline, in one place so
/// they can be adjusted without hunting through `SleepSessionBuilder`,
/// `MainSleepResolver`, and `BriefDeliveryPolicy` separately.
public enum BriefConstants {
    /// Night window starts at 18:00 the day before.
    public static let nightWindowStartHour: Int = 18

    public static let earliestDeliveryHour: Int = 6
    public static let earliestDeliveryMinute: Int = 30

    public static let latestDeliveryHour: Int = 10
    public static let latestDeliveryMinute: Int = 0

    public static let delayAfterWakeMinutes: Int = 30
    public static let retryInterval: TimeInterval = 30 * 60

    /// Adjacent sleep-stage segments separated by a gap this long or
    /// shorter are merged into one session.
    public static let gapTolerance: TimeInterval = 60 * 60

    /// Sessions shorter than this are treated as naps/noise, not a main
    /// sleep candidate.
    public static let minMainSleepDuration: TimeInterval = 2 * 60 * 60

    /// A candidate session ending within this long before `now` is treated
    /// as still in progress, not finished.
    public static let stillAsleepThreshold: TimeInterval = 15 * 60
}
