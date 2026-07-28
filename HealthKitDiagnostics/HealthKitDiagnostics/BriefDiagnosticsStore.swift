import Foundation
import MetricsCore

/// Small persistent operational record for Developer → Ranný brief debug.
/// It intentionally contains timestamps and outcomes only, never HealthKit
/// samples or derived health values.
struct BriefDiagnosticSnapshot {
    let lastAttemptDate: Date?
    let lastAttemptSource: String?
    let lastOutcome: String?
    let nextRefreshDate: Date?
    let schedulingError: String?
    let lastObserverTriggerDate: Date?
    let lastObserverOutcome: String?
    let sleepBackgroundDeliveryStatus: String?
    let resolvedMainSleepEnd: Date?
    let intendedDeliveryDate: Date?
    let fallbackFireDate: Date?
    let fallbackStatus: String?
    let wasDeduped: Bool
    let notificationError: String?
}

struct BriefDiagnosticsStore {
    private let defaults: UserDefaults

    private enum Key {
        static let lastAttemptDate = "BriefDiagnostics.lastAttemptDate"
        static let lastAttemptSource = "BriefDiagnostics.lastAttemptSource"
        static let lastOutcome = "BriefDiagnostics.lastOutcome"
        static let nextRefreshDate = "BriefDiagnostics.nextRefreshDate"
        static let schedulingError = "BriefDiagnostics.schedulingError"
        static let lastObserverTriggerDate = "BriefDiagnostics.lastObserverTriggerDate"
        static let lastObserverOutcome = "BriefDiagnostics.lastObserverOutcome"
        static let sleepBackgroundDeliveryStatus = "BriefDiagnostics.sleepBackgroundDeliveryStatus"
        static let resolvedMainSleepEnd = "BriefDiagnostics.resolvedMainSleepEnd"
        static let intendedDeliveryDate = "BriefDiagnostics.intendedDeliveryDate"
        static let fallbackFireDate = "BriefDiagnostics.fallbackFireDate"
        static let fallbackStatus = "BriefDiagnostics.fallbackStatus"
        static let wasDeduped = "BriefDiagnostics.wasDeduped"
        static let notificationError = "BriefDiagnostics.notificationError"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func recordAttemptStarted(at date: Date, source: String) {
        defaults.set(date, forKey: Key.lastAttemptDate)
        defaults.set(source, forKey: Key.lastAttemptSource)
        defaults.set("Prebieha", forKey: Key.lastOutcome)
    }

    func recordAttemptFinished(_ result: BriefRunResult) {
        defaults.set(outcomeText(for: result), forKey: Key.lastOutcome)
    }

    func recordNextRefresh(_ date: Date) {
        defaults.set(date, forKey: Key.nextRefreshDate)
    }

    func recordSchedulingError(_ error: Error?) {
        if let error {
            defaults.set(error.localizedDescription, forKey: Key.schedulingError)
        } else {
            defaults.removeObject(forKey: Key.schedulingError)
        }
    }

    func recordObserverTrigger(at date: Date) {
        defaults.set(date, forKey: Key.lastObserverTriggerDate)
    }

    func recordObserverOutcome(_ outcome: String) {
        defaults.set(outcome, forKey: Key.lastObserverOutcome)
    }

    func recordSleepBackgroundDelivery(success: Bool, errorDescription: String?) {
        if let errorDescription {
            defaults.set("Zlyhalo: \(errorDescription)", forKey: Key.sleepBackgroundDeliveryStatus)
        } else {
            defaults.set(success ? "Aktívne" : "WatchOS odmietol", forKey: Key.sleepBackgroundDeliveryStatus)
        }
    }

    func recordResolvedSleep(end: Date?, intendedDelivery: Date?) {
        if let end { defaults.set(end, forKey: Key.resolvedMainSleepEnd) } else { defaults.removeObject(forKey: Key.resolvedMainSleepEnd) }
        if let intendedDelivery { defaults.set(intendedDelivery, forKey: Key.intendedDeliveryDate) } else { defaults.removeObject(forKey: Key.intendedDeliveryDate) }
    }

    func recordFallback(fireDate: Date?, status: String) {
        if let fireDate { defaults.set(fireDate, forKey: Key.fallbackFireDate) } else { defaults.removeObject(forKey: Key.fallbackFireDate) }
        defaults.set(status, forKey: Key.fallbackStatus)
    }

    func recordDeduped(_ deduped: Bool) {
        defaults.set(deduped, forKey: Key.wasDeduped)
    }

    func recordNotificationError(_ error: Error?) {
        if let error { defaults.set(error.localizedDescription, forKey: Key.notificationError) }
        else { defaults.removeObject(forKey: Key.notificationError) }
    }

    func snapshot() -> BriefDiagnosticSnapshot {
        BriefDiagnosticSnapshot(
            lastAttemptDate: defaults.object(forKey: Key.lastAttemptDate) as? Date,
            lastAttemptSource: defaults.string(forKey: Key.lastAttemptSource),
            lastOutcome: defaults.string(forKey: Key.lastOutcome),
            nextRefreshDate: defaults.object(forKey: Key.nextRefreshDate) as? Date,
            schedulingError: defaults.string(forKey: Key.schedulingError),
            lastObserverTriggerDate: defaults.object(forKey: Key.lastObserverTriggerDate) as? Date,
            lastObserverOutcome: defaults.string(forKey: Key.lastObserverOutcome),
            sleepBackgroundDeliveryStatus: defaults.string(forKey: Key.sleepBackgroundDeliveryStatus),
            resolvedMainSleepEnd: defaults.object(forKey: Key.resolvedMainSleepEnd) as? Date,
            intendedDeliveryDate: defaults.object(forKey: Key.intendedDeliveryDate) as? Date,
            fallbackFireDate: defaults.object(forKey: Key.fallbackFireDate) as? Date,
            fallbackStatus: defaults.string(forKey: Key.fallbackStatus),
            wasDeduped: defaults.bool(forKey: Key.wasDeduped),
            notificationError: defaults.string(forKey: Key.notificationError)
        )
    }

    private func outcomeText(for result: BriefRunResult) -> String {
        switch result {
        case .delivered: "Doručené"
        case .policyRetry(let after): "Retry o \(Int(after / 60)) min"
        case .policySkip(let reason):
            switch reason {
            case .alreadyDelivered: "Preskočené: už doručené"
            case .noMainSleep: "Preskočené: žiadny hlavný spánok"
            case .pastCutoff: "Preskočené: po uzávierke"
            }
        case .notificationFailed: "Zlyhanie notifikácie"
        }
    }
}
