import SwiftUI

/// Main diagnostic screen: a night picker, plus HRV and SpO2 together for
/// whichever night is selected, each with its own HealthKit query/
/// authorization (via HRVStatusView/SpO2StatusView), same green/yellow/red
/// status-color pattern for both.
///
/// Night selection uses a Digital Crown-scrollable wheel Picker, embedded
/// directly in this view, rather than a List + NavigationLink to a separate
/// per-night screen. A NavigationLink push would mean HRV/SpO2 for a
/// historical night live on a *different* screen than "today" — but the
/// requirement is that this same overview re-renders in place for whichever
/// night is selected, and a wheel Picker is the standard watchOS idiom for
/// choosing one value from a small enumerable set (here: the last 14
/// nights) without leaving the current screen.
struct MetricsOverviewView: View {
    private let nightCount = 14

    /// Days back from tonight; 0 = tonight/today.
    @State private var selectedNightOffset = 0

    private var referenceDate: Date {
        Calendar.current.date(byAdding: .day, value: -selectedNightOffset, to: Date()) ?? Date()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Noc", selection: $selectedNightOffset) {
                    ForEach(0..<nightCount, id: \.self) { offset in
                        Text(pickerLabel(forOffset: offset)).tag(offset)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 60)

                Text(nightRangeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HRVStatusView(referenceDate: referenceDate)
                Divider()
                SpO2StatusView(referenceDate: referenceDate)
            }
        }
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
    /// not a live "right now" reading.
    private var nightRangeLabel: String {
        let calendar = Calendar.current
        let nightEnd = calendar.startOfDay(for: referenceDate)
        let nightStartDay = calendar.date(byAdding: .day, value: -1, to: nightEnd) ?? nightEnd
        let formatter = DateFormatter()
        formatter.dateFormat = "d.M."
        return "Noc \(formatter.string(from: nightStartDay))–\(formatter.string(from: nightEnd))"
    }
}
