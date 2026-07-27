/// Everything the morning brief has to say about one night: the resolved
/// main sleep plus whichever derived metrics were available for it. Any of
/// the metrics may be `nil` — a metric being unavailable does not block the
/// brief (see CLAUDE.md on VO2max-style optional inputs).
public struct NightSummary: Equatable {
    public let sleep: SleepSession
    public let hrv: HRVStatus?
    public let rhr: RHRStatus?
    public let spo2: SpO2Status?
    public let recovery: RecoverySignal?

    public init(sleep: SleepSession, hrv: HRVStatus?, rhr: RHRStatus?, spo2: SpO2Status?) {
        self.sleep = sleep
        self.hrv = hrv
        self.rhr = rhr
        self.spo2 = spo2
        self.recovery = RecoverySignal.evaluate(hrv: hrv, rhr: rhr)
    }
}
