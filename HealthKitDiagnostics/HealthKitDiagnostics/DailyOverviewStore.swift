import Foundation
import HealthKit
import MetricsCore
import UserNotifications
import WatchMetricsSupport

enum DataLoadState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case permissionDenied
    case failed(String)
}

enum NotificationAccess: String {
    case unknown = "Neoverené"
    case allowed = "Povolené"
    case denied = "Zakázané"
}

@MainActor
@Observable
final class DailyOverviewStore {
    private let sleepIntegration = SleepIntegration()
    private let hrvIntegration = HRVIntegration()
    private let rmssdIntegration = RMSSDIntegration()
    private let rhrIntegration = RHRIntegration()
    private let spo2Integration = SpO2Integration()
    private let briefStore = BriefStore()
    private let notifier = BriefNotifier()
    private let healthStore = HKHealthStore()

    private var loadGeneration = 0
    private let usesHealthKit: Bool

    private(set) var referenceDate: Date
    private(set) var snapshot: DailyDashboardSnapshot
    private(set) var history: [DailyDashboardSnapshot] = []
    private(set) var hrvHistory: [DatedMetric<HRVStatus>] = []
    private(set) var rmssdHistory: [DatedMetric<Double>] = []
    private(set) var rhrHistory: [DatedMetric<RHRStatus>] = []
    private(set) var spo2History: [DatedMetric<SpO2Status>] = []
    private(set) var sleepState: DataLoadState = .idle
    private(set) var hrvState: DataLoadState = .idle
    private(set) var rmssdState: DataLoadState = .idle
    private(set) var rhrState: DataLoadState = .idle
    private(set) var spo2State: DataLoadState = .idle
    private(set) var notificationAccess: NotificationAccess = .unknown
    private(set) var notificationTestMessage: String?
    private(set) var isLoading = false
    private(set) var rmssdValue: Double?
    private(set) var rmssdStatus: RMSSDStatus?
    private(set) var hrvAgreement: HRVAgreementInsight = .insufficientRMSSD

    init(referenceDate: Date = Date()) {
        self.referenceDate = referenceDate
        self.snapshot = DailyDashboardSnapshot(referenceDate: referenceDate)
        self.usesHealthKit = true
    }

    init(
        sample snapshot: DailyDashboardSnapshot,
        history: [DailyDashboardSnapshot] = [],
        hrvHistory: [DatedMetric<HRVStatus>] = [],
        rmssdHistory: [DatedMetric<Double>] = [],
        rmssdValue: Double? = nil,
        rmssdStatus: RMSSDStatus? = nil,
        rhrHistory: [DatedMetric<RHRStatus>] = [],
        spo2History: [DatedMetric<SpO2Status>] = [],
        states: DataLoadState = .loaded
    ) {
        self.referenceDate = snapshot.referenceDate
        self.snapshot = snapshot
        self.history = history
        self.hrvHistory = hrvHistory
        self.rmssdHistory = rmssdHistory
        self.rmssdValue = rmssdValue
        self.rmssdStatus = rmssdStatus
        self.hrvAgreement = HRVAgreementInsight.evaluate(
            sdnn: snapshot.hrv, rmssd: rmssdStatus
        )
        self.rhrHistory = rhrHistory
        self.spo2History = spo2History
        self.sleepState = states
        self.hrvState = states
        self.rmssdState = rmssdValue == nil ? .empty : states
        self.rhrState = states
        self.spo2State = states
        self.usesHealthKit = false
    }

    var dataStatusText: String {
        if isLoading { return "Načítavam HealthKit…" }
        switch snapshot.availability {
        case .complete: return "Dáta sú kompletné"
        case .partial(let available, let total): return "\(available) z \(total) metrík dostupné"
        case .empty: return "Pre túto noc nie sú dáta"
        }
    }

    var morningBriefText: String {
        guard let sleep = snapshot.sleep else { return "Čaká na hlavný spánok" }
        return briefStore.hasDelivered(onDay: sleep.end) ? "Dnešný brief bol doručený" : "Brief zatiaľ nebol doručený"
    }

    var healthKitAccessText: String {
        guard HKHealthStore.isHealthDataAvailable() else { return "Na zariadení nedostupný" }
        if [sleepState, hrvState, rhrState, spo2State].contains(.permissionDenied) {
            return "Skontrolujte povolenia v aplikácii Zdravie"
        }
        return "Prístup sa spravuje v aplikácii Zdravie"
    }

    func load(referenceDate: Date? = nil) async {
        guard usesHealthKit else { return }
        if let referenceDate { self.referenceDate = referenceDate }
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        sleepState = .loading
        hrvState = .loading
        rmssdState = .loading
        rmssdValue = nil
        rmssdStatus = nil
        rmssdHistory = []
        hrvAgreement = .insufficientRMSSD
        rhrState = .loading
        spo2State = .loading

        do {
            try await requestOverviewAuthorization()
        } catch {
            guard generation == loadGeneration else { return }
            sleepState = .permissionDenied
            hrvState = .permissionDenied
            rmssdState = .permissionDenied
            rhrState = .permissionDenied
            spo2State = .permissionDenied
            isLoading = false
            return
        }

        await sleepIntegration.run(
            referenceDate: self.referenceDate,
            historyDays: 42,
            requestAccess: false
        )
        guard generation == loadGeneration, !Task.isCancelled else { return }

        let nights = sleepIntegration.resolvedNights
        await hrvIntegration.run(
            referenceDate: self.referenceDate, nights: nights, requestAccess: false
        )
        guard generation == loadGeneration, !Task.isCancelled else { return }
        await rhrIntegration.run(referenceDate: self.referenceDate, requestAccess: false)
        guard generation == loadGeneration, !Task.isCancelled else { return }
        await spo2Integration.run(
            referenceDate: self.referenceDate, nights: nights, requestAccess: false
        )
        guard generation == loadGeneration, !Task.isCancelled else { return }

        snapshot = DailyDashboardSnapshot(
            referenceDate: self.referenceDate,
            sleep: sleepIntegration.mainSleep,
            hrv: hrvIntegration.hrvStatus,
            rhr: rhrIntegration.rhrStatus,
            spo2: spo2Integration.spo2Status
        )
        hrvHistory = hrvIntegration.history
        rhrHistory = rhrIntegration.history
        spo2History = spo2Integration.history
        sleepState = Self.state(valueExists: snapshot.sleep != nil, text: sleepIntegration.statusText)
        hrvState = Self.state(valueExists: snapshot.hrv != nil, text: hrvIntegration.statusText)
        rhrState = Self.state(valueExists: snapshot.rhr != nil, text: rhrIntegration.statusText)
        spo2State = Self.state(valueExists: snapshot.spo2 != nil, text: spo2Integration.statusText)
        history = Self.mergeHistory(
            referenceDate: self.referenceDate,
            selected: snapshot,
            nights: nights,
            hrv: hrvHistory,
            rhr: rhrHistory,
            spo2: spo2History
        )
        isLoading = false

        // RMSSD is an optional enrichment. The authoritative dashboard is
        // already usable before these more expensive heartbeat-series queries
        // begin, and the morning brief never instantiates this integration.
        await rmssdIntegration.run(
            referenceDate: self.referenceDate,
            nights: nights,
            requestAccess: true
        )
        guard generation == loadGeneration, !Task.isCancelled else { return }
        rmssdValue = rmssdIntegration.nightlyValue
        rmssdStatus = rmssdIntegration.status
        rmssdHistory = rmssdIntegration.history
        rmssdState = Self.state(
            valueExists: rmssdValue != nil,
            text: rmssdIntegration.statusText
        )
        hrvAgreement = HRVAgreementInsight.evaluate(
            sdnn: snapshot.hrv,
            rmssd: rmssdStatus
        )
    }

    func refreshNotificationAccess() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: notificationAccess = .allowed
        case .denied: notificationAccess = .denied
        default: notificationAccess = .unknown
        }
    }

    func sendSafeTestNotification() async {
        notificationTestMessage = nil
        do {
            try await notifier.requestAuthorization()
            try await notifier.notify(
                BriefContent(
                    title: "Watch Metrics",
                    lines: [
                        BriefLine(
                            label: "Test",
                            value: "notifikácia funguje",
                            qualifier: nil,
                            isProvisional: false
                        )
                    ]
                )
            )
            notificationTestMessage = "Test bol odoslaný"
        } catch {
            notificationTestMessage = "Test zlyhal: \(error.localizedDescription)"
        }
        await refreshNotificationAccess()
    }

    private func requestOverviewAuthorization() async throws {
        let readTypes: Set<HKObjectType> = [
            HKCategoryType(.sleepAnalysis),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.oxygenSaturation)
        ]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: nil, read: readTypes) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if granted {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: OverviewAuthorizationError.denied)
                }
            }
        }
    }

    private static func state(valueExists: Bool, text: String) -> DataLoadState {
        if valueExists { return .loaded }
        if text.localizedCaseInsensitiveContains("authorization") ||
            text.localizedCaseInsensitiveContains("povolen") {
            return .permissionDenied
        }
        if text.localizedCaseInsensitiveContains("error") { return .failed(text) }
        return .empty
    }

    private static func mergeHistory(
        referenceDate: Date,
        selected: DailyDashboardSnapshot,
        nights: [ResolvedNight],
        hrv: [DatedMetric<HRVStatus>],
        rhr: [DatedMetric<RHRStatus>],
        spo2: [DatedMetric<SpO2Status>]
    ) -> [DailyDashboardSnapshot] {
        let calendar = Calendar.current
        return (0..<14).compactMap { offset in
            // Preserve the selected wall-clock time. SleepIntegration's window
            // ends at referenceDate; normalizing history rows to midnight would
            // truncate the selected night before its morning sleep ends.
            guard let day = calendar.date(byAdding: .day, value: -offset, to: referenceDate)
            else { return nil }
            let isSelected = calendar.isDate(day, inSameDayAs: selected.referenceDate)
            return DailyDashboardSnapshot(
                referenceDate: day,
                sleep: isSelected
                    ? selected.sleep
                    : nights.first { calendar.isDate($0.day, inSameDayAs: day) }?.sleep,
                hrv: hrv.first { calendar.isDate($0.date, inSameDayAs: day) }?.value,
                rhr: rhr.first { calendar.isDate($0.date, inSameDayAs: day) }?.value,
                spo2: spo2.first { calendar.isDate($0.date, inSameDayAs: day) }?.value
            )
        }
    }
}

private enum OverviewAuthorizationError: Error {
    case denied
}
