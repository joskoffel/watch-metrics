import Foundation

/// One day's aggregated metric value (e.g. a night's median SDNN in ms)
/// feeding into `BaselineTracker`. Deliberately metric-agnostic — HRV, RHR,
/// etc. all get reduced to a single value per day by their own aggregation
/// step before reaching this point, so the rolling-window logic here isn't
/// duplicated per metric.
public struct DailyMetricValue: Equatable {
    public let date: Date
    public let value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

/// Computes 7-day/28-day rolling baselines from a historical series of
/// daily metric values.
///
/// Aggregation is the **median**, not the mean, of the values present in
/// the window: baselines need to stay stable in the face of a single
/// anomalous day (illness, alcohol, a bad night), and a median resists that
/// far better than a mean — especially with sparse/irregular data where a
/// mean would be disproportionately swayed by whichever few days happen to
/// be present.
///
/// Confidence reflects how much of the window is actually populated
/// (`availableDays / windowDays`), not just whether a value could be
/// computed at all — a median from 1 day out of 28 is technically a
/// number, but shouldn't be presented with the same confidence as a
/// complete window.
public enum BaselineTracker {
    static let highConfidenceThreshold = 0.85
    static let mediumConfidenceThreshold = 0.5

    /// Computes both the 7-day and 28-day rolling baselines as of `targetDate`.
    public static func baseline(from dailyValues: [DailyMetricValue], asOf targetDate: Date) -> Baseline {
        Baseline(
            sevenDay: rollingWindow(dailyValues: dailyValues, asOf: targetDate, windowDays: 7),
            twentyEightDay: rollingWindow(dailyValues: dailyValues, asOf: targetDate, windowDays: 28)
        )
    }

    /// Computes a single rolling window (`targetDate` and the `windowDays - 1`
    /// days before it). Returns nil only when the window has no data at all —
    /// sparse-but-nonempty windows still return a value, with lower confidence.
    public static func rollingWindow(
        dailyValues: [DailyMetricValue],
        asOf targetDate: Date,
        windowDays: Int
    ) -> RollingWindowBaseline? {
        let valuesInWindow = dailyValues.filter { dailyValue in
            let dayOffset = (targetDate.timeIntervalSince(dailyValue.date) / 86400).rounded()
            return dayOffset >= 0 && dayOffset < Double(windowDays)
        }
        guard !valuesInWindow.isEmpty else { return nil }

        let sortedValues = valuesInWindow.map(\.value).sorted()
        let availableRatio = Double(valuesInWindow.count) / Double(windowDays)
        let confidence: ConfidenceLevel
        switch availableRatio {
        case highConfidenceThreshold...:
            confidence = .high
        case mediumConfidenceThreshold..<highConfidenceThreshold:
            confidence = .medium
        default:
            confidence = .low
        }

        return RollingWindowBaseline(
            median: median(of: sortedValues),
            confidence: confidence,
            availableDays: valuesInWindow.count,
            windowDays: windowDays
        )
    }

    private static func median(of sortedValues: [Double]) -> Double {
        let count = sortedValues.count
        if count % 2 == 1 {
            return sortedValues[count / 2]
        }
        return (sortedValues[count / 2 - 1] + sortedValues[count / 2]) / 2
    }
}
