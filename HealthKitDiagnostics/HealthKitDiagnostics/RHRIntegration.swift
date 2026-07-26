import Foundation
import HealthKit
import MetricsCore

@MainActor
@Observable
final class RHRIntegration {
    private let healthStore = HKHealthStore()
    private let rhrType = HKQuantityType(.restingHeartRate)

    private(set) var rhrStatus: RHRStatus?
    private(set) var history: [DatedMetric<RHRStatus>] = []
    private(set) var statusText = "Not started"
    private(set) var isLoading = false

    func run(referenceDate: Date = Date(), requestAccess: Bool = true) async {
        isLoading = true
        defer { isLoading = false }

        guard HKHealthStore.isHealthDataAvailable() else {
            statusText = "HealthKit nie je na tomto zariadení dostupný"
            return
        }

        do {
            if requestAccess {
                try await requestAuthorization()
            }
            try await compute(referenceDate: referenceDate)
        } catch RHRIntegrationError.authorizationDenied {
            statusText = "Prístup k HealthKit nebol povolený"
        } catch {
            statusText = "Query error: \(error.localizedDescription)"
        }
    }

    private func requestAuthorization() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: nil, read: [rhrType]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if !granted {
                    continuation.resume(throwing: RHRIntegrationError.authorizationDenied)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func compute(referenceDate: Date) async throws {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: referenceDate)
        guard let end = calendar.date(byAdding: .day, value: 1, to: selectedDay),
              let start = calendar.date(byAdding: .day, value: -41, to: selectedDay) else {
            statusText = "Nepodarilo sa vytvoriť časové okno"
            return
        }

        let samples = try await fetch(from: start, to: end)
        guard !Task.isCancelled else { return }
        let byDay = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.timestamp) }
        let dailyValues = byDay.map { day, values in
            DailyMetricValue(date: day, value: Self.median(values.map(\.value)))
        }
        history = Array((0..<14).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: selectedDay),
                  let status = RHRStatus.compute(
                    from: byDay[day] ?? [],
                    baseline: BaselineTracker.baseline(from: dailyValues, asOf: day)
                  ) else { return nil }
            return DatedMetric(date: day, value: status)
        }.reversed())
        rhrStatus = RHRStatus.compute(
            from: byDay[selectedDay] ?? [],
            baseline: BaselineTracker.baseline(from: dailyValues, asOf: selectedDay)
        )
        statusText = rhrStatus == nil ? "Nedostatok denných dát alebo histórie" : "OK"
    }

    private func fetch(from start: Date, to end: Date) async throws -> [SensorSample] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKSampleQuery(
                sampleType: rhrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let unit = HKUnit.count().unitDivided(by: .minute())
                continuation.resume(returning: ((samples as? [HKQuantitySample]) ?? []).map {
                    SensorSample(
                        kind: .restingHeartRate,
                        timestamp: $0.startDate,
                        value: $0.quantity.doubleValue(for: unit),
                        unit: .beatsPerMinute
                    )
                })
            }
            healthStore.execute(query)
        }
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        return sorted.count.isMultiple(of: 2)
            ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
            : sorted[sorted.count / 2]
    }
}

private enum RHRIntegrationError: Error {
    case authorizationDenied
}
