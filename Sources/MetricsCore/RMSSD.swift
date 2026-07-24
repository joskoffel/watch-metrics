/// Root mean square of successive differences between RR intervals — a
/// standard time-domain HRV metric reflecting short-term (parasympathetic)
/// variability. Formula: sqrt(mean((RR[i+1] - RR[i])^2)) over the input
/// sequence, per Task Force of ESC/NASPE (1996) HRV measurement standards.
///
/// Returns `nil` when fewer than 2 intervals are given, rather than 0 or a
/// thrown error: a sparse night with <2 valid RR intervals is an expected
/// real-world condition (not a programmer error), and 0 would be
/// indistinguishable from a genuine "no variability between two identical
/// intervals" result.
public enum RMSSD {
    public static func calculate(from intervals: [RRInterval]) -> Double? {
        guard intervals.count >= 2 else { return nil }
        let diffs = zip(intervals, intervals.dropFirst()).map { $1.milliseconds - $0.milliseconds }
        let meanSquare = diffs.reduce(0) { $0 + $1 * $1 } / Double(diffs.count)
        return meanSquare.squareRoot()
    }
}
