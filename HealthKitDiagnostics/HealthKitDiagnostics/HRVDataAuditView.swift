import SwiftUI
import WatchMetricsSupport

struct HRVDataAuditView: View {
    @State private var store = HRVDataAuditStore()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if store.isLoading {
                    ProgressView(value: store.progress) {
                        Text(store.totalNightCount == 0
                            ? "Hľadám hlavné spánky…"
                            : "Analyzujem noc \(store.completedNightCount + 1) z \(store.totalNightCount)")
                            .font(.caption2)
                    }
                    Button("Zrušiť", role: .cancel) { store.cancel() }
                }

                if let error = store.errorText {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let summary = store.summary {
                    summaryView(summary)
                }

                ForEach(store.nights) { night in
                    nightView(night)
                }

                if !store.isLoading {
                    Button("Spustiť 28-nočný audit") { store.start() }
                }
            }
            .padding(.horizontal, 6)
        }
        .navigationTitle("HRV Data Audit")
        .task {
            if store.nights.isEmpty && store.errorText == nil { store.start() }
        }
    }

    private func summaryView(_ summary: HRVDataAuditSummary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Pokrytie").font(.headline)
            Text("Spánok \(summary.sleepNightCount) nocí")
            Text("SDNN \(summary.sdnnNightCount)/\(summary.sleepNightCount) · RMSSD \(summary.rmssdNightCount)/\(summary.sleepNightCount)")
            Text("Medián: \(summary.medianSeriesPerNight.formatted()) sérií · \(summary.medianAcceptedRRPerNight.formatted()) RR")
            Text("Riedke/chybné: \(summary.sparseOrFaultyNightCount)")
        }
        .font(.caption)
        .cardStyle()
    }

    private func nightView(_ night: HRVDataAuditNight) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(night.day.formatted(.dateTime.weekday(.abbreviated).day().month()))
                .font(.footnote.weight(.semibold))
            Text("SDNN \(metric(night.sdnn)) · RMSSD \(metric(night.heartbeat.rmssd))")
            Text("Série \(night.heartbeat.seriesCount) · RR \(night.heartbeat.acceptedIntervals.count)/\(night.heartbeat.rawIntervals.count) prijatých")
            ForEach(night.heartbeat.unusableSeries) { failure in
                Text(
                    "Séria \(failure.seriesIndex) (\(failure.seriesStart.formatted(date: .omitted, time: .shortened))): \(failure.reason)"
                )
                .foregroundStyle(.yellow)
            }
            if let hr = night.heartRate {
                Text("HR \(Int(hr.median.rounded())) bpm · low \(hr.robustLow.map { String(Int($0.rounded())) } ?? "—") · tretiny \(coverage(hr))")
                Text(hr.supportsSettlingTrend ? "Settling trend: použiteľný" : "Settling trend: málo dát")
            } else {
                Text("Nočný pulz: bez vzoriek")
            }
            if night.facts.isSparseOrFaulty {
                Label("Riedke alebo chybné dáta", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.yellow)
            }
        }
        .font(.caption2)
        .cardStyle()
    }

    private func metric(_ value: Double?) -> String {
        value.map { "\(Int($0.rounded())) ms" } ?? "—"
    }

    private func coverage(_ audit: NightHeartRateAudit) -> String {
        [
            audit.coverage.first ? "✓" : "–",
            audit.coverage.middle ? "✓" : "–",
            audit.coverage.last ? "✓" : "–"
        ].joined()
    }
}
