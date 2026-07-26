import MetricsCore
import Testing
@testable import WatchMetricsSupport

@Test func rmssdDoesNotCreateDifferenceAcrossSeriesBoundary() {
    let first = [800.0, 810.0].map(RRInterval.init(milliseconds:))
    let second = [1_200.0, 1_190.0].map(RRInterval.init(milliseconds:))

    #expect(SeriesRMSSDAggregator.calculate(from: [first, second]) == 10)
}

@Test func rmssdIsNilWhenEverySeriesIsSparse() {
    let sparse = [[RRInterval(milliseconds: 800)], [RRInterval(milliseconds: 900)]]
    #expect(SeriesRMSSDAggregator.calculate(from: sparse) == nil)
}
