import Foundation

/// Outcome of the complete shell-layer attempt, including notification
/// delivery. `BriefDecision` remains the result of the pure delivery policy;
/// this type records what actually happened after that decision was executed.
public enum BriefRunResult: Equatable {
    case delivered
    case policyRetry(after: TimeInterval)
    case policySkip(SkipReason)
    case notificationFailed(retryAfter: TimeInterval)
}
