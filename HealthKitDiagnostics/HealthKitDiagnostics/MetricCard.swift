import SwiftUI

/// Shared card chrome for HRV/SpO2 (and future metrics): consistent
/// padding/background/corner radius, and a fixed-height content area so
/// loading, empty, and value states never change the card's size — the
/// screen shouldn't visibly "jump" when a night finishes loading or turns
/// out to have no data.
struct MetricCard<Content: View>: View {
    let title: String
    let symbolName: String
    let isLoading: Bool
    let emptyMessage: String?
    @ViewBuilder let content: () -> Content

    private let contentHeight: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbolName)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.accent)

            Group {
                if isLoading {
                    PulsingSkeleton()
                } else if let emptyMessage {
                    Text(emptyMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    content()
                }
            }
            .frame(height: contentHeight, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppTheme.cardBackground,
            in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
        )
        .animation(.easeInOut(duration: 0.25), value: isLoading)
        .animation(.easeInOut(duration: 0.25), value: emptyMessage)
    }
}

/// Subtle pulsing placeholder for the loading state — deliberately quiet
/// (slow opacity pulse, no spinner/motion): watchOS favors calm, cheap
/// animations for battery life and readability while the wrist is moving.
struct PulsingSkeleton: View {
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 6)
                .frame(width: 90, height: 22)
            RoundedRectangle(cornerRadius: 4)
                .frame(width: 130, height: 10)
        }
        .foregroundStyle(AppTheme.accent.opacity(pulse ? 0.35 : 0.15))
        .task {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
