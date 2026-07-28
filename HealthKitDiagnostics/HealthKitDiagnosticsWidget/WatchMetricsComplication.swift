import SwiftUI
import WidgetKit

/// Static product complication — see roadmap section 11:
/// watchOS grants a background-refresh app a much more generous budget when
/// it has an active complication on the current watch face. This
/// complication exists purely to claim that slot; it carries no live data
/// (no HealthKit access, no App Group) — see `BriefDebugPanel` in the main
/// app for actually inspecting brief state.
struct WatchMetricsEntry: TimelineEntry {
    let date: Date
}

struct WatchMetricsProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchMetricsEntry {
        WatchMetricsEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchMetricsEntry) -> Void) {
        completion(WatchMetricsEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchMetricsEntry>) -> Void) {
        // Content never changes, so `.never` — no point spending any of the
        // widget's own refresh budget reloading a static complication.
        completion(Timeline(entries: [WatchMetricsEntry(date: Date())], policy: .never))
    }
}

struct WatchMetricsComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchMetricsProvider.Entry

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("Watch Metrics", systemImage: "waveform.path.ecg")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("Watch Metrics", systemImage: "waveform.path.ecg")
                    .font(.caption.weight(.semibold))
                    .widgetAccentable()
                Text("Daily overview")
                    .font(.caption2)
            }
        case .accessoryCorner:
            Image(systemName: "waveform.path.ecg")
                .widgetAccentable()
                .widgetLabel("Watch Metrics")
        default: // .accessoryCircular and any future accessory family
            Image(systemName: "waveform.path.ecg")
                .widgetAccentable()
        }
    }
}

struct WatchMetricsComplication: Widget {
    private let kind = "WatchMetricsComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchMetricsProvider()) { entry in
            WatchMetricsComplicationView(entry: entry)
                .containerBackground(.indigo.gradient, for: .widget)
        }
        .configurationDisplayName("Watch Metrics")
        .description("Opens your daily health overview.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
