import Foundation
import Testing
@testable import MetricsCore

private func t(_ isoDate: String) -> Date {
    ISO8601DateFormatter().date(from: isoDate)!
}

@Test func sleepSessionBuilderMergesAdjacentStageSegments() {
    let samples = [
        SleepSample(start: t("2026-07-16T22:00:00Z"), end: t("2026-07-16T23:30:00Z"), stage: .asleepCore),
        SleepSample(start: t("2026-07-16T23:30:00Z"), end: t("2026-07-17T01:00:00Z"), stage: .asleepDeep),
        SleepSample(start: t("2026-07-17T01:00:00Z"), end: t("2026-07-17T02:30:00Z"), stage: .asleepREM)
    ]

    let sessions = SleepSessionBuilder.build(from: samples)

    #expect(sessions.count == 1)
    #expect(sessions.first?.start == t("2026-07-16T22:00:00Z"))
    #expect(sessions.first?.end == t("2026-07-17T02:30:00Z"))
}

@Test func sleepSessionBuilderShortAwakeGapDoesNotSplitSession() {
    let samples = [
        SleepSample(start: t("2026-07-16T22:00:00Z"), end: t("2026-07-16T23:00:00Z"), stage: .asleepCore),
        SleepSample(start: t("2026-07-16T23:00:00Z"), end: t("2026-07-16T23:30:00Z"), stage: .awake),
        SleepSample(start: t("2026-07-16T23:30:00Z"), end: t("2026-07-17T01:00:00Z"), stage: .asleepDeep)
    ]

    let sessions = SleepSessionBuilder.build(from: samples)

    #expect(sessions.count == 1)
    #expect(sessions.first?.start == t("2026-07-16T22:00:00Z"))
    #expect(sessions.first?.end == t("2026-07-17T01:00:00Z"))
}

@Test func sleepSessionBuilderLongAwakeGapSplitsIntoTwoSessions() {
    let samples = [
        SleepSample(start: t("2026-07-16T22:00:00Z"), end: t("2026-07-16T23:00:00Z"), stage: .asleepCore),
        SleepSample(start: t("2026-07-16T23:00:00Z"), end: t("2026-07-17T00:30:00Z"), stage: .awake),
        SleepSample(start: t("2026-07-17T00:30:00Z"), end: t("2026-07-17T02:00:00Z"), stage: .asleepDeep)
    ]

    let sessions = SleepSessionBuilder.build(from: samples)

    #expect(sessions.count == 2)
    #expect(sessions[0] == SleepSession(start: t("2026-07-16T22:00:00Z"), end: t("2026-07-16T23:00:00Z")))
    #expect(sessions[1] == SleepSession(start: t("2026-07-17T00:30:00Z"), end: t("2026-07-17T02:00:00Z")))
}

@Test func sleepSessionBuilderExcludesAwakeAndInBedFromDuration() {
    let samples = [
        SleepSample(start: t("2026-07-16T22:00:00Z"), end: t("2026-07-16T22:15:00Z"), stage: .inBed),
        SleepSample(start: t("2026-07-16T22:15:00Z"), end: t("2026-07-16T23:00:00Z"), stage: .asleepCore),
        SleepSample(start: t("2026-07-16T23:00:00Z"), end: t("2026-07-16T23:05:00Z"), stage: .awake),
        SleepSample(start: t("2026-07-16T23:05:00Z"), end: t("2026-07-17T01:00:00Z"), stage: .asleepDeep)
    ]

    let sessions = SleepSessionBuilder.build(from: samples)

    #expect(sessions.count == 1)
    #expect(sessions.first?.start == t("2026-07-16T22:15:00Z"))
    #expect(sessions.first?.end == t("2026-07-17T01:00:00Z"))
}

@Test func sleepSessionBuilderReturnsEmptyForEmptyInput() {
    #expect(SleepSessionBuilder.build(from: []).isEmpty)
}

@Test func sleepSessionBuilderReturnsEmptyWhenOnlyAwakeAndInBedSamples() {
    let samples = [
        SleepSample(start: t("2026-07-16T22:00:00Z"), end: t("2026-07-16T22:15:00Z"), stage: .inBed),
        SleepSample(start: t("2026-07-16T22:15:00Z"), end: t("2026-07-16T22:30:00Z"), stage: .awake)
    ]

    #expect(SleepSessionBuilder.build(from: samples).isEmpty)
}
