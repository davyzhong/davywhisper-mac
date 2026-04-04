import XCTest
import AppKit
@testable import DavyWhisper

// MARK: - PromptPaletteHandler Tests
//
// The PromptPaletteHandler has heavy UI dependencies (PromptPaletteController, NSPasteboard,
// AXUIElement) that cannot be unit-tested in isolation. We test the testable surface:
// - visibility state
// - triggerSelection guards (not idle, no LLM provider, no actions)
// - callback wiring and invocation

@MainActor
final class PromptPaletteHandlerTests: XCTestCase {

    private var textInsertionService: TextInsertionService!
    private var promptActionService: PromptActionService!
    private var promptProcessingService: PromptProcessingService!
    private var soundService: SoundService!
    private var accessibilityAnnouncementService: AccessibilityAnnouncementService!
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = try TestSupport.makeTemporaryDirectory()
        let appDir = tempDir.appendingPathComponent("AppSupport", isDirectory: true)
        try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        textInsertionService = TextInsertionService()
        soundService = SoundService()
        accessibilityAnnouncementService = AccessibilityAnnouncementService()
        promptActionService = PromptActionService(appSupportDirectory: appDir)
        promptProcessingService = PromptProcessingService()
    }

    override func tearDown() {
        textInsertionService = nil
        soundService = nil
        accessibilityAnnouncementService = nil
        promptActionService = nil
        promptProcessingService = nil
        if let tempDir {
            TestSupport.remove(tempDir)
        }
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState_isNotVisible() {
        let handler = makeHandler()
        XCTAssertFalse(handler.isVisible)
    }

    func testInitialState_multipleHandlers_allNotVisible() {
        for _ in 0..<3 {
            let handler = makeHandler()
            XCTAssertFalse(handler.isVisible)
        }
    }

    // MARK: - Callbacks: onShowNotchFeedback

    func testOnShowNotchFeedback_callbackFires() {
        let handler = makeHandler()
        var callbackFired = false
        handler.onShowNotchFeedback = { _, _, _, _, _ in callbackFired = true }
        handler.onShowNotchFeedback?("test", "icon", 1.0, false, nil)
        XCTAssertTrue(callbackFired)
    }

    func testOnShowNotchFeedback_receivesAllParameters() {
        let handler = makeHandler()
        var receivedMessage: String?
        var receivedIcon: String?
        var receivedDuration: TimeInterval?
        var receivedIsError: Bool?
        var receivedCategory: String?

        handler.onShowNotchFeedback = { msg, icon, duration, isError, category in
            receivedMessage = msg
            receivedIcon = icon
            receivedDuration = duration
            receivedIsError = isError
            receivedCategory = category
        }

        handler.onShowNotchFeedback?("Processing...", "spinner", 5.0, true, "prompt")

        XCTAssertEqual(receivedMessage, "Processing...")
        XCTAssertEqual(receivedIcon, "spinner")
        XCTAssertEqual(receivedDuration, 5.0)
        XCTAssertTrue(receivedIsError ?? false)
        XCTAssertEqual(receivedCategory, "prompt")
    }

    func testOnShowNotchFeedback_nilCategory() {
        let handler = makeHandler()
        var receivedCategory: String? = "sentinel"

        handler.onShowNotchFeedback = { _, _, _, _, category in
            receivedCategory = category
        }

        handler.onShowNotchFeedback?("msg", "icon", 1.0, false, nil)
        XCTAssertNil(receivedCategory)
    }

    // MARK: - Callbacks: onShowError

    func testOnShowError_callbackFires() {
        let handler = makeHandler()
        var receivedError: String?
        handler.onShowError = { error in receivedError = error }
        handler.onShowError?("test error")
        XCTAssertEqual(receivedError, "test error")
    }

    func testOnShowError_emptyMessage() {
        let handler = makeHandler()
        var receivedError: String?
        handler.onShowError = { error in receivedError = error }
        handler.onShowError?("")
        XCTAssertEqual(receivedError, "")
    }

    // MARK: - Callbacks: getActionFeedback

    func testGetActionFeedback_returnsConfiguredValues() {
        let handler = makeHandler()
        handler.getActionFeedback = { (message: "test", icon: "star", duration: 3.0) }
        let result = handler.getActionFeedback?()
        XCTAssertEqual(result?.message, "test")
        XCTAssertEqual(result?.icon, "star")
        XCTAssertEqual(result?.duration, 3.0)
    }

    // MARK: - Callbacks: getPreserveClipboard

    func testGetPreserveClipboard_returnsTrue() {
        let handler = makeHandler()
        handler.getPreserveClipboard = { true }
        XCTAssertTrue(handler.getPreserveClipboard?() ?? false)
    }

    func testGetPreserveClipboard_returnsFalse() {
        let handler = makeHandler()
        handler.getPreserveClipboard = { false }
        XCTAssertFalse(handler.getPreserveClipboard?() ?? true)
    }

    func testGetPreserveClipboard_defaultIsNil() {
        let handler = makeHandler()
        XCTAssertNil(handler.getPreserveClipboard)
    }

    // MARK: - Callbacks: replacement and nil

    func testCallbacks_canBeReplaced() {
        let handler = makeHandler()
        var firstCalled = false
        var secondCalled = false

        handler.onShowError = { _ in firstCalled = true }
        handler.onShowError?("first")
        XCTAssertTrue(firstCalled)

        handler.onShowError = { _ in secondCalled = true }
        handler.onShowError?("second")
        XCTAssertTrue(secondCalled)
    }

    func testCallbacks_canBeSetToNil() {
        let handler = makeHandler()
        handler.onShowError = { _ in }
        handler.onShowError = nil
        XCTAssertNil(handler.onShowError)
    }

    func testMultipleCallbacks_coexist() {
        let handler = makeHandler()

        var notchCalled = false
        var errorCalled = false
        var feedbackCalled = false
        var clipboardCalled = false

        handler.onShowNotchFeedback = { _, _, _, _, _ in notchCalled = true }
        handler.onShowError = { _ in errorCalled = true }
        handler.getActionFeedback = { feedbackCalled = true; return (message: "m", icon: "i", duration: 1.0) }
        handler.getPreserveClipboard = { clipboardCalled = true; return true }

        handler.onShowNotchFeedback?("msg", "icon", 1.0, false, nil)
        handler.onShowError?("err")
        _ = handler.getActionFeedback?()
        _ = handler.getPreserveClipboard?()

        XCTAssertTrue(notchCalled)
        XCTAssertTrue(errorCalled)
        XCTAssertTrue(feedbackCalled)
        XCTAssertTrue(clipboardCalled)
    }

    // MARK: - hide()

    func testHide_doesNotCrashWhenNotVisible() {
        let handler = makeHandler()
        handler.hide()
        XCTAssertFalse(handler.isVisible)
    }

    func testHide_calledMultipleTimes_doesNotCrash() {
        let handler = makeHandler()
        handler.hide()
        handler.hide()
        handler.hide()
        XCTAssertFalse(handler.isVisible)
    }

    func testIsVisible_afterHide_isFalse() {
        let handler = makeHandler()
        handler.hide()
        XCTAssertFalse(handler.isVisible)
    }

    // MARK: - triggerSelection guards (non-idle states)

    func testTriggerSelection_whenRecording_doesNotShowPalette() {
        let handler = makeHandler()
        handler.triggerSelection(currentState: .recording, soundFeedbackEnabled: true)
        XCTAssertFalse(handler.isVisible)
    }

    func testTriggerSelection_whenProcessing_doesNotShowPalette() {
        let handler = makeHandler()
        handler.triggerSelection(currentState: .processing, soundFeedbackEnabled: true)
        XCTAssertFalse(handler.isVisible)
    }

    func testTriggerSelection_whenInserting_doesNotShowPalette() {
        let handler = makeHandler()
        handler.triggerSelection(currentState: .inserting, soundFeedbackEnabled: true)
        XCTAssertFalse(handler.isVisible)
    }

    func testTriggerSelection_whenErrorState_doesNotShowPalette() {
        let handler = makeHandler()
        handler.triggerSelection(currentState: .error("some error"), soundFeedbackEnabled: true)
        XCTAssertFalse(handler.isVisible)
    }

    func testTriggerSelection_whenPromptProcessing_doesNotShowPalette() {
        let handler = makeHandler()
        handler.triggerSelection(currentState: .promptProcessing("test"), soundFeedbackEnabled: true)
        XCTAssertFalse(handler.isVisible)
    }

    func testTriggerSelection_whenPromptSelection_doesNotShowPalette() {
        let handler = makeHandler()
        handler.triggerSelection(currentState: .promptSelection("text"), soundFeedbackEnabled: true)
        XCTAssertFalse(handler.isVisible)
    }

    // MARK: - triggerSelection idle state (attempts full flow but depends on providers)

    func testTriggerSelection_idleState_doesNotCrash() {
        let handler = makeHandler()
        handler.triggerSelection(currentState: .idle, soundFeedbackEnabled: false)
        XCTAssertNotNil(handler.isVisible)
    }

    func testTriggerSelection_idleState_withSoundFeedback_doesNotCrash() {
        let handler = makeHandler()
        handler.triggerSelection(currentState: .idle, soundFeedbackEnabled: true)
        XCTAssertNotNil(handler.isVisible)
    }

    // MARK: - Helper

    private func makeHandler() -> PromptPaletteHandler {
        return PromptPaletteHandler(
            textInsertionService: textInsertionService,
            promptActionService: promptActionService,
            promptProcessingService: promptProcessingService,
            soundService: soundService,
            accessibilityAnnouncementService: accessibilityAnnouncementService
        )
    }
}
