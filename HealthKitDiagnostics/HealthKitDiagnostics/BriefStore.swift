import Foundation

/// Dedupe store for the morning brief: remembers which calendar day's main
/// sleep already got a delivered brief, keyed as `yyyy-MM-dd` (see the spec
/// — "kalendárny dátum konca hlavného spánku").
///
/// Both the authoritative policy check and the post-notification write use
/// the resolved main sleep's `end`; `now` is never a dedupe key.
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
