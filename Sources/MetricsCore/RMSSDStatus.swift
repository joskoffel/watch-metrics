/// A nightly RR-derived RMSSD value compared with its own rolling personal
/// baseline. It deliberately reuses the established HRV relative convention
/// while remaining separate from the authoritative SDNN `HRVStatus`.
public struct RMSSDStatus: Equatable {
    public let value: Double
    public let level: HRVStatusLevel
    public let confidence: ConfidenceLevel

    public init(value: Double, level: HRVStatusLevel, confidence: ConfidenceLevel) {
        self.value = value
        self.level = level
        self.confidence = confidence
    }

    /// Returns nil when either the selected night's RMSSD or a personal
    /// baseline is unavailable. No population fallback is inferred.
    public static func compute(value: Double?, baseline: Baseline) -> RMSSDStatus? {
        guard
            let value,
            value.isFinite,
            value >= 0,
            let referenceWindow = baseline.twentyEightDay ?? baseline.sevenDay,
            referenceWindow.median > 0
        else {
            return nil
        }

        let deviation = (value - referenceWindow.median) / referenceWindow.median
        let level: HRVStatusLevel
        if deviation <= -HRVStatus.normalRangeFraction {
            level = .low
        } else if deviation >= HRVStatus.normalRangeFraction {
            level = .high
        } else {
            level = .normal
        }

        return RMSSDStatus(value: value, level: level, confidence: referenceWindow.confidence)
    }
}

/// A qualitative comparison of the independent SDNN and RMSSD directions.
/// It is explanatory only and is not used by `RecoverySignal`.
public enum HRVAgreementInsight: Equatable {
    case bothLower
    case bothTypicalOrHigher
    case mixed
    case insufficientRMSSD

    public static func evaluate(
        sdnn: HRVStatus?,
        rmssd: RMSSDStatus?
    ) -> HRVAgreementInsight {
        guard let sdnn, let rmssd else { return .insufficientRMSSD }

        switch (sdnn.level, rmssd.level) {
        case (.low, .low):
            return .bothLower
        case (.low, _), (_, .low):
            return .mixed
        default:
            return .bothTypicalOrHigher
        }
    }
}
