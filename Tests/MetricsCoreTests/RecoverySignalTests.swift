import Testing
@testable import MetricsCore

struct RecoverySignalTests {
    private let highHRV = HRVStatus(value: 60, level: .high, confidence: .high)
    private let normalHRV = HRVStatus(value: 50, level: .normal, confidence: .high)
    private let lowHRV = HRVStatus(value: 40, level: .low, confidence: .high)
    private let suppressedRHR = RHRStatus(value: 52, level: .suppressed, confidence: .high)
    private let normalRHR = RHRStatus(value: 58, level: .normal, confidence: .high)
    private let elevatedRHR = RHRStatus(value: 65, level: .elevated, confidence: .high)

    @Test func classifiesAlignedSignals() {
        #expect(RecoverySignal.evaluate(hrv: lowHRV, rhr: elevatedRHR)?.level == .strained)
        #expect(RecoverySignal.evaluate(hrv: highHRV, rhr: suppressedRHR)?.level == .favorable)
        #expect(RecoverySignal.evaluate(hrv: normalHRV, rhr: normalRHR)?.level == .typical)
    }

    @Test func classifiesEveryOtherAvailableCombinationAsMixed() {
        #expect(RecoverySignal.evaluate(hrv: lowHRV, rhr: normalRHR)?.level == .mixed)
        #expect(RecoverySignal.evaluate(hrv: normalHRV, rhr: elevatedRHR)?.level == .mixed)
        #expect(RecoverySignal.evaluate(hrv: lowHRV, rhr: suppressedRHR)?.level == .mixed)
        #expect(RecoverySignal.evaluate(hrv: highHRV, rhr: elevatedRHR)?.level == .mixed)
        #expect(RecoverySignal.evaluate(hrv: highHRV, rhr: normalRHR)?.level == .mixed)
        #expect(RecoverySignal.evaluate(hrv: normalHRV, rhr: suppressedRHR)?.level == .mixed)
    }

    @Test func requiresBothStatusesAndSufficientConfidence() {
        #expect(RecoverySignal.evaluate(hrv: nil, rhr: normalRHR) == nil)
        #expect(RecoverySignal.evaluate(hrv: normalHRV, rhr: nil) == nil)
        #expect(RecoverySignal.evaluate(
            hrv: HRVStatus(value: 40, level: .low, confidence: .low),
            rhr: elevatedRHR
        ) == nil)
        #expect(RecoverySignal.evaluate(
            hrv: lowHRV,
            rhr: RHRStatus(value: 65, level: .elevated, confidence: .low)
        ) == nil)
        #expect(RecoverySignal.evaluate(
            hrv: HRVStatus(value: 40, level: .low, confidence: .medium),
            rhr: RHRStatus(value: 65, level: .elevated, confidence: .medium)
        )?.level == .strained)
    }

    @Test func doesNotAlterSourceStatuses() {
        let hrv = lowHRV
        let rhr = elevatedRHR
        _ = RecoverySignal.evaluate(hrv: hrv, rhr: rhr)

        #expect(hrv == lowHRV)
        #expect(rhr == elevatedRHR)
    }
}
