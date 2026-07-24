/// How much of a rolling window's data is actually present. Kept coarse
/// (not the raw ratio) so downstream consumers can branch on it directly
/// without re-deriving thresholds themselves.
public enum ConfidenceLevel: Equatable {
    case low
    case medium
    case high
}

/// One rolling-window result (e.g. the 7-day or 28-day view), produced by
/// `BaselineTracker`.
public struct RollingWindowBaseline: Equatable {
    public let median: Double
    public let confidence: ConfidenceLevel
    public let availableDays: Int
    public let windowDays: Int

    public init(median: Double, confidence: ConfidenceLevel, availableDays: Int, windowDays: Int) {
        self.median = median
        self.confidence = confidence
        self.availableDays = availableDays
        self.windowDays = windowDays
    }
}

/// The baseline context passed alongside raw samples into a metric function
/// (see CLAUDE.md: "Vstup: pole vzoriek + Baseline"). Either window can be
/// nil when there's no data at all in that window — see `BaselineTracker`.
public struct Baseline: Equatable {
    public let sevenDay: RollingWindowBaseline?
    public let twentyEightDay: RollingWindowBaseline?

    public init(sevenDay: RollingWindowBaseline?, twentyEightDay: RollingWindowBaseline?) {
        self.sevenDay = sevenDay
        self.twentyEightDay = twentyEightDay
    }
}
