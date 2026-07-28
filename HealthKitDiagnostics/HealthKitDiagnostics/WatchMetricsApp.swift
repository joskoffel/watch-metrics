import SwiftUI
import WatchKit

@main
struct WatchMetricsApp: App {
    @WKApplicationDelegateAdaptor(BriefAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchMetricsRootView()
                .task {
                    await BriefScheduler.handleForegroundActivation()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task {
                        await BriefScheduler.handleForegroundActivation()
                    }
                }
        }
    }
}
