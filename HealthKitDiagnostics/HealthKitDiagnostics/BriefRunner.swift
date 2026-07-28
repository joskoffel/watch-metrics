import Foundation
import MetricsCore

/// Orchestrates both scheduled and debug attempts. The entry points are
/// deliberately separate: scheduled attempts enforce `BriefStore` dedupe,
/// while an explicit debug attempt may bypass it for on-demand verification.
///
@MainActor
@Observable
final class BriefRunner {
    private let sleepIntegration = SleepIntegration()
    private let hrvIntegration = HRVIntegration()
    private let rhrIntegration = RHRIntegration()
    private let spo2Integration = SpO2Integration()
    private let store = BriefStore()
    private let notifier = BriefNotifier()
    private let fallbackNotifier = BriefFallbackNotifier()
    private let diagnostics = BriefDiagnosticsStore()

    private(set) var lastDecision: BriefDecision?
    private(set) var lastResult: BriefRunResult?
    private(set) var statusText = "Not started"
    private(set) var isLoading = false

    func runScheduled() async -> BriefRunResult {
        await run(enforceDedupe: true, requestsNotificationAuthorization: false)
    }

    func runDebug() async -> BriefRunResult {
        await run(enforceDedupe: false, requestsNotificationAuthorization: true)
    }

    private func run(enforceDedupe: Bool, requestsNotificationAuthorization: Bool) async -> BriefRunResult {
        isLoading = true
        defer { isLoading = false }

        let now = Date()
        await sleepIntegration.run(referenceDate: now)
        let nights = sleepIntegration.resolvedNights
        await hrvIntegration.run(referenceDate: now, nights: nights)
        await rhrIntegration.run(referenceDate: now)
        await spo2Integration.run(referenceDate: now, nights: nights)

        let fallbackPlan = BriefFallbackPlanning.futurePlan(now: now, calendar: .current, sessions: sleepIntegration.sessions)
        diagnostics.recordResolvedSleep(end: fallbackPlan?.mainSleepEnd, intendedDelivery: fallbackPlan?.fireDate)

        let decision = BriefDeliveryPolicy.evaluate(
            now: now,
            calendar: .current,
            sessions: sleepIntegration.sessions,
            hrv: hrvIntegration.hrvStatus,
            rhr: rhrIntegration.rhrStatus,
            spo2: spo2Integration.spo2Status,
            isAlreadyDelivered: { [store] mainSleepEnd in
                guard enforceDedupe else { return false }
                if store.hasDelivered(onDay: mainSleepEnd) { return true }
                return fallbackNotifier.consumeDeliveredFallbackIfNeeded(for: mainSleepEnd, now: now, briefStore: store)
            }
        )
        lastDecision = decision

        let result: BriefRunResult
        switch decision {
        case .deliver(let summary):
            diagnostics.recordResolvedSleep(end: summary.sleep.end, intendedDelivery: BriefFallbackPlanning.deliveryDate(for: summary.sleep, now: now, calendar: .current))
            do {
                if enforceDedupe {
                    fallbackNotifier.cancel()
                    diagnostics.recordFallback(fireDate: nil, status: "Zrušený: pravidelný pokus doručuje")
                }
                if requestsNotificationAuthorization {
                    try await notifier.requestAuthorization()
                }
                var content = BriefComposer.compose(from: summary)
                if let weather = await WeatherBriefService.shared.currentSummary() {
                    content = BriefContent(
                        title: content.title,
                        lines: content.lines + [BriefLine(label: "Počasie", value: weather.briefText, qualifier: nil, isProvisional: false)]
                    )
                }
                try await notifier.notify(content)
                store.markDelivered(onDay: summary.sleep.end)
                diagnostics.recordDeduped(false)
                diagnostics.recordNotificationError(nil)
                statusText = "Doručené"
                result = .delivered
            } catch {
                diagnostics.recordNotificationError(error)
                statusText = "Notifikácia zlyhala: \(error.localizedDescription)"
                result = .notificationFailed(retryAfter: BriefConstants.retryInterval)
            }
        case .retry(let after):
            statusText = "Retry o \(Int(after / 60)) min"
            if enforceDedupe, let fallbackPlan {
                let hasHealthData = BriefFallbackNotifier.hasReadyHealthData(
                    hrv: hrvIntegration.hrvStatus,
                    rhr: rhrIntegration.rhrStatus,
                    spo2: spo2Integration.spo2Status
                )
                if hasHealthData {
                    let content = BriefComposer.compose(from: NightSummary(
                        sleep: fallbackPlan.mainSleep,
                        hrv: hrvIntegration.hrvStatus,
                        rhr: rhrIntegration.rhrStatus,
                        spo2: spo2Integration.spo2Status
                    ))
                    do {
                        try await fallbackNotifier.arm(content: content, plan: fallbackPlan)
                        diagnostics.recordFallback(fireDate: fallbackPlan.fireDate, status: "Aktívny: D1 vyriešený spánok, budúci policy čas")
                    } catch {
                        diagnostics.recordFallback(fireDate: nil, status: "Neozbrojený: \(error.localizedDescription)")
                    }
                } else {
                    diagnostics.recordFallback(fireDate: nil, status: "Neozbrojený: zdravotné dáta ešte nie sú pripravené")
                }
            } else if enforceDedupe {
                diagnostics.recordFallback(fireDate: nil, status: "Neozbrojený: žiadny budúci D1 policy čas")
            }
            result = .policyRetry(after: after)
        case .skip(let reason):
            if enforceDedupe {
                fallbackNotifier.cancel()
                diagnostics.recordFallback(fireDate: nil, status: "Zrušený: noc už nie je oprávnená")
            }
            diagnostics.recordDeduped(reason == .alreadyDelivered)
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
