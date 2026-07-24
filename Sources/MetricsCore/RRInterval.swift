/// A single RR interval — the time between two consecutive heartbeats, in
/// milliseconds. Array order represents temporal succession (each element
/// follows the previous one). This is the raw unit `HKHeartbeatSeriesQuery`
/// would produce once its availability is verified in the app (see
/// docs/data-availability-report.md); it isn't decoded from a JSON fixture
/// the way SensorSample is, so no Codable conformance is added until that's
/// actually needed.
public struct RRInterval: Equatable {
    public let milliseconds: Double

    public init(milliseconds: Double) {
        self.milliseconds = milliseconds
    }
}
