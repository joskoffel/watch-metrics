/// Today's SpO2 status, classified against a fixed clinical threshold.
public enum SpO2StatusLevel: Equatable {
    case normal
    case low
    case critical
}

/// M14 — daily SpO2 status: a day's median OxygenSaturation compared
/// against fixed clinical thresholds, not a personal baseline (unlike
/// HRVStatus/RHRStatus — see `compute` below for why).
public struct SpO2Status: Equatable {
    public let value: Double
    public let level: SpO2StatusLevel

    /// Unlike `HRVStatus.confidence`/`RHRStatus.confidence`, this does NOT
    /// reflect the trustworthiness of `level`. `level` comes from a fixed
    /// clinical threshold on today's absolute value, not a comparison
    /// against a personal baseline, so it doesn't need baseline history to
    /// be meaningful. `confidence` here only describes how much baseline/
    /// trend context is available (for a future trend signal) — it MUST
    /// NOT be used by any future composite/readiness logic to suppress or
    /// downweight a `.critical`/`.low` SpO2 level. A `.critical` reading
    /// with `.low` confidence is still a `.critical` reading.
    public let confidence: ConfidenceLevel

    public init(value: Double, level: SpO2StatusLevel, confidence: ConfidenceLevel) {
        self.value = value
        self.level = level
        self.confidence = confidence
    }

    /// At or above this, SpO2 is normal — 95-100% is the typical healthy
    /// resting range, consistent across clinical literature and consumer
    /// sleep-tracking guidance.
    public static let normalThreshold: Double = 95.0

    /// Below this, SpO2 is clinically significant hypoxemia — the widely
    /// cited <90% cutoff (e.g. WHO guidance for actionable low oxygen).
    /// [90, 95) is "low" (mild/borderline hypoxemia).
    ///
    /// Wrist-based SpO2 accuracy is materially worse than a medical pulse
    /// oximeter (~±2-3 percentage points MAE in validation studies),
    /// especially at lower values — a single borderline/critical reading
    /// should be read alongside `confidence`/trend, not in isolation.
    public static let criticalThreshold: Double = 90.0

    /// Computes today's SpO2 status from a day's raw samples and the
    /// current baseline.
    ///
    /// Returns nil ONLY when there are no SpO2 samples for the day — unlike
    /// HRVStatus/RHRStatus, a missing baseline (both 7d and 28d absent)
    /// does NOT produce nil here. HRV/RHR have no population-level
    /// "normal", so without a personal baseline there's nothing to compare
    /// against; SpO2 has a clinically valid threshold for any person, so a
    /// brand-new user with zero history must still get a real
    /// `.critical`/`.low` reading instead of it being silently suppressed
    /// for lack of baseline data. `confidence` simply drops to `.low` in
    /// that case.
    public static func compute(from samples: [SensorSample], baseline: Baseline) -> SpO2Status? {
        let spo2Values = samples
            .filter { $0.kind == .oxygenSaturation }
            .map(\.value)
            .sorted()
        guard !spo2Values.isEmpty else { return nil }
        let todayMedian = BaselineTracker.median(of: spo2Values)

        let level: SpO2StatusLevel
        if todayMedian >= normalThreshold {
            level = .normal
        } else if todayMedian >= criticalThreshold {
            level = .low
        } else {
            level = .critical
        }

        let confidence = (baseline.twentyEightDay ?? baseline.sevenDay)?.confidence ?? .low

        return SpO2Status(value: todayMedian, level: level, confidence: confidence)
    }
}
