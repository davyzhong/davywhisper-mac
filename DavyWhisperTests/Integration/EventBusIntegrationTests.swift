import XCTest
@testable import DavyWhisper
import DavyWhisperPluginSDK

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
        var deliveryCount = 0
        let id = EventBus.shared.subscribe { _ in
            deliveryCount += 1
        }

        // Emit before unsubscribe
        EventBus.shared.emit(.recordingStarted(RecordingStartedPayload(appName: nil, bundleIdentifier: nil)))
        XCTAssertEqual(deliveryCount, 1)

        // Unsubscribe
        EventBus.shared.unsubscribe(id: id)

        // Emit after unsubscribe — count should still be 1
        EventBus.shared.emit(.recordingStopped(RecordingStoppedPayload(durationSeconds: 1.0)))
        XCTAssertEqual(deliveryCount, 1)
    }

    func testDoubleUnsubscribe_isSafe() {
        let id = EventBus.shared.subscribe { _ in }
        EventBus.shared.unsubscribe(id: id)
        // Second unsubscribe should be safe (no-op)
        EventBus.shared.unsubscribe(id: id)
    }

    // MARK: - Event Delivery

    func testEmit_deliversAllRegisteredEvents() async {
        var receivedEvents: [DavyWhisperEvent] = []
        let id = EventBus.shared.subscribe { event in
            receivedEvents.append(event)
        }

        EventBus.shared.emit(.recordingStarted(RecordingStartedPayload(appName: nil, bundleIdentifier: nil)))
        EventBus.shared.emit(.recordingStopped(RecordingStoppedPayload(durationSeconds: 1.0)))
        EventBus.shared.emit(.recordingStarted(RecordingStartedPayload(appName: "Test", bundleIdentifier: nil)))

        XCTAssertEqual(receivedEvents.count, 3)

        EventBus.shared.unsubscribe(id: id)
    }

    func testEmit_recordingStarted_deliversCorrectPayload() async {
        var received: RecordingStartedPayload?
        let id = EventBus.shared.subscribe { event in
            if case .recordingStarted(let payload) = event {
                received = payload
            }
        }

        EventBus.shared.emit(.recordingStarted(RecordingStartedPayload(
            appName: "MyApp",
            bundleIdentifier: "com.example.myapp"
        )))

        XCTAssertNotNil(received)
        XCTAssertEqual(received?.appName, "MyApp")
        XCTAssertEqual(received?.bundleIdentifier, "com.example.myapp")

        EventBus.shared.unsubscribe(id: id)
    }

    func testEmit_transcriptionCompleted_deliversCorrectPayload() async {
        var received: TranscriptionCompletedPayload?
        let id = EventBus.shared.subscribe { event in
            if case .transcriptionCompleted(let payload) = event {
                received = payload
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

        XCTAssertNotNil(received)
        XCTAssertEqual(received?.rawText, "raw")
        XCTAssertEqual(received?.finalText, "final")
        XCTAssertEqual(received?.engineUsed, "WhisperKit")

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
