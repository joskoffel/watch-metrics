import Foundation

public struct TimedHeartRate: Equatable, Sendable {
    public let timestamp: Date
    public let beatsPerMinute: Double

    public init(timestamp: Date, beatsPerMinute: Double) {
        self.timestamp = timestamp
        self.beatsPerMinute = beatsPerMinute
    }
}

public struct NightThirdCoverage: Equatable, Sendable {
    public let first: Bool
    public let middle: Bool
    public let last: Bool

    public init(first: Bool, middle: Bool, last: Bool) {
        self.first = first
        self.middle = middle
        self.last = last
    }

    public var isComplete: Bool { first && middle && last }
}

public struct NightHeartRateAudit: Equatable, Sendable {
    public let sampleCount: Int
    public let median: Double
    public let robustLow: Double?
    public let coverage: NightThirdCoverage
    public let supportsSettlingTrend: Bool

    public init(
        sampleCount: Int,
        median: Double,
        robustLow: Double?,
        coverage: NightThirdCoverage,
        supportsSettlingTrend: Bool
    ) {
        self.sampleCount = sampleCount
        self.median = median
        self.robustLow = robustLow
        self.coverage = coverage
        self.supportsSettlingTrend = supportsSettlingTrend
    }
}

public enum NightHeartRateAnalyzer {
    public static func analyze(
        samples: [TimedHeartRate],
        interval: DateInterval
    ) -> NightHeartRateAudit? {
        let valid = samples
            .filter {
                interval.contains($0.timestamp) &&
                $0.beatsPerMinute.isFinite &&
                $0.beatsPerMinute > 0
            }
            .sorted { $0.timestamp < $1.timestamp }
        guard !valid.isEmpty else { return nil }

        let sortedValues = valid.map(\.beatsPerMinute).sorted()
        let robustLow: Double?
        if sortedValues.count >= 3 {
            let lowerCount = max(3, Int(ceil(Double(sortedValues.count) * 0.1)))
            robustLow = median(Array(sortedValues.prefix(lowerCount)))
        } else {
            robustLow = nil
        }

        let thirdDuration = interval.duration / 3
        var first = false
        var middle = false
        var last = false
        for sample in valid {
            let offset = sample.timestamp.timeIntervalSince(interval.start)
            if offset < thirdDuration {
                first = true
            } else if offset < 2 * thirdDuration {
                middle = true
            } else {
                last = true
            }
        }
        let coverage = NightThirdCoverage(first: first, middle: middle, last: last)
        return NightHeartRateAudit(
            sampleCount: valid.count,
            median: median(sortedValues),
            robustLow: robustLow,
            coverage: coverage,
            supportsSettlingTrend: valid.count >= 6 && coverage.isComplete
        )
    }

    private static func median(_ sorted: [Double]) -> Double {
        sorted.count.isMultiple(of: 2)
            ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
            : sorted[sorted.count / 2]
    }
}
