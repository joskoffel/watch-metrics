/// Today's RHR status relative to the personal baseline.
///
/// Named distinctly from `HRVStatusLevel` (not reused as `low`/`high`)
/// because the direction of "bad" is inverted between the two metrics: for
/// HRV, low means below baseline (a warning sign) and high just flags a
/// notable increase. For RHR it's the opposite — a resting heart rate
/// *above* baseline is the classic early stress/fatigue/illness signal,
/// while *below* baseline is typically good or neutral (better recovery).
/// Reusing `low`/`high` for both would silently invert what "low" means
/// depending on which metric you're looking at; `elevated`/`suppressed`
/// name the direction without implying which one is good or bad in the
/// abstract, since that judgment is metric-specific.
public enum RHRStatusLevel: Equatable {
    case suppressed
    case normal
    case elevated
}

/// M3 — daily RHR status: a day's median RestingHeartRate compared against
/// the 7d/28d rolling baseline from `BaselineTracker`, same shape as
/// `HRVStatus` (M1/M2).
public struct RHRStatus: Equatable {
    public let value: Double
    public let level: RHRStatusLevel
    public let confidence: ConfidenceLevel

    public init(value: Double, level: RHRStatusLevel, confidence: ConfidenceLevel) {
        self.value = value
        self.level = level
        self.confidence = confidence
    }

    /// How far today's median RHR may deviate from the baseline median
    /// before being flagged `elevated`/`suppressed` instead of `normal`.
    ///
    /// Tighter than `HRVStatus.normalRangeFraction` (±10%) deliberately:
    /// resting heart rate is physiologically far more stable day-to-day
    /// than HRV — a normal night-to-night RHR fluctuation is typically a
    /// few bpm, not the 10-20%+ swings routine for SDNN/RMSSD. Using the
    /// same ±10% band here would mute the early stress/illness signal this
    /// metric exists to catch. Still a placeholder heuristic (see
    /// HRVStatus's TODO) pending empirical calibration from real
    /// longitudinal data, not a sourced clinical threshold.
    public static let normalRangeFraction: Double = 0.05

    /// Computes today's RHR status from a day's raw samples and the current
    /// baseline. Returns nil if there's no RestingHeartRate sample for the
    /// day, or no baseline window (7d/28d) to compare against at all.
    public static func compute(from samples: [SensorSample], baseline: Baseline) -> RHRStatus? {
        let rhrValues = samples
            .filter { $0.kind == .restingHeartRate }
            .map(\.value)
            .sorted()
        guard !rhrValues.isEmpty else { return nil }
        let todayMedian = BaselineTracker.median(of: rhrValues)

        guard let referenceWindow = baseline.twentyEightDay ?? baseline.sevenDay else {
            return nil
        }

        let deviation = (todayMedian - referenceWindow.median) / referenceWindow.median
        let level: RHRStatusLevel
        if deviation >= normalRangeFraction {
            level = .elevated
        } else if deviation <= -normalRangeFraction {
            level = .suppressed
        } else {
            level = .normal
        }

        return RHRStatus(value: todayMedian, level: level, confidence: referenceWindow.confidence)
    }
}
