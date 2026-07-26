import MetricsCore

/// Combines RR series without ever creating a successive difference across
/// two distinct HealthKit heartbeat series.
public enum SeriesRMSSDAggregator {
    public static func calculate(from series: [[RRInterval]]) -> Double? {
        var squaredDifferenceSum = 0.0
        var differenceCount = 0

        for intervals in series {
            guard let rmssd = RMSSD.calculate(from: intervals) else { continue }
            let count = intervals.count - 1
            squaredDifferenceSum += rmssd * rmssd * Double(count)
            differenceCount += count
        }

        guard differenceCount > 0 else { return nil }
        return (squaredDifferenceSum / Double(differenceCount)).squareRoot()
    }
}
