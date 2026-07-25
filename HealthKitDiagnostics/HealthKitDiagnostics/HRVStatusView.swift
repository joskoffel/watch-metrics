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
        MetricCard(
            title: "HRV",
            symbolName: "waveform.path.ecg",
            isLoading: integration.isLoading,
            emptyMessage: integration.hrvStatus == nil ? integration.statusText : nil
        ) {
            if let status = integration.hrvStatus {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Circle()
                            .fill(colorForLevel(status.level))
                            .frame(width: 10, height: 10)
                            .animation(.easeInOut(duration: 0.2), value: status.level)
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(String(format: "%.1f", status.value))
                                .font(.title2.weight(.semibold))
                            Text("ms")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("Medián za noc")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(levelText(status.level)) · confidence \(confidenceText(status.confidence))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: integration.hrvStatus)
        // .task(id:) cancels the in-flight query and starts a fresh one
        // whenever referenceDate changes (e.g. stepping the night picker),
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
        case .normal: AppTheme.statusNormal
        case .low, .high: AppTheme.statusLow
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
