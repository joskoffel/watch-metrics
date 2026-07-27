/// Conservative interpretation of the existing personal HRV and resting
/// heart-rate statuses. It is not a numeric score or a medical conclusion.
public enum RecoverySignalLevel: Equatable {
    case strained
    case mixed
    case typical
    case favorable
}

public struct RecoverySignal: Equatable {
    public let level: RecoverySignalLevel

    public init(level: RecoverySignalLevel) {
        self.level = level
    }

    /// Returns a signal only when both personal-baseline comparisons have at
    /// least medium confidence. Low-confidence inputs deliberately do not
    /// get a population-based substitute.
    public static func evaluate(hrv: HRVStatus?, rhr: RHRStatus?) -> RecoverySignal? {
        guard let hrv, let rhr,
              hrv.confidence != .low,
              rhr.confidence != .low else {
            return nil
        }

        switch (hrv.level, rhr.level) {
        case (.low, .elevated):
            return RecoverySignal(level: .strained)
        case (.high, .suppressed):
            return RecoverySignal(level: .favorable)
        case (.normal, .normal):
            return RecoverySignal(level: .typical)
        default:
            return RecoverySignal(level: .mixed)
        }
    }

    public var briefText: String {
        switch level {
        case .strained: "nižšia než obvykle"
        case .mixed: "zmiešaný signál"
        case .typical: "v osobnej norme"
        case .favorable: "priaznivá"
        }
    }
}
