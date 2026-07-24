import Testing
@testable import MetricsCore

@Test func rmssdMatchesHandComputedValueForFourIntervals() {
    // RR intervals: 800, 810, 790, 805 ms
    // successive diffs: 10, -20, 15 → squares: 100, 400, 225 → sum 725
    // mean square = 725/3 = 241.6667 → sqrt ≈ 15.5456 ms (hand-verified)
    let intervals = [800.0, 810.0, 790.0, 805.0].map { RRInterval(milliseconds: $0) }
    let result = RMSSD.calculate(from: intervals)
    #expect(result != nil)
    #expect(abs(result! - 15.5456) < 0.001)
}

@Test func rmssdIsZeroForTwoIdenticalIntervals() {
    let intervals = [RRInterval(milliseconds: 800), RRInterval(milliseconds: 800)]
    #expect(RMSSD.calculate(from: intervals) == 0)
}

@Test func rmssdReturnsNilForEmptyIntervals() {
    #expect(RMSSD.calculate(from: []) == nil)
}

@Test func rmssdReturnsNilForSingleInterval() {
    #expect(RMSSD.calculate(from: [RRInterval(milliseconds: 800)]) == nil)
}
