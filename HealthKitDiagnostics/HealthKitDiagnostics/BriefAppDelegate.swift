import WatchKit

/// Wires `BriefScheduler` into the app lifecycle: arms the first background
/// refresh on launch, and hands every fired `WKApplicationRefreshBackgroundTask`
/// to `BriefScheduler.handle(_:)`. Any other background task kind (none
/// expected in this app) is completed immediately rather than left hanging.
final class BriefAppDelegate: NSObject, WKApplicationDelegate {
    private let sleepBriefObserver = SleepBriefObserver()

    func applicationDidFinishLaunching() {
        BriefScheduler.scheduleInitialRefresh()
        sleepBriefObserver.start()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let refreshTask as WKApplicationRefreshBackgroundTask:
                Task { @MainActor in
                    await BriefScheduler.handle(refreshTask)
                }
            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
