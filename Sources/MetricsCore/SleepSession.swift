import Foundation

/// One raw sleep-stage segment as reported by HealthKit's sleep analysis,
/// expressed as a pure type so `SleepSessionBuilder` stays independent of
/// `HKCategorySample` — mapping from HealthKit belongs in the shell layer.
public struct SleepSample: Equatable {
    public enum Stage: Equatable, Sendable {
        case inBed
        case awake
        case asleepUnspecified
        case asleepCore
        case asleepDeep
        case asleepREM
    }

    public let start: Date
    public let end: Date
    public let stage: Stage

    public init(start: Date, end: Date, stage: Stage) {
        self.start = start
        self.end = end
        self.stage = stage
    }
}

/// A single continuous stretch of sleep, after merging adjacent stage
/// segments (see `SleepSessionBuilder`).
public struct SleepSession: Equatable {
    public let start: Date
    public let end: Date
    /// Sum of the unique time covered by asleep-stage samples. Unlike the
    /// session bounds, this excludes awake/in-bed gaps and never double-counts
    /// overlapping asleep samples.
    public let asleepDuration: TimeInterval

    public init(start: Date, end: Date, asleepDuration: TimeInterval) {
        self.start = start
        self.end = end
        self.asleepDuration = asleepDuration
    }

    /// Wall-clock span from the first asleep sample to the last. This is a
    /// boundary measurement, not the amount of time asleep.
    public var elapsedDuration: TimeInterval { end.timeIntervalSince(start) }
}

/// Turns raw sleep-stage segments into merged sleep sessions.
///
/// `awake`/`inBed` segments never contribute to `asleepDuration`; they only
/// matter as gaps between asleep segments, and a gap longer than
/// `gapTolerance` splits what would otherwise be one session into two.
public enum SleepSessionBuilder {
    private static let sleepStages: Set<SleepSample.Stage> = [
        .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM
    ]

    public static func build(
        from samples: [SleepSample],
        gapTolerance: TimeInterval = BriefConstants.gapTolerance
    ) -> [SleepSession] {
        let sleepSamples = samples
            .filter { sleepStages.contains($0.stage) }
            .filter { $0.end > $0.start }
            .sorted { $0.start < $1.start }

        guard var currentStart = sleepSamples.first?.start else { return [] }
        var currentEnd = sleepSamples[0].end
        var currentAsleepDuration = currentEnd.timeIntervalSince(currentStart)

        var sessions: [SleepSession] = []

        for sample in sleepSamples.dropFirst() {
            if sample.start.timeIntervalSince(currentEnd) <= gapTolerance {
                let uncoveredStart = max(sample.start, currentEnd)
                if sample.end > uncoveredStart {
                    currentAsleepDuration += sample.end.timeIntervalSince(uncoveredStart)
                }
                currentEnd = max(currentEnd, sample.end)
            } else {
                sessions.append(SleepSession(
                    start: currentStart,
                    end: currentEnd,
                    asleepDuration: currentAsleepDuration
                ))
                currentStart = sample.start
                currentEnd = sample.end
                currentAsleepDuration = sample.end.timeIntervalSince(sample.start)
            }
        }
        sessions.append(SleepSession(
            start: currentStart,
            end: currentEnd,
            asleepDuration: currentAsleepDuration
        ))

        return sessions
    }
}
