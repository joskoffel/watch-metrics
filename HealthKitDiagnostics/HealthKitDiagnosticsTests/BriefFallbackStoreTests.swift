import Foundation
import Testing
@testable import WatchMetrics

@Test func regularDeliveryCancellationClearsPendingFallback() {
    let defaults = UserDefaults(suiteName: "BriefFallbackStoreTests.cancel")!
    defaults.removePersistentDomain(forName: "BriefFallbackStoreTests.cancel")
    let store = BriefFallbackStore(defaults: defaults)
    let record = BriefFallbackRecord(mainSleepEnd: Date(timeIntervalSince1970: 1_000), fireDate: Date(timeIntervalSince1970: 2_000))

    store.save(record)
    store.clear()

    #expect(store.pendingRecord() == nil)
}

@Test func firedFallbackBecomesBriefStoreDedupeRecord() {
    let defaults = UserDefaults(suiteName: "BriefFallbackStoreTests.dedupe")!
    defaults.removePersistentDomain(forName: "BriefFallbackStoreTests.dedupe")
    let fallbackStore = BriefFallbackStore(defaults: defaults)
    let briefStore = BriefStore(defaults: defaults)
    let mainSleepEnd = Date(timeIntervalSince1970: 10_000)
    fallbackStore.save(BriefFallbackRecord(mainSleepEnd: mainSleepEnd, fireDate: Date(timeIntervalSince1970: 10_100)))

    #expect(fallbackStore.consumeIfFired(for: mainSleepEnd, now: Date(timeIntervalSince1970: 10_100), briefStore: briefStore))
    #expect(briefStore.hasDelivered(onDay: mainSleepEnd))
    #expect(fallbackStore.pendingRecord() == nil)
}

@Test func missingHealthDataDoesNotArmFallbackContent() {
    #expect(!BriefFallbackNotifier.hasReadyHealthData(hrv: nil, rhr: nil, spo2: nil))
}
