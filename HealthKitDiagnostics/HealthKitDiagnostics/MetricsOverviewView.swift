import SwiftUI

/// Main diagnostic screen: HRV and SpO2 together, each with its own
/// HealthKit query/authorization (via HRVStatusView/SpO2StatusView), same
/// green/yellow/red status-color pattern for both.
struct MetricsOverviewView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HRVStatusView()
                Divider()
                SpO2StatusView()
            }
        }
    }
}
