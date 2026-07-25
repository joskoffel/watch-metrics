import SwiftUI

@main
struct HealthKitDiagnosticsApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                // New: real MetricsCore-computed HRV + SpO2 status, together.
                MetricsOverviewView()
                // Kept: Gate G0.2's raw HKHeartbeatSeriesQuery check, still
                // useful for future gate checks (e.g. other sample types).
                DiagnosticsView()
            }
            .tabViewStyle(.page)
        }
    }
}
