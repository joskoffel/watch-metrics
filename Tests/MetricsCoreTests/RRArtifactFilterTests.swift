import Testing
@testable import MetricsCore

@Test func rrArtifactFilterRemovesClearOutlierAndKeepsNormalValues() {
    // Normal beat-to-beat RR around 780-820ms; one artifact ~3x that,
    // clearly outside both the physiological range (300-2000ms) and the
    // 20% successive-change threshold.
    let intervals = [800.0, 810.0, 790.0, 2400.0, 805.0, 795.0].map { RRInterval(milliseconds: $0) }
    let filtered = RRArtifactFilter.filter(intervals)
    #expect(filtered.map(\.milliseconds) == [800.0, 810.0, 790.0, 805.0, 795.0])
}

@Test func rrArtifactFilterKeepsAllValuesWhenNoArtifactsPresent() {
    let intervals = [800.0, 810.0, 790.0, 805.0, 795.0].map { RRInterval(milliseconds: $0) }
    let filtered = RRArtifactFilter.filter(intervals)
    #expect(filtered.map(\.milliseconds) == intervals.map(\.milliseconds))
}

@Test func rrArtifactFilterRejectsValuesOutsidePhysiologicalRange() {
    let intervals = [800.0, 250.0, 810.0, 2100.0, 790.0].map { RRInterval(milliseconds: $0) }
    let filtered = RRArtifactFilter.filter(intervals)
    #expect(filtered.map(\.milliseconds) == [800.0, 810.0, 790.0])
}

@Test func rrArtifactFilterRejectsSuddenRelativeJumpWithinPhysiologicalRange() {
    // 1000ms is within the 300-2000ms absolute range but a 26.6% jump from
    // the preceding accepted 790ms — over the 20% successive-change
    // threshold, so this isolates the relative-jump rule from the
    // absolute-range rule.
    let intervals = [800.0, 810.0, 790.0, 1000.0, 805.0].map { RRInterval(milliseconds: $0) }
    let filtered = RRArtifactFilter.filter(intervals)
    #expect(filtered.map(\.milliseconds) == [800.0, 810.0, 790.0, 805.0])
}

@Test func rrArtifactFilterHandlesEmptyInput() {
    #expect(RRArtifactFilter.filter([]).isEmpty)
}
