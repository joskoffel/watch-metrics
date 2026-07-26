import Foundation

/// Pure, presentation-ready summary for one reference day. Every section is
/// optional so one missing HealthKit stream never blocks the rest.
public struct DailyDashboardSnapshot: Equatable {
    public let referenceDate: Date
    public let sleep: SleepSession?
    public let hrv: HRVStatus?
    public let rhr: RHRStatus?
    public let spo2: SpO2Status?

    public init(
        referenceDate: Date,
        sleep: SleepSession? = nil,
        hrv: HRVStatus? = nil,
        rhr: RHRStatus? = nil,
        spo2: SpO2Status? = nil
    ) {
        self.referenceDate = referenceDate
        self.sleep = sleep
        self.hrv = hrv
        self.rhr = rhr
        self.spo2 = spo2
    }

    public var availableSectionCount: Int {
        [sleep != nil, hrv != nil, rhr != nil, spo2 != nil]
            .filter { $0 }
            .count
    }

    public var availability: DashboardAvailability {
        switch availableSectionCount {
        case 0:
            return .empty
        case 4:
            return .complete
        case let available:
            return .partial(available: available, total: 4)
        }
    }
}

public enum DashboardAvailability: Equatable {
    case empty
    case partial(available: Int, total: Int)
    case complete
}
