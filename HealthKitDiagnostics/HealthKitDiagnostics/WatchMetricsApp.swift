import SwiftUI
import WatchKit

@main
struct WatchMetricsApp: App {
    @WKApplicationDelegateAdaptor(BriefAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            WatchMetricsRootView()
        }
    }
}
