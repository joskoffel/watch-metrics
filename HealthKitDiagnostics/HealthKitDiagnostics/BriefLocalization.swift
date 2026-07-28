import Foundation
import MetricsCore

/// Localizes the structured MetricsCore brief at the presentation boundary.
/// MetricsCore remains deterministic and bundle-independent; notification
/// wording follows the watch language when the notification is created.
enum BriefLocalization {
    static func title(
        _ content: BriefContent,
        locale: Locale = .current,
        bundle: Bundle = .main
    ) -> String {
        content.title == "Dobré ráno"
            ? String(localized: "Good morning", bundle: bundle, locale: locale)
            : content.title
    }

    static func renderLines(
        _ lines: [BriefLine],
        locale: Locale = .current,
        bundle: Bundle = .main
    ) -> String {
        lines.map { renderLine($0, locale: locale, bundle: bundle) }.joined(separator: "\n")
    }

    private static func renderLine(_ line: BriefLine, locale: Locale, bundle: Bundle) -> String {
        var row = "\(localizedLabel(line.label, locale: locale, bundle: bundle)) \(localizedValue(line.value, label: line.label, locale: locale, bundle: bundle))"
        if let qualifier = line.qualifier {
            row += " · \(localizedQualifier(qualifier, locale: locale, bundle: bundle))"
        }
        if line.isProvisional {
            row += " \(String(localized: "(provisional)", bundle: bundle, locale: locale))"
        }
        return row
    }

    private static func localizedLabel(_ label: String, locale: Locale, bundle: Bundle) -> String {
        switch label {
        case "Spánok": String(localized: "Sleep", bundle: bundle, locale: locale)
        case "Pokojový pulz": String(localized: "Resting heart rate", bundle: bundle, locale: locale)
        case "Regenerácia": String(localized: "Recovery", bundle: bundle, locale: locale)
        default: label
        }
    }

    private static func localizedQualifier(_ qualifier: String, locale: Locale, bundle: Bundle) -> String {
        switch qualifier {
        case "znížené": String(localized: "lower", bundle: bundle, locale: locale)
        case "znížený": String(localized: "lower", bundle: bundle, locale: locale)
        case "v norme": String(localized: "within range", bundle: bundle, locale: locale)
        case "zvýšené": String(localized: "higher", bundle: bundle, locale: locale)
        case "zvýšený": String(localized: "higher", bundle: bundle, locale: locale)
        case "kriticky nízke": String(localized: "critically low", bundle: bundle, locale: locale)
        default: qualifier
        }
    }

    private static func localizedValue(_ value: String, label: String, locale: Locale, bundle: Bundle) -> String {
        guard label == "Regenerácia" else { return value }
        return switch value {
        case "nižšia než obvykle": String(localized: "lower than usual", bundle: bundle, locale: locale)
        case "zmiešaný signál": String(localized: "mixed signal", bundle: bundle, locale: locale)
        case "v osobnej norme": String(localized: "within personal range", bundle: bundle, locale: locale)
        case "priaznivá": String(localized: "favorable", bundle: bundle, locale: locale)
        default: value
        }
    }
}
