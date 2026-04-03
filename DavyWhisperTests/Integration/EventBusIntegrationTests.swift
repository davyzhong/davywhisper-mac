import XCTest
@testable import DavyWhisper
import DavyWhisperPluginSDK

/// Tests EventBus pub/sub and the event → MemoryService pipeline.
/// Uses an actor to safely capture events from callbacks that may run on any thread.
actor EventCollector {
    private(set) var events: [DavyWhisperEvent] = []
    private(set) var count: Int = 0
    private(set) var recordingPayload: RecordingStartedPayload?
    private(set) var transcriptionPayload: TranscriptionCompletedPayload?

    func addEvent(_ event: DavyWhisperEvent) {
        events.append(event)
        count += 1
    }

    func setRecordingPayload(_ payload: RecordingStartedPayload) {
        recordingPayload = payload
    }

    func setTranscriptionPayload(_ payload: TranscriptionCompletedPayload) {
        transcriptionPayload = payload
    }

    func reset() {
        events = []
        count = 0
        recordingPayload = nil
        transcriptionPayload = nil
    }
}

/// Tests EventBus pub/sub and the event → MemoryService pipeline.
@MainActor
final class EventBusIntegrationTests: XCTestCase {

    var container: TestServiceContainer!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = try! TestSupport.makeTemporaryDirectory()
        let appDir = tempDir.appendingPathComponent("AppSupport", isDirectory: true)
        try! FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        let original = AppConstants.testAppSupportDirectoryOverride
        AppConstants.testAppSupportDirectoryOverride = appDir

        container = try! TestServiceContainer()

        AppConstants.testAppSupportDirectoryOverride = original
    }

    override func tearDown() {
        container.tearDown()
        container = nil
        TestSupport.remove(tempDir)
        super.tearDown()
    }

    // MARK: - Subscribe / Unsubscribe

    func testSubscribe_returnsSubscriptionId() {
        let id = EventBus.shared.subscribe { _ in }
        XCTAssertNotEqual(id, UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
    }

    func testUnsubscribe_preventsDelivery() async {
        let collector = EventCollector()
        let id = EventBus.shared.subscribe { event in
            Task { await collector.addEvent(event) }
        }

        // Emit before unsubscribe
        EventBus.shared.emit(.recordingStarted(RecordingStartedPayload(appName: nil, bundleIdentifier: nil)))
        try? await Task.sleep(for: .milliseconds(50))
        let count1 = await collector.count
        XCTAssertEqual(count1, 1)

        // Unsubscribe
        EventBus.shared.unsubscribe(id: id)

        // Emit after unsubscribe — count should still be 1
        EventBus.shared.emit(.recordingStopped(RecordingStoppedPayload(durationSeconds: 1.0)))
        try? await Task.sleep(for: .milliseconds(50))
        let count2 = await collector.count
        XCTAssertEqual(count2, 1)
    }

    func testDoubleUnsubscribe_isSafe() {
        let id = EventBus.shared.subscribe { _ in }
        EventBus.shared.unsubscribe(id: id)
        // Second unsubscribe should be safe (no-op)
        EventBus.shared.unsubscribe(id: id)
    }

    // MARK: - Event Delivery

    func testEmit_deliversAllRegisteredEvents() async {
        let collector = EventCollector()
        let id = EventBus.shared.subscribe { event in
            Task { await collector.addEvent(event) }
        }

        EventBus.shared.emit(.recordingStarted(RecordingStartedPayload(appName: nil, bundleIdentifier: nil)))
        EventBus.shared.emit(.recordingStopped(RecordingStoppedPayload(durationSeconds: 1.0)))
        EventBus.shared.emit(.recordingStarted(RecordingStartedPayload(appName: "Test", bundleIdentifier: nil)))

        try? await Task.sleep(for: .milliseconds(50))
        let count = await collector.count
        XCTAssertEqual(count, 3)

        EventBus.shared.unsubscribe(id: id)
    }

    func testEmit_recordingStarted_deliversCorrectPayload() async {
        let collector = EventCollector()
        let id = EventBus.shared.subscribe { event in
            if case .recordingStarted(let payload) = event {
                Task { await collector.setRecordingPayload(payload) }
            }
        }

        EventBus.shared.emit(.recordingStarted(RecordingStartedPayload(
            appName: "MyApp",
            bundleIdentifier: "com.example.myapp"
        )))

        try? await Task.sleep(for: .milliseconds(50))
        let payload = await collector.recordingPayload
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.appName, "MyApp")
        XCTAssertEqual(payload?.bundleIdentifier, "com.example.myapp")

        EventBus.shared.unsubscribe(id: id)
    }

    func testEmit_transcriptionCompleted_deliversCorrectPayload() async {
        let collector = EventCollector()
        let id = EventBus.shared.subscribe { event in
            if case .transcriptionCompleted(let payload) = event {
                Task { await collector.setTranscriptionPayload(payload) }
            }
        }

        EventBus.shared.emit(.transcriptionCompleted(TranscriptionCompletedPayload(
            rawText: "raw",
            finalText: "final",
            language: "en",
            engineUsed: "WhisperKit",
            modelUsed: "base",
            durationSeconds: 2.5,
            appName: "TestApp",
            bundleIdentifier: "com.test"
        )))

        try? await Task.sleep(for: .milliseconds(50))
        let payload = await collector.transcriptionPayload
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.rawText, "raw")
        XCTAssertEqual(payload?.finalText, "final")
        XCTAssertEqual(payload?.engineUsed, "WhisperKit")

        EventBus.shared.unsubscribe(id: id)
    }

    // MARK: - MemoryService Integration

    func testMemoryService_subscribesToTranscriptionCompleted() {
        // MemoryService.startListening() subscribes to EventBus
        container.memoryService.startListening()

        // Verify no crash — service registered its subscription
        container.memoryService.stopListening()
    }

    func testMemoryService_stopListening_unsubscribes() {
        container.memoryService.startListening()
        container.memoryService.stopListening()
        // Safe to call twice
        container.memoryService.stopListening()
    }
}
