import SwiftUI
import MetricsCore

/// First real end-to-end HRV display: HealthKit samples -> MetricsCore's
/// HRVStatus -> screen. Distinct from DiagnosticsView (Gate G0.2's raw
/// HKHeartbeatSeriesQuery check), which stays as-is for future gate checks.
struct HRVStatusView: View {
    @State private var integration = HRVIntegration()

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let status = integration.hrvStatus {
                    Text("\(String(format: "%.1f", status.value)) ms")
                        .font(.title2)
                    Text("Level: \(levelText(status.level))")
                    Text("Confidence: \(confidenceText(status.confidence))")
                } else {
                    Text(integration.statusText)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .task {
            await integration.run()
        }
    }

    private func levelText(_ level: HRVStatusLevel) -> String {
        switch level {
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        }
    }

    private func confidenceText(_ confidence: ConfidenceLevel) -> String {
        switch confidence {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}
