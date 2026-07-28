import Foundation
import MetricsCore
import UserNotifications

/// Persistent state for the one D1-approved local-notification fallback.
/// It contains only the resolved sleep end and scheduled fire date, never
/// HealthKit samples or derived metric values.
struct BriefFallbackRecord: Codable, Equatable {
    let mainSleepEnd: Date
    let fireDate: Date
}

struct BriefFallbackStore {
    private let defaults: UserDefaults
    private static let recordKey = "BriefFallback.pendingRecord"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func pendingRecord() -> BriefFallbackRecord? {
        guard let data = defaults.data(forKey: Self.recordKey) else { return nil }
        return try? JSONDecoder().decode(BriefFallbackRecord.self, from: data)
    }

    func save(_ record: BriefFallbackRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: Self.recordKey)
    }

    func clear() {
        defaults.removeObject(forKey: Self.recordKey)
    }

    func consumeIfFired(for mainSleepEnd: Date, now: Date, briefStore: BriefStore) -> Bool {
        guard let record = pendingRecord(), record.mainSleepEnd == mainSleepEnd, record.fireDate <= now else {
            return false
        }
        briefStore.markDelivered(onDay: mainSleepEnd)
        clear()
        return true
    }
}

/// Schedules exactly one local fallback after the authoritative policy has
/// produced a final main sleep and a future, policy-approved delivery time.
/// It never queries HealthKit and never chooses its own alarm time.
@MainActor
struct BriefFallbackNotifier {
    private static let identifier = "morning-brief.d1-fallback"
    private let center: UNUserNotificationCenter
    private let store: BriefFallbackStore

    init(center: UNUserNotificationCenter = .current(), store: BriefFallbackStore = BriefFallbackStore()) {
        self.center = center
        self.store = store
    }

    nonisolated static func hasReadyHealthData(hrv: HRVStatus?, rhr: RHRStatus?, spo2: SpO2Status?) -> Bool {
        hrv != nil || rhr != nil || spo2 != nil
    }

    func arm(content: BriefContent, plan: BriefFallbackPlan) async throws {
        cancelPendingRequest()
        let settings = await center.notificationSettings()
        guard [.authorized, .provisional].contains(settings.authorizationStatus) else {
            throw BriefNotifierError.authorizationDenied
        }
        let notification = UNMutableNotificationContent()
        notification.title = BriefLocalization.title(content)
        notification.body = BriefLocalization.renderLines(content.lines)
        notification.sound = .default
        let interval = max(plan.fireDate.timeIntervalSinceNow, 1)
        let request = UNNotificationRequest(
            identifier: Self.identifier,
            content: notification,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        try await center.add(request)
        store.save(BriefFallbackRecord(mainSleepEnd: plan.mainSleepEnd, fireDate: plan.fireDate))
    }

    func cancel() {
        cancelPendingRequest()
        store.clear()
    }

    /// Once the OS-owned local notification's fire time has passed, turn its
    /// accepted scheduling into the normal `BriefStore` dedupe record before
    /// any later automatic attempt can send a second notification.
    func consumeDeliveredFallbackIfNeeded(for mainSleepEnd: Date, now: Date, briefStore: BriefStore) -> Bool {
        guard let record = store.pendingRecord(), record.mainSleepEnd == mainSleepEnd, record.fireDate <= now else {
            return false
        }
        guard store.consumeIfFired(for: mainSleepEnd, now: now, briefStore: briefStore) else { return false }
        cancel()
        return true
    }

    func pendingRecord() -> BriefFallbackRecord? {
        store.pendingRecord()
    }

    private func cancelPendingRequest() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }
}
