import SwiftUI
import MetricsCore

/// First real end-to-end HRV display: HealthKit samples -> MetricsCore's
/// HRVStatus -> screen. Distinct from DiagnosticsView (Gate G0.2's raw
/// HKHeartbeatSeriesQuery check), which stays as-is for future gate checks.
struct HRVStatusView: View {
    let referenceDate: Date
    @State private var integration = HRVIntegration()

    init(referenceDate: Date = Date()) {
        self.referenceDate = referenceDate
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("HRV")
                .font(.headline)
            if integration.isLoading {
                ProgressView()
            } else if let status = integration.hrvStatus {
                HStack(spacing: 6) {
                    Circle()
                        .fill(colorForLevel(status.level))
                        .frame(width: 12, height: 12)
                    Text("\(String(format: "%.1f", status.value)) ms")
                        .font(.title2)
                }
                Text("Medián za noc")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Level: \(levelText(status.level))")
                Text("Confidence: \(confidenceText(status.confidence))")
            } else {
                Text(integration.statusText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        // .task(id:) cancels the in-flight query and starts a fresh one
        // whenever referenceDate changes (e.g. scrolling the night picker),
        // instead of stacking overlapping HealthKit queries.
        .task(id: referenceDate) {
            await integration.run(referenceDate: referenceDate)
        }
    }

    /// Same green/yellow/red pattern as SpO2StatusView. HRV has no
    /// "critical" tier — both `.low` (below baseline) and `.high` (notable
    /// increase) map to yellow, since neither is the severe/actionable
    /// signal that SpO2's `.critical` is.
    private func colorForLevel(_ level: HRVStatusLevel) -> Color {
        switch level {
        case .normal: .green
        case .low, .high: .yellow
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
