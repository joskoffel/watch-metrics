import Foundation
import MetricsCore

/// App-layer description of one resolved recovery night. It deliberately
/// contains no HealthKit types so every nocturnal integration shares exactly
/// the same interval and morning-day key.
public struct ResolvedNight: Equatable {
    public let day: Date
    public let sleep: SleepSession
    public let interval: DateInterval

    public init(sleep: SleepSession, calendar: Calendar) {
        self.day = calendar.startOfDay(for: sleep.end)
        self.sleep = sleep
        self.interval = DateInterval(start: sleep.start, end: sleep.end)
    }
}

public enum NightWindowResolver {
    public static func resolve(
        referenceDate: Date,
        sessions: [SleepSession],
        calendar: Calendar,
        now: Date
    ) -> ResolvedNight? {
        let morning = calendar.startOfDay(for: referenceDate)
        guard
            let previousDay = calendar.date(byAdding: .day, value: -1, to: morning),
            let windowStart = calendar.date(
                bySettingHour: BriefConstants.nightWindowStartHour,
                minute: 0,
                second: 0,
                of: previousDay
            )
        else { return nil }

        let window = DateInterval(start: windowStart, end: referenceDate)
        guard let sleep = MainSleepResolver.resolveMainSleep(
            sessions: sessions,
            window: window,
            now: now
        ) else { return nil }
        return ResolvedNight(sleep: sleep, calendar: calendar)
    }
}

public enum NightMetricMapper {
    public static func samples(
        _ samples: [SensorSample],
        kind: SensorSample.Kind,
        in night: ResolvedNight
    ) -> [SensorSample] {
        samples
            .filter { $0.kind == kind && night.interval.contains($0.timestamp) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    public static func dailyMedian(
        samples: [SensorSample],
        kind: SensorSample.Kind,
        in night: ResolvedNight
    ) -> DailyMetricValue? {
        let values = self.samples(samples, kind: kind, in: night).map(\.value).sorted()
        guard !values.isEmpty else { return nil }
        return DailyMetricValue(date: night.day, value: median(values))
    }

    private static func median(_ sorted: [Double]) -> Double {
        sorted.count.isMultiple(of: 2)
            ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
            : sorted[sorted.count / 2]
    }
}
