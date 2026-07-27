import Foundation

/// One line of the morning brief, kept as structured data (not a
/// pre-formatted string) so its content is testable independent of how the
/// renderer lays it out.
public struct BriefLine: Equatable {
    public let label: String
    public let value: String
    public let qualifier: String?
    public let isProvisional: Bool

    public init(label: String, value: String, qualifier: String?, isProvisional: Bool) {
        self.label = label
        self.value = value
        self.qualifier = qualifier
        self.isProvisional = isProvisional
    }
}

public struct BriefContent: Equatable {
    public let title: String
    public let lines: [BriefLine]

    public init(title: String, lines: [BriefLine]) {
        self.title = title
        self.lines = lines
    }
}

/// Turns a `NightSummary` into `BriefContent`.
///
/// The sleep-duration line is always first and always present. Recovery is a
/// concise optional interpretation of HRV/RHR; the underlying metric lines
/// stay present on their own. The result is capped at 5 lines for on-wrist
/// readability.
public enum BriefComposer {
    private static let maxLines = 5

    public static func compose(from summary: NightSummary) -> BriefContent {
        var lines = [sleepLine(for: summary.sleep)]

        if let hrv = summary.hrv {
            lines.append(hrvLine(for: hrv))
        }
        if let rhr = summary.rhr {
            lines.append(rhrLine(for: rhr))
        }
        if let recovery = summary.recovery {
            lines.append(recoveryLine(for: recovery))
        }
        if let spo2 = summary.spo2 {
            lines.append(spo2Line(for: spo2))
        }

        return BriefContent(title: "Dobré ráno", lines: Array(lines.prefix(maxLines)))
    }

    private static func sleepLine(for session: SleepSession) -> BriefLine {
        let totalMinutes = Int(session.asleepDuration / 60)
        let value = "\(totalMinutes / 60) h \(totalMinutes % 60) min"
        return BriefLine(label: "Spánok", value: value, qualifier: nil, isProvisional: false)
    }

    private static func hrvLine(for status: HRVStatus) -> BriefLine {
        let qualifier: String
        switch status.level {
        case .low: qualifier = "znížené"
        case .normal: qualifier = "v norme"
        case .high: qualifier = "zvýšené"
        }
        return BriefLine(
            label: "HRV",
            value: "\(Int(status.value.rounded())) ms",
            qualifier: qualifier,
            isProvisional: status.confidence == .low
        )
    }

    private static func rhrLine(for status: RHRStatus) -> BriefLine {
        let qualifier: String
        switch status.level {
        case .suppressed: qualifier = "znížený"
        case .normal: qualifier = "v norme"
        case .elevated: qualifier = "zvýšený"
        }
        return BriefLine(
            label: "Pokojový pulz",
            value: "\(Int(status.value.rounded()))",
            qualifier: qualifier,
            isProvisional: status.confidence == .low
        )
    }

    private static func recoveryLine(for signal: RecoverySignal) -> BriefLine {
        BriefLine(label: "Regenerácia", value: signal.briefText, qualifier: nil, isProvisional: false)
    }

    /// `isProvisional` is always `false` here, unlike HRV/RHR: SpO2's
    /// `confidence` reflects available trend context only, not the
    /// trustworthiness of `level` (see `SpO2Status.confidence`'s doc
    /// comment) — a low-confidence critical reading must still read as a
    /// plain, non-provisional line.
    private static func spo2Line(for status: SpO2Status) -> BriefLine {
        let qualifier: String
        switch status.level {
        case .normal: qualifier = "v norme"
        case .low: qualifier = "znížené"
        case .critical: qualifier = "kriticky nízke"
        }
        return BriefLine(
            label: "SpO₂",
            value: "\(Int(status.value.rounded())) %",
            qualifier: qualifier,
            isProvisional: false
        )
    }
}

/// Renders `BriefContent` into plain text.
public enum BriefRenderer {
    /// Full notification text: title followed by every line.
    public static func render(_ content: BriefContent) -> String {
        ([content.title] + content.lines.map(renderLine)).joined(separator: "\n")
    }

    /// Just the lines, no title — for hosts (e.g. `UNNotificationContent`)
    /// that carry the title in a separate field already.
    public static func renderLines(_ lines: [BriefLine]) -> String {
        lines.map(renderLine).joined(separator: "\n")
    }

    private static func renderLine(_ line: BriefLine) -> String {
        var row = "\(line.label) \(line.value)"
        if let qualifier = line.qualifier {
            row += " · \(qualifier)"
        }
        if line.isProvisional {
            row += " (orientačne)"
        }
        return row
    }
}
