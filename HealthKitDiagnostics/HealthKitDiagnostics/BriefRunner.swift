import Foundation
import MetricsCore

/// Orchestrates the debug trigger ("Spustiť brief teraz"): fetches the same
/// data a real scheduled run would, then calls the exact same
/// `BriefDeliveryPolicy` and `BriefNotifier`. The only things it bypasses
/// are waiting for the scheduled delivery time and the dedupe check
/// (`isAlreadyDelivered` is hard-wired to `false`) — everything else,
/// including writing to `BriefStore` on an actual delivery, behaves like
/// the real pipeline so a debug run doesn't cause a duplicate later.
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
    private(set) var statusText = "Not started"
    private(set) var isLoading = false

    func runNow() async {
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
            isAlreadyDelivered: { _ in false }
        )
        lastDecision = decision

        switch decision {
        case .deliver(let summary):
            do {
                try await notifier.requestAuthorization()
                try await notifier.notify(BriefComposer.compose(from: summary))
                store.markDelivered(onDay: summary.sleep.end)
                statusText = "Doručené"
            } catch {
                statusText = "Notifikácia zlyhala: \(error.localizedDescription)"
            }
        case .retry(let after):
            statusText = "Retry o \(Int(after / 60)) min"
        case .skip(let reason):
            statusText = "Preskočené: \(Self.skipReasonText(reason))"
        }
    }

    private static func skipReasonText(_ reason: SkipReason) -> String {
        switch reason {
        case .alreadyDelivered: "už doručené dnes"
        case .noMainSleep: "žiadny hlavný spánok"
        case .pastCutoff: "po uzávierke"
        }
    }
}
