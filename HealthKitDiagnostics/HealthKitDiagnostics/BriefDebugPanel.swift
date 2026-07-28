import SwiftUI
import MetricsCore

#if DEBUG
/// Debug trigger screen (spec step 6): runs the exact same
/// `BriefDeliveryPolicy`/`BriefNotifier` pipeline a scheduled background
/// run would, on demand — see `BriefRunner`. Lets the whole pipeline
/// (composed text, notification delivery, dedupe write) get verified in
/// minutes instead of waiting for tomorrow morning; only the actual
/// background scheduling (step 7) still needs real overnight runs to confirm.
struct BriefDebugPanel: View {
    @State private var runner = BriefRunner()
    @State private var diagnostics = BriefDiagnosticsStore().snapshot()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Label("Ranný brief", systemImage: "bell.badge")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)

                triggerButton

                automaticStatusCard

                if let decision = runner.lastDecision {
                    decisionCard(decision)
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 2)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear { diagnostics = BriefDiagnosticsStore().snapshot() }
    }

    private var triggerButton: some View {
        Button {
            Task { _ = await runner.runDebug() }
        } label: {
            if runner.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text("Spustiť brief teraz")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(AppTheme.accent)
        .disabled(runner.isLoading)
    }

    private var automaticStatusCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Automatické pokusy")
                .font(.footnote.weight(.semibold))
            diagnosticLine("Posledný", value: timestamp(diagnostics.lastAttemptDate, with: diagnostics.lastAttemptSource))
            diagnosticLine("Výsledok", value: diagnostics.lastOutcome ?? "Zatiaľ žiadny")
            diagnosticLine("Deduplikácia", value: diagnostics.wasDeduped ? "Áno" : "Nie")
            diagnosticLine("Hlavný spánok", value: timestamp(diagnostics.resolvedMainSleepEnd))
            diagnosticLine("Plán doručenia", value: timestamp(diagnostics.intendedDeliveryDate))
            diagnosticLine("Lokálny fallback", value: fallbackStatus)
            if let error = diagnostics.notificationError {
                diagnosticLine("Notifikácia", value: "Zlyhala: \(error)")
            }
            diagnosticLine("Ďalší", value: timestamp(diagnostics.nextRefreshDate))
            diagnosticLine("Sleep observer", value: timestamp(diagnostics.lastObserverTriggerDate))
            diagnosticLine("Observer výsledok", value: diagnostics.lastObserverOutcome ?? "Zatiaľ žiadny")
            diagnosticLine("Sleep background", value: diagnostics.sleepBackgroundDeliveryStatus ?? "Neoverené")
            if let error = diagnostics.schedulingError {
                diagnosticLine("Plánovanie", value: "Zlyhalo: \(error)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            AppTheme.cardBackground,
            in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
        )
    }

    private func diagnosticLine(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2.weight(.semibold))
            Text(value).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func timestamp(_ date: Date?, with source: String? = nil) -> String {
        guard let date else { return "Zatiaľ žiadny" }
        let formatted = date.formatted(date: .abbreviated, time: .shortened)
        return source.map { "\(formatted) (\($0))" } ?? formatted
    }

    private var fallbackStatus: String {
        let fire = timestamp(diagnostics.fallbackFireDate)
        let status = diagnostics.fallbackStatus ?? "Zatiaľ nevyhodnotený"
        return diagnostics.fallbackFireDate == nil ? status : "\(fire) — \(status)"
    }

    /// Shows the policy's raw decision category at a glance (color-coded
    /// dot + deliver/retry/skip) plus `runner.statusText` for the reason —
    /// the spec asks for "decision + dôvod (reason)" together, and
    /// `BriefRunner` already renders the reason into `statusText`, so this
    /// view doesn't re-derive it.
    private func decisionCard(_ decision: BriefDecision) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color(for: decision))
                    .frame(width: 10, height: 10)
                Text(categoryLabel(for: decision))
                    .font(.footnote.weight(.semibold))
            }
            Text(runner.statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            AppTheme.cardBackground,
            in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
        )
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: decision)
    }

    private func categoryLabel(for decision: BriefDecision) -> String {
        switch decision {
        case .deliver: "Deliver"
        case .retry: "Retry"
        case .skip: "Skip"
        }
    }

    private func color(for decision: BriefDecision) -> Color {
        switch decision {
        case .deliver: AppTheme.statusNormal
        case .retry: AppTheme.statusLow
        case .skip: AppTheme.statusCritical
        }
    }
}
#endif
