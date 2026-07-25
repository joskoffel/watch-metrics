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
        VStack(spacing: 8) {
            Text("SpO2")
                .font(.headline)
            if integration.isLoading {
                ProgressView()
            } else if let status = integration.spo2Status {
                HStack(spacing: 6) {
                    Circle()
                        .fill(colorForLevel(status.level))
                        .frame(width: 12, height: 12)
                    Text("\(String(format: "%.1f", status.value))%")
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
        .task(id: referenceDate) {
            await integration.run(referenceDate: referenceDate)
        }
    }

    /// Same green/yellow/red pattern as HRVStatusView.
    private func colorForLevel(_ level: SpO2StatusLevel) -> Color {
        switch level {
        case .normal: .green
        case .low: .yellow
        case .critical: .red
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
