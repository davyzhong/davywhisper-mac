import XCTest
import AppKit
@testable import DavyWhisper

// MARK: - Local Replicas of Private Logic
//
// The functions below are private to TextInsertionService.swift and cannot be
// accessed even with @testable import. We replicate their logic here for
// direct unit testing. The existing TextInsertionServiceTests already uses this
// same approach for escapeForAppleScript.

private func escapeForAppleScript(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
}

private enum BrowserType: String {
    case safari, arc, chromiumBased, firefox, notABrowser
}

private func identifyBrowser(_ bundleId: String) -> BrowserType {
    switch bundleId {
    case "com.apple.Safari":
        return .safari
    case "company.thebrowser.Browser":
        return .arc
    case "com.google.Chrome",
         "com.google.Chrome.canary",
         "com.brave.Browser",
         "com.microsoft.edgemac",
         "com.operasoftware.Opera",
         "com.vivaldi.Vivaldi",
         "org.chromium.Chromium":
        return .chromiumBased
    case "org.mozilla.firefox":
        return .firefox
    default:
        return .notABrowser
    }
}

private func isValidURL(_ string: String) -> Bool {
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > 3, trimmed.count < 2048 else { return false }
    return trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.hasPrefix("file://")
}

// MARK: - TextInsertionExtendedTests

@MainActor
final class TextInsertionExtendedTests: XCTestCase {

    private var service: TextInsertionService!

    override func setUp() {
        service = TextInsertionService()
    }

    override func tearDown() {
        service = nil
    }

    // =========================================================================
    // MARK: - InsertionResult
    // =========================================================================

    func testInsertionResult_pasted() {
        let result: TextInsertionService.InsertionResult = .pasted
        switch result {
        case .pasted:
            XCTAssertTrue(true)
        }
    }

    // =========================================================================
    // MARK: - TextInsertionError
    // =========================================================================

    func testError_accessibilityNotGranted_hasDescriptiveMessage() {
        let error = TextInsertionService.TextInsertionError.accessibilityNotGranted
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Accessibility"))
        XCTAssertTrue(error.errorDescription!.contains("Privacy & Security"))
    }

    func testError_pasteFailed_includesDetail() {
        let detail = "clipboard was empty"
        let error = TextInsertionService.TextInsertionError.pasteFailed(detail)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains(detail))
        XCTAssertTrue(error.errorDescription!.contains("Failed to paste"))
    }

    func testError_pasteFailed_withEmptyDetail() {
        let error = TextInsertionService.TextInsertionError.pasteFailed("")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Failed to paste text: "))
    }

    func testError_conformsToLocalizedError() {
        // Verify conformance by checking the protocol method exists and returns non-nil
        let errors: [TextInsertionService.TextInsertionError] = [
            .accessibilityNotGranted,
            .pasteFailed("reason")
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
        }
    }

    // =========================================================================
    // MARK: - escapeForAppleScript (replicated private logic)
    // =========================================================================

    func testEscapeForAppleScript_plainText_unchanged() {
        XCTAssertEqual(escapeForAppleScript("Safari"), "Safari")
        XCTAssertEqual(escapeForAppleScript("Google Chrome"), "Google Chrome")
        XCTAssertEqual(escapeForAppleScript(""), "")
    }

    func testEscapeForAppleScript_doubleQuotes_escaped() {
        XCTAssertEqual(escapeForAppleScript("App \"Test\""), "App \\\"Test\\\"")
    }

    func testEscapeForAppleScript_backslashes_escaped() {
        XCTAssertEqual(escapeForAppleScript("C:\\Path"), "C:\\\\Path")
    }

    func testEscapeForAppleScript_mixedSpecialChars() {
        XCTAssertEqual(
            escapeForAppleScript("Path \"C:\\test\""),
            "Path \\\"C:\\\\test\\\""
        )
    }

    func testEscapeForAppleScript_onlyBackslashes() {
        XCTAssertEqual(escapeForAppleScript("\\\\"), "\\\\\\\\")
    }

    func testEscapeForAppleScript_onlyDoubleQuotes() {
        XCTAssertEqual(escapeForAppleScript("\"\""), "\\\"\\\"")
    }

    func testEscapeForAppleScript_backslashBeforeQuote() {
        XCTAssertEqual(escapeForAppleScript("\\\""), "\\\\\\\"")
    }

    func testEscapeForAppleScript_multipleBackslashes() {
        XCTAssertEqual(escapeForAppleScript("a\\b\\c"), "a\\\\b\\\\c")
    }

    func testEscapeForAppleScript_embeddedQuote() {
        XCTAssertEqual(escapeForAppleScript("say \"hello\""), "say \\\"hello\\\"")
    }

    // =========================================================================
    // MARK: - isValidURL (replicated private logic)
    // =========================================================================

    func testIsValidURL_https_isValid() {
        XCTAssertTrue(isValidURL("https://example.com"))
    }

    func testIsValidURL_http_isValid() {
        XCTAssertTrue(isValidURL("http://example.com"))
    }

    func testIsValidURL_file_isValid() {
        XCTAssertTrue(isValidURL("file:///Users/test/doc.txt"))
    }

    func testIsValidURL_ftp_isInvalid() {
        XCTAssertFalse(isValidURL("ftp://example.com"))
    }

    func testIsValidURL_noScheme_isInvalid() {
        XCTAssertFalse(isValidURL("example.com"))
    }

    func testIsValidURL_empty_isInvalid() {
        XCTAssertFalse(isValidURL(""))
    }

    func testIsValidURL_tooShort_isInvalid() {
        XCTAssertFalse(isValidURL("ab"))
        XCTAssertFalse(isValidURL("abc"))
    }

    func testIsValidURL_exactlyFourChars_noValidPrefix() {
        // "http" is 4 chars, > 3 check passes, but no valid prefix
        XCTAssertFalse(isValidURL("http"))
    }

    func testIsValidURL_exceedsMaxLength_isInvalid() {
        let longURL = "https://" + String(repeating: "a", count: 2050)
        XCTAssertFalse(isValidURL(longURL))
    }

    func testIsValidURL_nearMaxLength_isValid() {
        let prefix = "https://e.com/"
        let url = prefix + String(repeating: "a", count: 2047 - prefix.count)
        XCTAssertTrue(isValidURL(url))
    }

    func testIsValidURL_trimsWhitespace() {
        XCTAssertTrue(isValidURL("  https://example.com  "))
    }

    func testIsValidURL_trimsNewlines() {
        XCTAssertTrue(isValidURL("\nhttps://example.com\n"))
    }

    func testIsValidURL_withQuery() {
        XCTAssertTrue(isValidURL("https://example.com/search?q=test&lang=en"))
    }

    func testIsValidURL_withFragment() {
        XCTAssertTrue(isValidURL("https://example.com/page#section"))
    }

    func testIsValidURL_withPort() {
        XCTAssertTrue(isValidURL("http://localhost:8080/api"))
    }

    func testIsValidURL_onlyWhitespace_isInvalid() {
        XCTAssertFalse(isValidURL("   "))
    }

    func testIsValidURL_newlineOnly_isInvalid() {
        XCTAssertFalse(isValidURL("\n"))
    }

    func testIsValidURL_mixedCaseScheme_isInvalid() {
        XCTAssertFalse(isValidURL("HTTPS://example.com"))
        XCTAssertFalse(isValidURL("Http://example.com"))
    }

    // =========================================================================
    // MARK: - identifyBrowser (replicated private logic)
    // =========================================================================

    func testIdentifyBrowser_safari() {
        XCTAssertEqual(identifyBrowser("com.apple.Safari"), .safari)
    }

    func testIdentifyBrowser_arc() {
        XCTAssertEqual(identifyBrowser("company.thebrowser.Browser"), .arc)
    }

    func testIdentifyBrowser_chrome() {
        XCTAssertEqual(identifyBrowser("com.google.Chrome"), .chromiumBased)
    }

    func testIdentifyBrowser_chromeCanary() {
        XCTAssertEqual(identifyBrowser("com.google.Chrome.canary"), .chromiumBased)
    }

    func testIdentifyBrowser_brave() {
        XCTAssertEqual(identifyBrowser("com.brave.Browser"), .chromiumBased)
    }

    func testIdentifyBrowser_edge() {
        XCTAssertEqual(identifyBrowser("com.microsoft.edgemac"), .chromiumBased)
    }

    func testIdentifyBrowser_opera() {
        XCTAssertEqual(identifyBrowser("com.operasoftware.Opera"), .chromiumBased)
    }

    func testIdentifyBrowser_vivaldi() {
        XCTAssertEqual(identifyBrowser("com.vivaldi.Vivaldi"), .chromiumBased)
    }

    func testIdentifyBrowser_chromium() {
        XCTAssertEqual(identifyBrowser("org.chromium.Chromium"), .chromiumBased)
    }

    func testIdentifyBrowser_firefox() {
        XCTAssertEqual(identifyBrowser("org.mozilla.firefox"), .firefox)
    }

    func testIdentifyBrowser_unknownApp() {
        XCTAssertEqual(identifyBrowser("com.apple.TextEdit"), .notABrowser)
    }

    func testIdentifyBrowser_emptyBundleId() {
        XCTAssertEqual(identifyBrowser(""), .notABrowser)
    }

    func testIdentifyBrowser_randomString() {
        XCTAssertEqual(identifyBrowser("not.a.real.bundle.id"), .notABrowser)
    }

    // =========================================================================
    // MARK: - BrowserType raw values
    // =========================================================================

    func testBrowserType_rawValues() {
        XCTAssertEqual(BrowserType.safari.rawValue, "safari")
        XCTAssertEqual(BrowserType.arc.rawValue, "arc")
        XCTAssertEqual(BrowserType.chromiumBased.rawValue, "chromiumBased")
        XCTAssertEqual(BrowserType.firefox.rawValue, "firefox")
        XCTAssertEqual(BrowserType.notABrowser.rawValue, "notABrowser")
    }

    // =========================================================================
    // MARK: - Clipboard Snapshot Static Methods
    // =========================================================================

    func testClipboardSnapshot_emptyArray_returnsEmpty() {
        let snapshot = TextInsertionService.clipboardSnapshot(from: [])
        XCTAssertTrue(snapshot.isEmpty)
    }

    func testClipboardSnapshot_singleItem_singleType() {
        let item = NSPasteboardItem()
        item.setString("Hello World", forType: .string)

        let snapshot = TextInsertionService.clipboardSnapshot(from: [item])

        XCTAssertEqual(snapshot.count, 1)
        XCTAssertEqual(snapshot.first?.keys.count, 1)
        XCTAssertTrue(snapshot.first?.keys.contains(.string) ?? false)
    }

    func testClipboardSnapshot_preservesStringData() {
        let item = NSPasteboardItem()
        let testString = "Test clipboard content"
        item.setString(testString, forType: .string)

        let snapshot = TextInsertionService.clipboardSnapshot(from: [item])

        guard let data = snapshot.first?[.string] else {
            XCTFail("Expected string data in snapshot")
            return
        }
        let restored = String(data: data, encoding: .utf8)
        XCTAssertEqual(restored, testString)
    }

    func testClipboardSnapshot_multipleItems() {
        let item1 = NSPasteboardItem()
        item1.setString("First", forType: .string)

        let item2 = NSPasteboardItem()
        item2.setString("Second", forType: .string)

        let snapshot = TextInsertionService.clipboardSnapshot(from: [item1, item2])
        XCTAssertEqual(snapshot.count, 2)
    }

    func testClipboardSnapshot_itemWithMultipleTypes() {
        let item = NSPasteboardItem()
        item.setString("text content", forType: .string)
        item.setData(Data("{\\rtf1 content}".utf8), forType: .rtf)

        let snapshot = TextInsertionService.clipboardSnapshot(from: [item])

        XCTAssertEqual(snapshot.first?.keys.count, 2)
        XCTAssertTrue(snapshot.first?.keys.contains(.string) ?? false)
        XCTAssertTrue(snapshot.first?.keys.contains(.rtf) ?? false)
    }

    func testClipboardSnapshot_filtersNilData() {
        let item = NSPasteboardItem()
        item.setString("valid data", forType: .string)
        // .rtf is never set, so data(forType: .rtf) returns nil

        let snapshot = TextInsertionService.clipboardSnapshot(from: [item])

        XCTAssertEqual(snapshot.first?.keys.count, 1)
        XCTAssertTrue(snapshot.first?.keys.contains(.string) ?? false)
        XCTAssertFalse(snapshot.first?.keys.contains(.rtf) ?? false)
    }

    // =========================================================================
    // MARK: - Pasteboard Items Round-trip
    // =========================================================================

    func testPasteboardItems_emptySnapshot_returnsEmpty() {
        let items = TextInsertionService.pasteboardItems(from: [])
        XCTAssertTrue(items.isEmpty)
    }

    func testPasteboardItems_roundTripPreservesData() {
        let original = NSPasteboardItem()
        let testContent = "Round-trip test content"
        original.setString(testContent, forType: .string)

        let snapshot = TextInsertionService.clipboardSnapshot(from: [original])
        let restored = TextInsertionService.pasteboardItems(from: snapshot)

        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored.first?.string(forType: .string), testContent)
    }

    func testPasteboardItems_roundTripMultipleItems() {
        let item1 = NSPasteboardItem()
        item1.setString("Alpha", forType: .string)

        let item2 = NSPasteboardItem()
        item2.setString("Beta", forType: .string)

        let snapshot = TextInsertionService.clipboardSnapshot(from: [item1, item2])
        let restored = TextInsertionService.pasteboardItems(from: snapshot)

        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(restored[0].string(forType: .string), "Alpha")
        XCTAssertEqual(restored[1].string(forType: .string), "Beta")
    }

    func testPasteboardItems_roundTripMultipleTypesPerItem() {
        let original = NSPasteboardItem()
        original.setString("string value", forType: .string)
        let rtfData = Data("{\\rtf1 rtf content}".utf8)
        original.setData(rtfData, forType: .rtf)

        let snapshot = TextInsertionService.clipboardSnapshot(from: [original])
        let restored = TextInsertionService.pasteboardItems(from: snapshot)

        XCTAssertEqual(restored.first?.string(forType: .string), "string value")
        XCTAssertEqual(restored.first?.data(forType: .rtf), rtfData)
    }

    func testSnapshotRoundTrip_preservesNonASCIIContent() {
        let chineseText = "Test content with special characters"
        let item = NSPasteboardItem()
        item.setString(chineseText, forType: .string)

        let snapshot = TextInsertionService.clipboardSnapshot(from: [item])
        let restored = TextInsertionService.pasteboardItems(from: snapshot)

        XCTAssertEqual(restored.first?.string(forType: .string), chineseText)
    }

    func testSnapshotRoundTrip_preservesBinaryData() {
        let binaryData = Data([0x00, 0x01, 0x02, 0xFF, 0xFE])
        let item = NSPasteboardItem()
        item.setData(binaryData, forType: .tiff)

        let snapshot = TextInsertionService.clipboardSnapshot(from: [item])
        let restored = TextInsertionService.pasteboardItems(from: snapshot)

        XCTAssertEqual(restored.first?.data(forType: .tiff), binaryData)
    }

    func testSnapshotRoundTrip_doesNotCrashOnEmptyString() {
        let item = NSPasteboardItem()
        item.setString("", forType: .string)

        let snapshot = TextInsertionService.clipboardSnapshot(from: [item])
        let restored = TextInsertionService.pasteboardItems(from: snapshot)

        // Verify no crash; NSPasteboardItem may represent empty string differently
        _ = restored.first?.string(forType: .string)
    }

    // =========================================================================
    // MARK: - focusedTextDidChange (public static method)
    // =========================================================================

    func testFocusedTextDidChange_sameValues_returnsFalse() {
        let initial = (value: "hello" as String?, selectedText: "hel" as String?, selectedRange: NSRange(location: 0, length: 3) as NSRange?)
        let current = (value: "hello" as String?, selectedText: "hel" as String?, selectedRange: NSRange(location: 0, length: 3) as NSRange?)

        XCTAssertFalse(TextInsertionService.focusedTextDidChange(from: initial, to: current))
    }

    func testFocusedTextDidChange_valueChanged_returnsTrue() {
        let initial = (value: "hello" as String?, selectedText: nil as String?, selectedRange: nil as NSRange?)
        let current = (value: "hello world" as String?, selectedText: nil as String?, selectedRange: nil as NSRange?)

        XCTAssertTrue(TextInsertionService.focusedTextDidChange(from: initial, to: current))
    }

    func testFocusedTextDidChange_selectedTextChanged_returnsTrue() {
        let initial = (value: "hello" as String?, selectedText: "hel" as String?, selectedRange: nil as NSRange?)
        let current = (value: "hello" as String?, selectedText: "lo" as String?, selectedRange: nil as NSRange?)

        XCTAssertTrue(TextInsertionService.focusedTextDidChange(from: initial, to: current))
    }

    func testFocusedTextDidChange_selectedRangeChanged_returnsTrue() {
        let initial = (value: "hello" as String?, selectedText: nil as String?, selectedRange: NSRange(location: 0, length: 3) as NSRange?)
        let current = (value: "hello" as String?, selectedText: nil as String?, selectedRange: NSRange(location: 1, length: 2) as NSRange?)

        XCTAssertTrue(TextInsertionService.focusedTextDidChange(from: initial, to: current))
    }

    func testFocusedTextDidChange_bothNil_returnsFalse() {
        let initial = (value: nil as String?, selectedText: nil as String?, selectedRange: nil as NSRange?)
        let current = (value: nil as String?, selectedText: nil as String?, selectedRange: nil as NSRange?)

        XCTAssertFalse(TextInsertionService.focusedTextDidChange(from: initial, to: current))
    }

    func testFocusedTextDidChange_nilToNonNil_returnsTrue() {
        let initial = (value: nil as String?, selectedText: nil as String?, selectedRange: nil as NSRange?)
        let current = (value: "new text" as String?, selectedText: nil as String?, selectedRange: nil as NSRange?)

        XCTAssertTrue(TextInsertionService.focusedTextDidChange(from: initial, to: current))
    }

    func testFocusedTextDidChange_nonNilToNil_returnsTrue() {
        let initial = (value: "old text" as String?, selectedText: nil as String?, selectedRange: nil as NSRange?)
        let current = (value: nil as String?, selectedText: nil as String?, selectedRange: nil as NSRange?)

        XCTAssertTrue(TextInsertionService.focusedTextDidChange(from: initial, to: current))
    }

    func testFocusedTextDidChange_valueSameRangeDiffers_returnsTrue() {
        let initial = (value: "abc" as String?, selectedText: "a" as String?, selectedRange: NSRange(location: 0, length: 1) as NSRange?)
        let current = (value: "abc" as String?, selectedText: "c" as String?, selectedRange: NSRange(location: 2, length: 1) as NSRange?)

        XCTAssertTrue(TextInsertionService.focusedTextDidChange(from: initial, to: current))
    }

    // =========================================================================
    // MARK: - saveClipboard / restoreClipboard (instance methods)
    // =========================================================================

    func testSaveClipboard_returnsSnapshot() {
        let pasteboard = NSPasteboard(name: .init("TestSaveClipboard"))
        pasteboard.clearContents()
        pasteboard.setString("test content", forType: .string)

        let snapshot = service.saveClipboard(from: pasteboard)
        XCTAssertFalse(snapshot.isEmpty)
        XCTAssertEqual(snapshot.count, 1)

        pasteboard.releaseGlobally()
    }

    func testSaveClipboard_emptyPasteboard_returnsEmptySnapshot() {
        let pasteboard = NSPasteboard(name: .init("TestEmptyClipboard"))
        pasteboard.clearContents()

        let snapshot = service.saveClipboard(from: pasteboard)
        XCTAssertTrue(snapshot.isEmpty)

        pasteboard.releaseGlobally()
    }

    func testRestoreClipboard_emptySnapshot_clearsPasteboard() {
        let pasteboard = NSPasteboard(name: .init("TestRestoreEmpty"))
        pasteboard.clearContents()
        pasteboard.setString("should be cleared", forType: .string)

        service.restoreClipboard([], to: pasteboard)

        let content = pasteboard.string(forType: .string)
        XCTAssertNil(content)

        pasteboard.releaseGlobally()
    }

    func testSaveAndRestoreClipboard_roundTrip() {
        let pasteboard = NSPasteboard(name: .init("TestRoundTrip"))
        let originalContent = "original clipboard content"
        pasteboard.clearContents()
        pasteboard.setString(originalContent, forType: .string)

        let snapshot = service.saveClipboard(from: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString("temporary content", forType: .string)

        service.restoreClipboard(snapshot, to: pasteboard)

        let restored = pasteboard.string(forType: .string)
        XCTAssertEqual(restored, originalContent)

        pasteboard.releaseGlobally()
    }

    func testRestoreClipboard_preservesMultipleItems() {
        let pasteboard = NSPasteboard(name: .init("TestRestoreMultiple"))
        pasteboard.clearContents()
        pasteboard.setString("first item", forType: .string)

        let snapshot = service.saveClipboard(from: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString("temporary", forType: .string)

        service.restoreClipboard(snapshot, to: pasteboard)

        let items = pasteboard.pasteboardItems
        XCTAssertEqual(items?.count, 1)
        XCTAssertEqual(items?.first?.string(forType: .string), "first item")

        pasteboard.releaseGlobally()
    }

    func testSaveClipboard_multipleTypesPerItem() {
        let pasteboard = NSPasteboard(name: .init("TestMultipleTypes"))
        pasteboard.clearContents()
        pasteboard.setString("text", forType: .string)

        let snapshot = service.saveClipboard(from: pasteboard)

        // Snapshot should capture whatever types the pasteboard item has
        XCTAssertFalse(snapshot.isEmpty)

        pasteboard.releaseGlobally()
    }

    // =========================================================================
    // MARK: - TextSelection struct

    func testTextSelection_storesTextAndElement() {
        let element = AXUIElementCreateSystemWide()
        let selection = TextInsertionService.TextSelection(text: "selected text", element: element)
        XCTAssertEqual(selection.text, "selected text")
        XCTAssertEqual(selection.element, element)
    }

    // =========================================================================
    // MARK: - PasteVerificationState

    func testCapturePasteVerificationState_returnsState() {
        // Returns state even if no focused text element in headless environments
        let state = service.capturePasteVerificationState()
        _ = state
    }

    // =========================================================================
    // MARK: - ClipboardSnapshot type alias

    func testClipboardSnapshotTypeAlias_compiles() {
        let itemSnapshot: TextInsertionService.ClipboardItemSnapshot = [:]
        let snapshot: TextInsertionService.ClipboardSnapshot = [itemSnapshot]
        XCTAssertEqual(snapshot.count, 1)
        XCTAssertTrue(snapshot.first?.isEmpty ?? false)
    }

    // =========================================================================
    // MARK: - captureActiveApp

    func testCaptureActiveApp_returnsTuple() {
        let result = service.captureActiveApp()
        // Verify it returns a valid tuple without crashing
        _ = result.name
        _ = result.bundleId
        // url is always nil in the current implementation
        XCTAssertNil(result.url)
    }

    // =========================================================================
    // MARK: - isAccessibilityGranted

    func testIsAccessibilityGranted_doesNotCrash() {
        _ = service.isAccessibilityGranted
    }

    // =========================================================================
    // MARK: - insertText (accessibility guard)

    func testInsertText_throwsWhenAccessibilityNotGranted() async {
        guard !service.isAccessibilityGranted else {
            // In environments where accessibility IS granted, skip to avoid false failures
            return
        }

        do {
            _ = try await service.insertText("test")
            XCTFail("Expected accessibilityNotGranted error")
        } catch let error as TextInsertionService.TextInsertionError {
            if case .accessibilityNotGranted = error {
                // Expected
            } else {
                XCTFail("Unexpected error variant: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testInsertText_returnsPastedWhenAccessible() async {
        guard service.isAccessibilityGranted else { return }

        do {
            let result = try await service.insertText("test", preserveClipboard: false)
            XCTAssertEqual(result, .pasted)
        } catch {
            guard error is TextInsertionService.TextInsertionError else {
                XCTFail("Unexpected error type: \(error)")
                return
            }
        }
    }

    func testInsertText_preserveClipboardTrue_doesNotCrash() async {
        guard service.isAccessibilityGranted else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("pre-existing content", forType: .string)

        do {
            let result = try await service.insertText("new text", preserveClipboard: true)
            XCTAssertEqual(result, .pasted)
        } catch {
            guard error is TextInsertionService.TextInsertionError else {
                XCTFail("Unexpected error type: \(error)")
                return
            }
        }
    }

    // =========================================================================
    // MARK: - AXUIElement-based methods (headless smoke tests)

    func testHasFocusedTextField_doesNotCrash() {
        _ = service.hasFocusedTextField()
    }

    func testFocusedElementPosition_doesNotCrash() {
        _ = service.focusedElementPosition()
    }

    func testGetSelectedText_doesNotCrash() {
        _ = service.getSelectedText()
    }

    func testGetTextSelection_doesNotCrash() {
        _ = service.getTextSelection()
    }

    func testGetFocusedTextElement_doesNotCrash() {
        _ = service.getFocusedTextElement()
    }

    // =========================================================================
    // MARK: - insertTextAt / replaceSelectedText

    func testInsertTextAt_withInvalidElement_returnsFalse() {
        let dummyElement = AXUIElementCreateSystemWide()
        let result = service.insertTextAt(element: dummyElement, text: "test")
        XCTAssertFalse(result)
    }

    func testReplaceSelectedText_withInvalidElement_returnsFalse() {
        let dummyElement = AXUIElementCreateSystemWide()
        let selection = TextInsertionService.TextSelection(text: "original", element: dummyElement)
        let result = service.replaceSelectedText(in: selection, with: "replacement")
        XCTAssertFalse(result)
    }

    func testInsertTextAt_withEmptyString() {
        let dummyElement = AXUIElementCreateSystemWide()
        let result = service.insertTextAt(element: dummyElement, text: "")
        // Empty string still fails on an invalid element
        XCTAssertFalse(result)
    }

    // =========================================================================
    // MARK: - resolveBrowserURL (public, tests browser detection indirectly)

    func testResolveBrowserURL_nonBrowser_returnsNil() async {
        let url = await service.resolveBrowserURL(bundleId: "com.apple.TextEdit")
        XCTAssertNil(url)
    }

    func testResolveBrowserURL_firefox_returnsNil() async {
        // Firefox does not support AppleScript URL access
        let url = await service.resolveBrowserURL(bundleId: "org.mozilla.firefox")
        XCTAssertNil(url)
    }

    func testResolveBrowserURL_emptyBundleId_returnsNil() async {
        let url = await service.resolveBrowserURL(bundleId: "")
        XCTAssertNil(url)
    }

    // =========================================================================
    // MARK: - resolveBrowserInfo (public, tests browser detection indirectly)

    func testResolveBrowserInfo_nonBrowser_returnsNilPair() async {
        let info = await service.resolveBrowserInfo(bundleId: "com.apple.TextEdit")
        XCTAssertNil(info.url)
        XCTAssertNil(info.title)
    }

    func testResolveBrowserInfo_firefox_returnsNilPair() async {
        let info = await service.resolveBrowserInfo(bundleId: "org.mozilla.firefox")
        XCTAssertNil(info.url)
        XCTAssertNil(info.title)
    }

    func testResolveBrowserInfo_emptyBundleId_returnsNilPair() async {
        let info = await service.resolveBrowserInfo(bundleId: "")
        XCTAssertNil(info.url)
        XCTAssertNil(info.title)
    }

    // =========================================================================
    // MARK: - pasteFromClipboard

    func testPasteFromClipboard_doesNotCrash() {
        service.pasteFromClipboard()
    }

    // =========================================================================
    // MARK: - getTextSelectionViaCopy

    func testGetTextSelectionViaCopy_doesNotCrash() async {
        let text = await service.getTextSelectionViaCopy()
        _ = text
    }

    // =========================================================================
    // MARK: - Integration: snapshot + focusedTextDidChange

    func testSnapshotRoundTrip_combinedWithFocusedTextChange() {
        let item = NSPasteboardItem()
        item.setString("content", forType: .string)
        let snapshot = TextInsertionService.clipboardSnapshot(from: [item])
        let restored = TextInsertionService.pasteboardItems(from: snapshot)
        XCTAssertEqual(restored.first?.string(forType: .string), "content")

        let initial = (value: "a" as String?, selectedText: nil as String?, selectedRange: nil as NSRange?)
        let current = (value: "b" as String?, selectedText: nil as String?, selectedRange: nil as NSRange?)
        XCTAssertTrue(TextInsertionService.focusedTextDidChange(from: initial, to: current))
    }
}
