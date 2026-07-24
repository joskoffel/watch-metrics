import Foundation
import Testing
@testable import MetricsCore

@Test func decodesSparseNightHRVFixtureIntoSensorSamples() throws {
    let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/night_sparse_hrv.json")

    let data = try Data(contentsOf: fixtureURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let samples = try decoder.decode([SensorSample].self, from: data)

    #expect(samples.count == 5)
    #expect(samples.allSatisfy { $0.kind == .heartRateVariabilitySDNN })
    #expect(samples.allSatisfy { $0.unit == .milliseconds })
    #expect(samples.allSatisfy { (20.0...80.0).contains($0.value) })
    #expect(samples.map(\.timestamp) == samples.map(\.timestamp).sorted())
}
