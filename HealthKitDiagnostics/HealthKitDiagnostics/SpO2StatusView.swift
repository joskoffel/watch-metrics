import SwiftUI
import MetricsCore

/// Real end-to-end SpO2 display, same shape as HRVStatusView.
struct SpO2StatusView: View {
    let referenceDate: Date
    @State private var integration = SpO2Integration()

    init(referenceDate: Date = Date()) {
        self.referenceDate = referenceDate
    }

    var body: some View {
        // "drop.fill" rather than "lungs.fill": matches Apple's own Health
        // app iconography for blood oxygen (a blood-drop motif); lungs
        // reads more naturally for a future respiratory-rate (M12) metric.
        MetricCard(
            title: "SpO2",
            symbolName: "drop.fill",
            isLoading: integration.isLoading,
            emptyMessage: integration.spo2Status == nil ? integration.statusText : nil
        ) {
            if let status = integration.spo2Status {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Circle()
                            .fill(colorForLevel(status.level))
                            .frame(width: 10, height: 10)
                            .animation(.easeInOut(duration: 0.2), value: status.level)
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(String(format: "%.1f", status.value))
                                .font(.title2.weight(.semibold))
                            Text("%")
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
        .animation(.easeInOut(duration: 0.25), value: integration.spo2Status)
        .task(id: referenceDate) {
            await integration.run(referenceDate: referenceDate)
        }
    }

    /// Same green/yellow/red pattern as HRVStatusView.
    private func colorForLevel(_ level: SpO2StatusLevel) -> Color {
        switch level {
        case .normal: AppTheme.statusNormal
        case .low: AppTheme.statusLow
        case .critical: AppTheme.statusCritical
        }
    }

    private func levelText(_ level: SpO2StatusLevel) -> String {
        switch level {
        case .normal: "Normal"
        case .low: "Low"
        case .critical: "Critical"
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
