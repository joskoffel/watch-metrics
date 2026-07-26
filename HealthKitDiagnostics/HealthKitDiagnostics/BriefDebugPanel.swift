import SwiftUI
import MetricsCore

/// Debug trigger screen (spec step 6): runs the exact same
/// `BriefDeliveryPolicy`/`BriefNotifier` pipeline a scheduled background
/// run would, on demand — see `BriefRunner`. Lets the whole pipeline
/// (composed text, notification delivery, dedupe write) get verified in
/// minutes instead of waiting for tomorrow morning; only the actual
/// background scheduling (step 7) still needs real overnight runs to confirm.
struct BriefDebugPanel: View {
    @State private var runner = BriefRunner()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Label("Ranný brief", systemImage: "bell.badge")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)

                triggerButton

                if let decision = runner.lastDecision {
                    decisionCard(decision)
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 2)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    private var triggerButton: some View {
        Button {
            Task { await runner.runNow() }
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
