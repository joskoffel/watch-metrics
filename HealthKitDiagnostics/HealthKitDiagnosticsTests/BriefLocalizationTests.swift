import Foundation
import MetricsCore
import Testing
@testable import WatchMetrics

struct BriefLocalizationTests {
    private var appBundle: Bundle {
        Bundle.allBundles.first { $0.bundleIdentifier == "com.watchmetrics.WatchMetrics" } ?? .main
    }

    private func localizedBundle(_ language: String) -> Bundle {
        guard
            let path = appBundle.path(forResource: language, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return appBundle
        }
        return bundle
    }

    private let content = BriefContent(
        title: "Dobré ráno",
        lines: [
            BriefLine(label: "Spánok", value: "7 h 42 min", qualifier: nil, isProvisional: false),
            BriefLine(label: "HRV", value: "48 ms", qualifier: "znížené", isProvisional: true),
            BriefLine(label: "Pokojový pulz", value: "54 bpm", qualifier: "v norme", isProvisional: false),
            BriefLine(label: "SpO₂", value: "97 %", qualifier: nil, isProvisional: false),
            BriefLine(label: "Regenerácia", value: "priaznivá", qualifier: nil, isProvisional: false)
        ]
    )

    @Test
    func rendersNativeEnglishNotificationCopy() {
        let bundle = localizedBundle("en")
        #expect(BriefLocalization.title(content, locale: Locale(identifier: "en"), bundle: bundle) == "Good morning")
        #expect(
            BriefLocalization.renderLines(content.lines, locale: Locale(identifier: "en"), bundle: bundle) ==
                """
                Sleep 7 h 42 min
                HRV 48 ms · lower (provisional)
                Resting heart rate 54 bpm · within range
                SpO₂ 97 %
                Recovery favorable
                """
        )
    }

    @Test
    func preservesEstablishedSlovakNotificationCopy() {
        let bundle = localizedBundle("sk")
        #expect(BriefLocalization.title(content, locale: Locale(identifier: "sk"), bundle: bundle) == "Dobré ráno")
        #expect(
            BriefLocalization.renderLines(content.lines, locale: Locale(identifier: "sk"), bundle: bundle) ==
                """
                Spánok 7 h 42 min
                HRV 48 ms · znížené (orientačne)
                Pokojový pulz 54 bpm · v norme
                SpO₂ 97 %
                Regenerácia priaznivá
                """
        )
    }
}
