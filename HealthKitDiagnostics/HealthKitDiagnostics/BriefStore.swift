import Foundation

/// Dedupe store for the morning brief: remembers which calendar day's main
/// sleep already got a delivered brief, keyed as `yyyy-MM-dd` (see the spec
/// — "kalendárny dátum konca hlavného spánku").
///
/// `hasDelivered`/`markDelivered` take a plain `Date`, not specifically
/// main sleep's `end`: the upfront dedupe check (`BriefDeliveryPolicy` step
/// 1) runs *before* main sleep is resolved, so at that point the caller can
/// only pass `now` (today's date) as a practical stand-in — the two
/// virtually always land on the same calendar day, since main sleep ends
/// before the 10:00 cutoff whenever it resolves at all. Once delivery
/// actually happens, the caller has `main.end` and should pass that
/// instead, matching the spec's key exactly.
struct BriefStore {
    private let defaults: UserDefaults
    private static let lastDeliveredDayKey = "BriefStore.lastDeliveredDay"

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        return formatter
    }()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func hasDelivered(onDay day: Date) -> Bool {
        defaults.string(forKey: Self.lastDeliveredDayKey) == Self.dayFormatter.string(from: day)
    }

    func markDelivered(onDay day: Date) {
        defaults.set(Self.dayFormatter.string(from: day), forKey: Self.lastDeliveredDayKey)
    }
}
