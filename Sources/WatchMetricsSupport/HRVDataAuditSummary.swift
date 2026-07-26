public struct NightAuditFacts: Equatable, Sendable {
    public let sdnnSampleCount: Int
    public let heartbeatSeriesCount: Int
    public let rawRRCount: Int
    public let acceptedRRCount: Int
    public let hasRMSSD: Bool

    public init(
        sdnnSampleCount: Int,
        heartbeatSeriesCount: Int,
        rawRRCount: Int,
        acceptedRRCount: Int,
        hasRMSSD: Bool
    ) {
        self.sdnnSampleCount = sdnnSampleCount
        self.heartbeatSeriesCount = heartbeatSeriesCount
        self.rawRRCount = rawRRCount
        self.acceptedRRCount = acceptedRRCount
        self.hasRMSSD = hasRMSSD
    }

    public var acceptanceRatio: Double? {
        rawRRCount > 0 ? Double(acceptedRRCount) / Double(rawRRCount) : nil
    }

    public var isSparseOrFaulty: Bool {
        heartbeatSeriesCount == 0 ||
        acceptedRRCount < 2 ||
        (acceptanceRatio.map { $0 < 0.7 } ?? false)
    }
}

public struct HRVDataAuditSummary: Equatable, Sendable {
    public let sleepNightCount: Int
    public let sdnnNightCount: Int
    public let rmssdNightCount: Int
    public let medianSeriesPerNight: Double
    public let medianAcceptedRRPerNight: Double
    public let sparseOrFaultyNightCount: Int

    public static func compute(from records: [NightAuditFacts]) -> HRVDataAuditSummary? {
        guard !records.isEmpty else { return nil }
        return HRVDataAuditSummary(
            sleepNightCount: records.count,
            sdnnNightCount: records.count { $0.sdnnSampleCount > 0 },
            rmssdNightCount: records.count(where: \.hasRMSSD),
            medianSeriesPerNight: median(records.map { Double($0.heartbeatSeriesCount) }),
            medianAcceptedRRPerNight: median(records.map { Double($0.acceptedRRCount) }),
            sparseOrFaultyNightCount: records.count(where: \.isSparseOrFaulty)
        )
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        return sorted.count.isMultiple(of: 2)
            ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
            : sorted[sorted.count / 2]
    }
}
