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
}

struct BriefDiagnosticsStore {
    private let defaults: UserDefaults

    private enum Key {
        static let lastAttemptDate = "BriefDiagnostics.lastAttemptDate"
        static let lastAttemptSource = "BriefDiagnostics.lastAttemptSource"
        static let lastOutcome = "BriefDiagnostics.lastOutcome"
        static let nextRefreshDate = "BriefDiagnostics.nextRefreshDate"
        static let schedulingError = "BriefDiagnostics.schedulingError"
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

    func snapshot() -> BriefDiagnosticSnapshot {
        BriefDiagnosticSnapshot(
            lastAttemptDate: defaults.object(forKey: Key.lastAttemptDate) as? Date,
            lastAttemptSource: defaults.string(forKey: Key.lastAttemptSource),
            lastOutcome: defaults.string(forKey: Key.lastOutcome),
            nextRefreshDate: defaults.object(forKey: Key.nextRefreshDate) as? Date,
            schedulingError: defaults.string(forKey: Key.schedulingError)
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
