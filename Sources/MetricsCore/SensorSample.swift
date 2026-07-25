import Foundation

/// One discrete measured sample from a HealthKit-like source (e.g. one HRV
/// SDNN reading, one RHR reading, one wrist-temperature reading).
public struct SensorSample: Codable {
    public enum Kind: String, Codable {
        case heartRateVariabilitySDNN
        case restingHeartRate
        case sleepingWristTemperature
        case oxygenSaturation
    }

    public enum Unit: String, Codable {
        case milliseconds
        case beatsPerMinute
        case degreesCelsius
        case percent
    }

    public let kind: Kind
    public let timestamp: Date
    public let value: Double
    public let unit: Unit

    public init(kind: Kind, timestamp: Date, value: Double, unit: Unit) {
        self.kind = kind
        self.timestamp = timestamp
        self.value = value
        self.unit = unit
    }
}
