import XCTest
@testable import DavyWhisper
import DavyWhisperPluginSDK

/// Thread-safe counter for use in detached async handlers
actor CallCounter {
    private(set) var count = 0
    func increment() { count += 1 }
    func reset() { count = 0 }
}

final class EventBusTests: XCTestCase {
    override func setUp() async throws {
        await MainActor.run {
            EventBus.shared = EventBus()
        }
    }

    /// Flush main queue to ensure async dispatches complete
    @MainActor
    private func flushMainQueue() async {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)
    }

    @MainActor
    func testSubscribeReturnsUniqueUUID() {
        let bus = EventBus()
        let id1 = bus.subscribe { _ in }
        let id2 = bus.subscribe { _ in }
        XCTAssertNotEqual(id1, id2)
    }

    @MainActor
    func testUnsubscribeRemovesHandler() async throws {
        let bus = EventBus()
        let counter = CallCounter()

        let id = bus.subscribe { _ in
            await counter.increment()
        }
        await flushMainQueue()

        let event = DavyWhisperEvent.textInserted(
            TextInsertedPayload(text: "hello", appName: nil, bundleIdentifier: nil)
        )
        bus.emit(event)
        try? await Task.sleep(nanoseconds: 500_000_000)

        let countBefore = await counter.count
        XCTAssertGreaterThan(countBefore, 0, "Handler should have been called")

        bus.unsubscribe(id: id)
        await flushMainQueue()

        await counter.reset()
        let event2 = DavyWhisperEvent.textInserted(
            TextInsertedPayload(text: "world", appName: nil, bundleIdentifier: nil)
        )
        bus.emit(event2)
        try? await Task.sleep(nanoseconds: 200_000_000)

        let countAfter = await counter.count
        XCTAssertEqual(countAfter, 0, "Handler should not have been called after unsubscribe")
    }

    @MainActor
    func testEmitDeliversToAllSubscribers() async throws {
        let bus = EventBus()
        let counter1 = CallCounter()
        let counter2 = CallCounter()
        let counter3 = CallCounter()

        bus.subscribe { _ in await counter1.increment() }
        bus.subscribe { _ in await counter2.increment() }
        bus.subscribe { _ in await counter3.increment() }
        await flushMainQueue()

        let event = DavyWhisperEvent.textInserted(
            TextInsertedPayload(text: "test", appName: nil, bundleIdentifier: nil)
        )
        bus.emit(event)
        try? await Task.sleep(nanoseconds: 500_000_000)

        let c1 = await counter1.count
        let c2 = await counter2.count
        let c3 = await counter3.count
        XCTAssertEqual(c1, 1)
        XCTAssertEqual(c2, 1)
        XCTAssertEqual(c3, 1)
    }

    @MainActor
    func testEmitWithNoSubscribersDoesNotCrash() {
        let bus = EventBus()
        let event = DavyWhisperEvent.recordingStopped(
            RecordingStoppedPayload(durationSeconds: 1.5)
        )
        bus.emit(event)  // Should not throw
    }
}
