import Foundation
import Testing
@testable import WatchMetrics
import WatchMetricsSupport

private final class CollectorResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Result<[HeartbeatEvent], Error>] = []

    func append(_ result: Result<[HeartbeatEvent], Error>) {
        lock.lock()
        results.append(result)
        lock.unlock()
    }

    func snapshot() -> [Result<[HeartbeatEvent], Error>] {
        lock.lock()
        defer { lock.unlock() }
        return results
    }
}

@Test func collectorStoresAllCallbacksInOrderBeforeDoneCompletes() throws {
    let collector = HeartbeatEventCollector()
    let box = CollectorResultBox()
    collector.installCompletion { box.append($0) }
    let first = HeartbeatEvent(timeSinceSeriesStart: 0.1, precededByGap: false)
    let second = HeartbeatEvent(timeSinceSeriesStart: 0.9, precededByGap: false)

    collector.receive(event: first, done: false, error: nil)
    collector.receive(event: second, done: true, error: nil)

    let result = try #require(box.snapshot().first)
    #expect(try result.get() == [first, second])
}

@Test func collectorCompletesExactlyOnceAndDropsCallbacksAfterDone() throws {
    let collector = HeartbeatEventCollector()
    let box = CollectorResultBox()
    collector.installCompletion { box.append($0) }
    let first = HeartbeatEvent(timeSinceSeriesStart: 0.1, precededByGap: false)
    let late = HeartbeatEvent(timeSinceSeriesStart: 0.9, precededByGap: false)

    collector.receive(event: first, done: true, error: nil)
    collector.receive(event: late, done: true, error: nil)
    collector.cancel()

    #expect(box.snapshot().count == 1)
    #expect(try box.snapshot()[0].get() == [first])
}

@Test func collectorErrorCompletesOnceWithoutAppendingErrorCallback() {
    let collector = HeartbeatEventCollector()
    let box = CollectorResultBox()
    collector.installCompletion { box.append($0) }
    collector.receive(
        event: HeartbeatEvent(timeSinceSeriesStart: 0.1, precededByGap: false),
        done: false,
        error: CollectorTestError.sample
    )
    collector.receive(event: nil, done: true, error: nil)

    #expect(box.snapshot().count == 1)
    #expect(throws: CollectorTestError.self) { try box.snapshot()[0].get() }
}

@Test func collectorCancellationCompletesOnceAndRejectsLateCallbacks() {
    let collector = HeartbeatEventCollector()
    let box = CollectorResultBox()
    collector.installCompletion { box.append($0) }

    collector.cancel()
    collector.receive(
        event: HeartbeatEvent(timeSinceSeriesStart: 0.1, precededByGap: false),
        done: true,
        error: nil
    )

    #expect(box.snapshot().count == 1)
    #expect(throws: CancellationError.self) { try box.snapshot()[0].get() }
}

private enum CollectorTestError: Error {
    case sample
}
