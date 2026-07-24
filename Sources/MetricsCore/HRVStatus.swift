/// Today's HRV status relative to the personal baseline, expressed as a
/// simple direction (`low`/`normal`/`high`), not a numeric deviation.
public enum HRVStatusLevel: Equatable {
    case low
    case normal
    case high
}

/// M1/M2 — daily HRV status: a day's median SDNN compared against the
/// 7d/28d rolling baseline from `BaselineTracker`.
///
/// Uses SDNN, not RMSSD: real RR intervals aren't available yet (pending
/// `HKHeartbeatSeriesQuery` verification — see docs/data-availability-report.md),
/// so SDNN samples from the Health export are the only real daily HRV
/// signal today.
public struct HRVStatus: Equatable {
    public let value: Double
    public let level: HRVStatusLevel
    public let confidence: ConfidenceLevel

    public init(value: Double, level: HRVStatusLevel, confidence: ConfidenceLevel) {
        self.value = value
        self.level = level
        self.confidence = confidence
    }

    /// How far today's median SDNN may deviate from the baseline median
    /// before being flagged `low`/`high` instead of `normal`.
    ///
    /// TODO: placeholder heuristic, not a sourced clinical threshold — needs
    /// empirical calibration once real longitudinal day-to-day SDNN
    /// variance data exists (e.g. derived per-user from their own history)
    /// rather than a fixed constant for everyone.
    public static let normalRangeFraction: Double = 0.10

    /// Computes today's HRV status from a day's raw samples and the current
    /// baseline. Returns nil if there's no SDNN sample for the day, or no
    /// baseline window (7d/28d) to compare against at all — an absence of
    /// data, not an error.
    public static func compute(from samples: [SensorSample], baseline: Baseline) -> HRVStatus? {
        let sdnnValues = samples
            .filter { $0.kind == .heartRateVariabilitySDNN }
            .map(\.value)
            .sorted()
        guard !sdnnValues.isEmpty else { return nil }
        let todayMedian = BaselineTracker.median(of: sdnnValues)

        guard let referenceWindow = baseline.twentyEightDay ?? baseline.sevenDay else {
            return nil
        }

        let deviation = (todayMedian - referenceWindow.median) / referenceWindow.median
        let level: HRVStatusLevel
        if deviation <= -normalRangeFraction {
            level = .low
        } else if deviation >= normalRangeFraction {
            level = .high
        } else {
            level = .normal
        }

        return HRVStatus(value: todayMedian, level: level, confidence: referenceWindow.confidence)
    }
}
