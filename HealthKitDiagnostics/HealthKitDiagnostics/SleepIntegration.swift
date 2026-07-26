import Foundation
import HealthKit
import MetricsCore

/// HealthKit -> MetricsCore bridge for sleep sessions, same shape as
/// `HRVIntegration`/`SpO2Integration`.
@MainActor
@Observable
final class SleepIntegration {
    private let healthStore = HKHealthStore()
    private let sleepType = HKCategoryType(.sleepAnalysis)

    private(set) var mainSleep: SleepSession?
    private(set) var statusText = "Not started"
    private(set) var isLoading = false

    /// All candidate sessions built for the last `run(referenceDate:)` call
    /// (not just the resolved main sleep) — `BriefRunner` needs the full
    /// list to hand to `BriefDeliveryPolicy.evaluate`, which resolves main
    /// sleep itself.
    private(set) var sessions: [SleepSession] = []

    /// `referenceDate` picks which night to show (defaults to tonight) —
    /// see `HRVIntegration.run(referenceDate:)`. It only selects the night
    /// *window*; it must never stand in for `MainSleepResolver`'s `now`.
    /// The night picker sets `referenceDate` to "real now minus N days", so
    /// when browsing a historical night, `referenceDate` can land just
    /// minutes after that night's main sleep ended purely by coincidence of
    /// wall-clock time — using it as `now` would then misclassify a
    /// 3-day-old session as still in progress. The real current instant is
    /// fetched fresh in `computeMainSleep` instead.
    func run(referenceDate: Date = Date(), requestAccess: Bool = true) async {
        isLoading = true
        defer { isLoading = false }

        guard HKHealthStore.isHealthDataAvailable() else {
            statusText = "HealthKit not available on this device"
            return
        }

        if requestAccess {
            do {
                try await requestAuthorization()
            } catch {
                statusText = "Authorization error: \(error.localizedDescription)"
                return
            }
        }

        await computeMainSleep(referenceDate: referenceDate)
    }

    private func requestAuthorization() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: nil, read: [sleepType]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if !granted {
                    continuation.resume(throwing: SleepIntegrationError.authorizationDenied)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func computeMainSleep(referenceDate: Date) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let windowStart = calendar.date(
                  bySettingHour: BriefConstants.nightWindowStartHour, minute: 0, second: 0, of: yesterday
              ) else {
            statusText = "Could not compute the night window"
            return
        }

        do {
            let samples = try await fetchSleepSamples(from: windowStart, to: referenceDate)
            guard !Task.isCancelled else { return }

            guard !samples.isEmpty else {
                statusText = "Nedostatok dát — žiadne spánkové vzorky za túto noc"
                mainSleep = nil
                sessions = []
                return
            }

            let builtSessions = SleepSessionBuilder.build(from: samples)
            sessions = builtSessions
            let window = DateInterval(start: windowStart, end: referenceDate)

            guard let main = MainSleepResolver.resolveMainSleep(sessions: builtSessions, window: window, now: Date()) else {
                mainSleep = nil
                statusText = "Žiadny hlavný spánok pre túto noc"
                return
            }

            mainSleep = main
            statusText = "OK"
        } catch {
            statusText = "Query error: \(error.localizedDescription)"
        }
    }

    /// Maps HealthKit's sleep-analysis category samples onto MetricsCore's
    /// `SleepSample`. Unrecognized category values (e.g. a future stage
    /// added by a newer OS) are dropped rather than guessed at.
    private func fetchSleepSamples(from start: Date, to end: Date) async throws -> [SleepSample] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sortByStartDate = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortByStartDate]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let mapped = ((samples as? [HKCategorySample]) ?? []).compactMap { sample -> SleepSample? in
                    guard let stage = Self.stage(forRawValue: sample.value) else { return nil }
                    return SleepSample(start: sample.startDate, end: sample.endDate, stage: stage)
                }
                continuation.resume(returning: mapped)
            }

            healthStore.execute(query)
        }
    }

    nonisolated private static func stage(forRawValue rawValue: Int) -> SleepSample.Stage? {
        guard let value = HKCategoryValueSleepAnalysis(rawValue: rawValue) else { return nil }
        switch value {
        case .inBed: return .inBed
        case .awake: return .awake
        case .asleepUnspecified: return .asleepUnspecified
        case .asleepCore: return .asleepCore
        case .asleepDeep: return .asleepDeep
        case .asleepREM: return .asleepREM
        @unknown default: return nil
        }
    }
}

private enum SleepIntegrationError: Error {
    case authorizationDenied
}
