import Foundation
import Testing
@testable import MetricsCore

private let referenceDate = ISO8601DateFormatter().date(from: "2026-07-26T08:00:00Z")!

@Test func dailyDashboardSnapshotReportsEmptyWhenNoSectionsHaveData() {
    let snapshot = DailyDashboardSnapshot(
        referenceDate: referenceDate,
        sleep: nil,
        hrv: nil,
        rhr: nil,
        spo2: nil
    )

    #expect(snapshot.availableSectionCount == 0)
    #expect(snapshot.availability == .empty)
}

@Test func dailyDashboardSnapshotReportsPartialAvailability() {
    let sleep = SleepSession(
        start: referenceDate.addingTimeInterval(-8 * 60 * 60),
        end: referenceDate,
        asleepDuration: 7.25 * 60 * 60
    )
    let snapshot = DailyDashboardSnapshot(
        referenceDate: referenceDate,
        sleep: sleep,
        hrv: HRVStatus(value: 52, level: .normal, confidence: .medium),
        rhr: nil,
        spo2: nil
    )

    #expect(snapshot.availableSectionCount == 2)
    #expect(snapshot.availability == .partial(available: 2, total: 4))
}

@Test func dailyDashboardSnapshotReportsCompleteAvailability() {
    let sleep = SleepSession(
        start: referenceDate.addingTimeInterval(-8 * 60 * 60),
        end: referenceDate,
        asleepDuration: 7.25 * 60 * 60
    )
    let snapshot = DailyDashboardSnapshot(
        referenceDate: referenceDate,
        sleep: sleep,
        hrv: HRVStatus(value: 52, level: .normal, confidence: .high),
        rhr: RHRStatus(value: 51, level: .normal, confidence: .high),
        spo2: SpO2Status(value: 97, level: .normal, confidence: .low)
    )

    #expect(snapshot.availableSectionCount == 4)
    #expect(snapshot.availability == .complete)
}
