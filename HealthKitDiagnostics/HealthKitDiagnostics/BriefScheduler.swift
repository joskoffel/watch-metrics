import Foundation
import MetricsCore
import WatchKit

/// Owns the watchOS background-refresh retry ladder (spec D1): arms
/// `WKApplication.scheduleBackgroundRefresh`, and on each fired task runs
/// the same pipeline `BriefRunner`/`BriefDebugPanel` use, then reschedules
/// per `BriefScheduling.nextRefreshDate` based on the complete attempt result.
/// An observer is only an additional wake-up signal. D1's main-sleep and
/// delivery decision remain entirely inside `BriefRunner.runScheduled()`.
@MainActor
enum BriefScheduler {
    private static let diagnostics = BriefDiagnosticsStore()
    private static var isAutomaticAttemptInFlight = false

    static func scheduleNextRefresh(preferredDate: Date) {
        diagnostics.recordNextRefresh(preferredDate)
        WKApplication.shared().scheduleBackgroundRefresh(withPreferredDate: preferredDate, userInfo: nil) { error in
            Task { @MainActor in
                // Scheduling is best-effort, but the failure is actionable:
                // retain it for Developer diagnostics instead of silently
                // discarding it. A foreground activation remains a fallback.
                diagnostics.recordSchedulingError(error)
            }
        }
    }

    /// Call from `WKApplicationDelegate.applicationDidFinishLaunching()`.
    static func scheduleInitialRefresh() {
        scheduleNextRefresh(preferredDate: BriefScheduling.nextRefreshDate(now: Date(), calendar: .current, result: nil))
    }

    /// Foreground is a fallback for watchOS's best-effort background budget.
    /// It invokes the same deduplicating scheduled runner, never a separate
    /// notification path, and always schedules from the completed result.
    static func handleForegroundActivation() async {
        let now = Date()
        guard BriefScheduling.shouldAttemptOnForegroundActivation(now: now, calendar: .current) else {
            scheduleInitialRefresh()
            return
        }
        await performAutomaticAttempt(source: "Foreground", now: now)
    }

    /// Call from `WKApplicationDelegate.handle(_:)` for each
    /// `WKApplicationRefreshBackgroundTask`.
    static func handle(_ task: WKApplicationRefreshBackgroundTask) async {
        await performAutomaticAttempt(source: "Background", now: Date())
        task.setTaskCompletedWithSnapshot(false)
    }

    static func handleHealthKitObserver() async {
        let now = Date()
        diagnostics.recordObserverTrigger(at: now)
        let didRun = await performAutomaticAttempt(source: "HealthKitObserver", now: now)
        if !didRun {
            diagnostics.recordObserverOutcome("Čaká na prebiehajúci pokus")
            scheduleInitialRefresh()
        }
    }

    @discardableResult
    private static func performAutomaticAttempt(source: String, now: Date) async -> Bool {
        guard !isAutomaticAttemptInFlight else { return false }
        isAutomaticAttemptInFlight = true
        defer { isAutomaticAttemptInFlight = false }

        diagnostics.recordAttemptStarted(at: now, source: source)
        let result = await BriefRunner().runScheduled()
        diagnostics.recordAttemptFinished(result)
        if source == "HealthKitObserver" {
            diagnostics.recordObserverOutcome(diagnostics.snapshot().lastOutcome ?? "Dokončené")
        }

        let nextDate = BriefScheduling.nextRefreshDate(now: Date(), calendar: .current, result: result)
        scheduleNextRefresh(preferredDate: nextDate)
        return true
    }
}
