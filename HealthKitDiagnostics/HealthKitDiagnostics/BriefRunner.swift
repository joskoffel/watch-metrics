import Foundation
import MetricsCore

/// Orchestrates both scheduled and debug attempts. The entry points are
/// deliberately separate: scheduled attempts enforce `BriefStore` dedupe,
/// while an explicit debug attempt may bypass it for on-demand verification.
///
/// There is no `RHRIntegration` in this diagnostics app yet (M3 was never
/// wired into the shell), so `rhr` is always `nil` here — `NightSummary`
/// already treats a missing metric as "omit it", not an error.
@MainActor
@Observable
final class BriefRunner {
    private let sleepIntegration = SleepIntegration()
    private let hrvIntegration = HRVIntegration()
    private let spo2Integration = SpO2Integration()
    private let store = BriefStore()
    private let notifier = BriefNotifier()

    private(set) var lastDecision: BriefDecision?
    private(set) var lastResult: BriefRunResult?
    private(set) var statusText = "Not started"
    private(set) var isLoading = false

    func runScheduled() async -> BriefRunResult {
        await run(enforceDedupe: true)
    }

    func runDebug() async -> BriefRunResult {
        await run(enforceDedupe: false)
    }

    private func run(enforceDedupe: Bool) async -> BriefRunResult {
        isLoading = true
        defer { isLoading = false }

        let now = Date()
        await sleepIntegration.run(referenceDate: now)
        await hrvIntegration.run(referenceDate: now)
        await spo2Integration.run(referenceDate: now)

        let decision = BriefDeliveryPolicy.evaluate(
            now: now,
            calendar: .current,
            sessions: sleepIntegration.sessions,
            hrv: hrvIntegration.hrvStatus,
            rhr: nil,
            spo2: spo2Integration.spo2Status,
            isAlreadyDelivered: { [store] mainSleepEnd in
                enforceDedupe && store.hasDelivered(onDay: mainSleepEnd)
            }
        )
        lastDecision = decision

        let result: BriefRunResult
        switch decision {
        case .deliver(let summary):
            do {
                try await notifier.requestAuthorization()
                try await notifier.notify(BriefComposer.compose(from: summary))
                store.markDelivered(onDay: summary.sleep.end)
                statusText = "Doručené"
                result = .delivered
            } catch {
                statusText = "Notifikácia zlyhala: \(error.localizedDescription)"
                result = .notificationFailed(retryAfter: BriefConstants.retryInterval)
            }
        case .retry(let after):
            statusText = "Retry o \(Int(after / 60)) min"
            result = .policyRetry(after: after)
        case .skip(let reason):
            statusText = "Preskočené: \(Self.skipReasonText(reason))"
            result = .policySkip(reason)
        }

        lastResult = result
        return result
    }

    private static func skipReasonText(_ reason: SkipReason) -> String {
        switch reason {
        case .alreadyDelivered: "už doručené dnes"
        case .noMainSleep: "žiadny hlavný spánok"
        case .pastCutoff: "po uzávierke"
        }
    }
}
