import SwiftUI

/// Main diagnostic screen: a compact night stepper, plus HRV and SpO2 as
/// separate cards for whichever night is selected, each with its own
/// HealthKit query/authorization (via HRVStatusView/SpO2StatusView).
///
/// Night selection is a compact "‹ label ›" stepper, not a wheel Picker or
/// a List + NavigationLink: both cards need to be visible at a glance right
/// after opening the app, without scrolling past a big control first — a
/// full-height wheel Picker would eat the vertical space the cards need on
/// a watch screen. A NavigationLink push was also ruled out since the
/// requirement is that this same screen re-renders in place for whichever
/// night is picked, not a separate per-night page. The stepper still keeps
/// everything on one screen and stays reachable via the same tap target
/// pattern watchOS uses elsewhere for compact value adjustment.
struct MetricsOverviewView: View {
    private let nightCount = 14

    /// Days back from tonight; 0 = tonight/today.
    @State private var selectedNightOffset = 0

    private var referenceDate: Date {
        Calendar.current.date(byAdding: .day, value: -selectedNightOffset, to: Date()) ?? Date()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                nightStepper
                HRVStatusView(referenceDate: referenceDate)
                SpO2StatusView(referenceDate: referenceDate)
            }
            .padding(.horizontal, 6)
            .padding(.top, 2)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    private var nightStepper: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedNightOffset = min(selectedNightOffset + 1, nightCount - 1)
                }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(selectedNightOffset >= nightCount - 1)

            Spacer(minLength: 4)

            VStack(spacing: 0) {
                Text(pickerLabel(forOffset: selectedNightOffset))
                    .font(.footnote.weight(.semibold))
                Text(nightRangeLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .contentTransition(.opacity)

            Spacer(minLength: 4)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedNightOffset = max(selectedNightOffset - 1, 0)
                }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(selectedNightOffset <= 0)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.accent)
        .animation(.easeInOut(duration: 0.2), value: selectedNightOffset)
    }

    private func pickerLabel(forOffset offset: Int) -> String {
        switch offset {
        case 0: "Dnes"
        case 1: "Včera"
        default: shortDateLabel(for: dateForOffset(offset))
        }
    }

    private func dateForOffset(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
    }

    private func shortDateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d.M."
        return formatter.string(from: date)
    }

    /// "Noc {previous day}.–{selected day}." — makes explicit that the
    /// displayed values are a nightly summary spanning two calendar dates,
    /// not a live "right now" reading. Shown once here rather than
    /// repeated on both cards below, since it applies to both equally.
    private var nightRangeLabel: String {
        let calendar = Calendar.current
        let nightEnd = calendar.startOfDay(for: referenceDate)
        let nightStartDay = calendar.date(byAdding: .day, value: -1, to: nightEnd) ?? nightEnd
        let formatter = DateFormatter()
        formatter.dateFormat = "d.M."
        return "Noc \(formatter.string(from: nightStartDay))–\(formatter.string(from: nightEnd))"
    }
}
