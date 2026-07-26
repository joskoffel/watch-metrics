import Foundation
import MetricsCore
import WatchKit

/// Owns the watchOS background-refresh retry ladder (spec D1): arms
/// `WKApplication.scheduleBackgroundRefresh`, and on each fired task runs
/// the same pipeline `BriefRunner`/`BriefDebugPanel` use, then reschedules
/// per `BriefScheduling.nextRefreshDate` based on the resulting decision.
/// `HKObserverQuery` is deliberately not used here — see D1: "longest
/// session of the night" can't be known until the night window is over, so
/// polling at fixed points is the only correct trigger, not an
/// event-on-session-end one.
@MainActor
enum BriefScheduler {
    static func scheduleNextRefresh(preferredDate: Date) {
        WKApplication.shared().scheduleBackgroundRefresh(withPreferredDate: preferredDate, userInfo: nil) { _ in
            // Best-effort: watchOS may deny scheduling under budget
            // pressure. Nothing actionable here — the next app launch
            // (`scheduleInitialRefresh`) or fired task (`handle`) will just
            // try arming the next one again.
        }
    }

    /// Call from `WKApplicationDelegate.applicationDidFinishLaunching()`.
    static func scheduleInitialRefresh() {
        scheduleNextRefresh(preferredDate: BriefScheduling.nextRefreshDate(now: Date(), calendar: .current, decision: nil))
    }

    /// Call from `WKApplicationDelegate.handle(_:)` for each
    /// `WKApplicationRefreshBackgroundTask`.
    static func handle(_ task: WKApplicationRefreshBackgroundTask) async {
        let runner = BriefRunner()
        await runner.runNow()

        let nextDate = BriefScheduling.nextRefreshDate(now: Date(), calendar: .current, decision: runner.lastDecision)
        scheduleNextRefresh(preferredDate: nextDate)

        task.setTaskCompletedWithSnapshot(false)
    }
}
