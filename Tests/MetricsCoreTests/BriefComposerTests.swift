import Foundation
import Testing
@testable import MetricsCore

@Test func briefComposerAddsOneRecoveryLineWhenSignalIsAvailable() {
    let summary = NightSummary(
        sleep: sevenHoursTwelveMinutesSleep(),
        hrv: HRVStatus(value: 40, level: .low, confidence: .high),
        rhr: RHRStatus(value: 65, level: .elevated, confidence: .high),
        spo2: nil
    )

    let lines = BriefComposer.compose(from: summary).lines.filter { $0.label == "Regenerácia" }

    #expect(lines == [BriefLine(label: "Regenerácia", value: "nižšia než obvykle", qualifier: nil, isProvisional: false)])
}

@Test func briefComposerOmitsRecoveryLineWhenSignalIsUnavailable() {
    let summary = NightSummary(
        sleep: sevenHoursTwelveMinutesSleep(),
        hrv: HRVStatus(value: 40, level: .low, confidence: .low),
        rhr: RHRStatus(value: 65, level: .elevated, confidence: .high),
        spo2: nil
    )

    #expect(BriefComposer.compose(from: summary).lines.allSatisfy { $0.label != "Regenerácia" })
}

private func t(_ isoDate: String) -> Date {
    ISO8601DateFormatter().date(from: isoDate)!
}

private func sevenHoursTwelveMinutesSleep() -> SleepSession {
    SleepSession(
        start: t("2026-07-15T23:00:00Z"),
        end: t("2026-07-16T06:12:00Z"),
        asleepDuration: 7 * 60 * 60 + 12 * 60
    )
}

@Test func briefComposerIncludesAllLinesWhenAllMetricsPresent() {
    let summary = NightSummary(
        sleep: sevenHoursTwelveMinutesSleep(),
        hrv: HRVStatus(value: 48, level: .normal, confidence: .high),
        rhr: RHRStatus(value: 52, level: .elevated, confidence: .high),
        spo2: SpO2Status(value: 96, level: .normal, confidence: .high)
    )

    let content = BriefComposer.compose(from: summary)

    #expect(content.title == "Dobré ráno")
    #expect(content.lines.count == 5)
    #expect(content.lines[0] == BriefLine(label: "Spánok", value: "7 h 12 min", qualifier: nil, isProvisional: false))
    #expect(content.lines[1].label == "HRV")
    #expect(content.lines[2].label == "Pokojový pulz")
    #expect(content.lines[3].label == "Regenerácia")
    #expect(content.lines[4].label == "SpO₂")
}

@Test func briefComposerDisplaysActualAsleepDurationInsteadOfSessionBounds() {
    let summary = NightSummary(
        sleep: SleepSession(
            start: t("2026-07-15T22:00:00Z"),
            end: t("2026-07-16T06:00:00Z"),
            asleepDuration: 6.5 * 60 * 60
        ),
        hrv: nil,
        rhr: nil,
        spo2: nil
    )

    let content = BriefComposer.compose(from: summary)

    #expect(content.lines[0].value == "6 h 30 min")
}

@Test func briefComposerOmitsMissingMetric() {
    let summary = NightSummary(
        sleep: sevenHoursTwelveMinutesSleep(),
        hrv: HRVStatus(value: 48, level: .normal, confidence: .high),
        rhr: nil,
        spo2: SpO2Status(value: 96, level: .normal, confidence: .high)
    )

    let content = BriefComposer.compose(from: summary)

    #expect(content.lines.map(\.label) == ["Spánok", "HRV", "SpO₂"])
}

@Test func briefComposerMarksLowConfidenceHRVAsProvisional() {
    let summary = NightSummary(
        sleep: sevenHoursTwelveMinutesSleep(),
        hrv: HRVStatus(value: 48, level: .normal, confidence: .low),
        rhr: nil,
        spo2: nil
    )

    let content = BriefComposer.compose(from: summary)

    #expect(content.lines[1].isProvisional == true)
}

@Test func briefComposerKeepsHighConfidenceHRVNonProvisional() {
    let summary = NightSummary(
        sleep: sevenHoursTwelveMinutesSleep(),
        hrv: HRVStatus(value: 48, level: .normal, confidence: .high),
        rhr: nil,
        spo2: nil
    )

    let content = BriefComposer.compose(from: summary)

    #expect(content.lines[1].isProvisional == false)
}

@Test func briefComposerNeverMarksSpO2AsProvisionalEvenWithLowConfidence() {
    let summary = NightSummary(
        sleep: sevenHoursTwelveMinutesSleep(),
        hrv: nil,
        rhr: nil,
        spo2: SpO2Status(value: 87, level: .critical, confidence: .low)
    )

    let content = BriefComposer.compose(from: summary)

    #expect(content.lines[1].label == "SpO₂")
    #expect(content.lines[1].isProvisional == false)
}

@Test func briefComposerNeverExceedsFiveLines() {
    let summary = NightSummary(
        sleep: sevenHoursTwelveMinutesSleep(),
        hrv: HRVStatus(value: 48, level: .normal, confidence: .high),
        rhr: RHRStatus(value: 52, level: .elevated, confidence: .high),
        spo2: SpO2Status(value: 96, level: .normal, confidence: .high)
    )

    let content = BriefComposer.compose(from: summary)

    #expect(content.lines.count <= 5)
}

@Test func briefRendererFormatsContentWithQualifiersAndProvisionalSuffix() {
    let content = BriefContent(
        title: "Dobré ráno",
        lines: [
            BriefLine(label: "Spánok", value: "7 h 12 min", qualifier: nil, isProvisional: false),
            BriefLine(label: "HRV", value: "48 ms", qualifier: "v norme", isProvisional: true)
        ]
    )

    let text = BriefRenderer.render(content)

    #expect(text == "Dobré ráno\nSpánok 7 h 12 min\nHRV 48 ms · v norme (orientačne)")
}

@Test func briefRendererRenderLinesOmitsTitle() {
    let content = BriefContent(
        title: "Dobré ráno",
        lines: [
            BriefLine(label: "Spánok", value: "7 h 12 min", qualifier: nil, isProvisional: false),
            BriefLine(label: "HRV", value: "48 ms", qualifier: "v norme", isProvisional: true)
        ]
    )

    let text = BriefRenderer.renderLines(content.lines)

    #expect(text == "Spánok 7 h 12 min\nHRV 48 ms · v norme (orientačne)")
}
