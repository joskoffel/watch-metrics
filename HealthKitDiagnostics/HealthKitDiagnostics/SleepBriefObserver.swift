import Foundation
import HealthKit

/// Retained for the lifetime of the app delegate. Sleep changes wake the app,
/// but never decide that a sleep session is final or send a notification.
@MainActor
final class SleepBriefObserver {
    private let healthStore: HKHealthStore
    private let sleepType = HKCategoryType(.sleepAnalysis)
    private var query: HKObserverQuery?
    private let diagnostics = BriefDiagnosticsStore()

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    func start() {
        enableBackgroundDelivery()
        guard query == nil else { return }

        query = HKObserverQuery(sampleType: sleepType, predicate: nil) { _, completion, error in
            let errorDescription = error?.localizedDescription
            // HealthKit owns this non-Sendable completion handler; finish it
            // on its callback queue before crossing into the main actor.
            completion()
            Task { @MainActor in
                if let errorDescription {
                    BriefDiagnosticsStore().recordObserverOutcome("Chyba observera: \(errorDescription)")
                    return
                }
                await BriefScheduler.handleHealthKitObserver()
            }
        }
        if let query { healthStore.execute(query) }
    }

    private func enableBackgroundDelivery() {
        healthStore.enableBackgroundDelivery(for: sleepType, frequency: .immediate) { success, error in
            let errorDescription = error?.localizedDescription
            Task { @MainActor in
                BriefDiagnosticsStore().recordSleepBackgroundDelivery(success: success, errorDescription: errorDescription)
            }
        }
    }
}
