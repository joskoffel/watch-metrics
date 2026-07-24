/// Removes physiologically implausible RR intervals before HRV calculation.
///
/// Two rejection rules, applied per interval in sequence order:
/// - Absolute range 300-2000ms (200-30 bpm) — the outer bound of plausible
///   human beat-to-beat intervals, per the Task Force of the European
///   Society of Cardiology and NASPE (1996) HRV measurement standards.
/// - Change of more than 20% from the last *accepted* interval — a common
///   ectopic-beat/sensor-glitch heuristic for jumps that stay inside the
///   absolute range but are still implausible given the previous beat
///   (referenced e.g. in Kubios HRV's artifact-correction documentation).
public enum RRArtifactFilter {
    public static let physiologicalRange: ClosedRange<Double> = 300...2000
    public static let maxSuccessiveChangeFraction: Double = 0.2

    public static func filter(_ intervals: [RRInterval]) -> [RRInterval] {
        var accepted: [RRInterval] = []
        for interval in intervals {
            guard physiologicalRange.contains(interval.milliseconds) else { continue }
            if let last = accepted.last {
                let change = abs(interval.milliseconds - last.milliseconds) / last.milliseconds
                guard change <= maxSuccessiveChangeFraction else { continue }
            }
            accepted.append(interval)
        }
        return accepted
    }
}
