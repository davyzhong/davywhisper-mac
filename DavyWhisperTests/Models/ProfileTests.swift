import XCTest
@testable import DavyWhisper

final class ProfileTests: XCTestCase {

    // MARK: - Init defaults

    func testInit_defaultValues() {
        let profile = Profile(name: "Test Profile")
        XCTAssertEqual(profile.name, "Test Profile")
        XCTAssertTrue(profile.isEnabled)
        XCTAssertTrue(profile.bundleIdentifiers.isEmpty)
        XCTAssertTrue(profile.urlPatterns.isEmpty)
        XCTAssertFalse(profile.memoryEnabled)
        XCTAssertFalse(profile.inlineCommandsEnabled)
        XCTAssertNil(profile.inputLanguage)
        XCTAssertNil(profile.translationTargetLanguage)
        XCTAssertNil(profile.selectedTask)
        XCTAssertNil(profile.engineOverride)
        XCTAssertNil(profile.hotkeyData)
        XCTAssertNil(profile.hotkey)
    }

    func testInit_copiesAllArguments() {
        let bundleIds = ["com.apple.Safari", "com.apple.Mail"]
        let urls = ["github.com", "*.notion.so"]
        let profile = Profile(
            name: "Work",
            isEnabled: false,
            bundleIdentifiers: bundleIds,
            urlPatterns: urls,
            inputLanguage: "en",
            translationTargetLanguage: "zh-Hans",
            selectedTask: "transcribe",
            engineOverride: "WhisperKit",
            cloudModelOverride: "gpt-4o",
            promptActionId: "abc",
            memoryEnabled: true,
            outputFormat: "markdown",
            inlineCommandsEnabled: true
        )
        XCTAssertEqual(profile.name, "Work")
        XCTAssertFalse(profile.isEnabled)
        XCTAssertEqual(profile.bundleIdentifiers, bundleIds)
        XCTAssertEqual(profile.urlPatterns, urls)
        XCTAssertEqual(profile.inputLanguage, "en")
        XCTAssertEqual(profile.translationTargetLanguage, "zh-Hans")
        XCTAssertEqual(profile.selectedTask, "transcribe")
        XCTAssertEqual(profile.engineOverride, "WhisperKit")
        XCTAssertEqual(profile.cloudModelOverride, "gpt-4o")
        XCTAssertEqual(profile.promptActionId, "abc")
        XCTAssertTrue(profile.memoryEnabled)
        XCTAssertEqual(profile.outputFormat, "markdown")
        XCTAssertTrue(profile.inlineCommandsEnabled)
    }

    // MARK: - hotkey round-trip via computed property

    func testHotkey_setAndRead_roundTrip() {
        let profile = Profile(name: "Hotkey Test")
        let hotkey = UnifiedHotkey(
            keyCode: 36, modifierFlags: UInt(CGEventFlags.maskCommand.rawValue), isFn: false, isDoubleTap: true
        )
        profile.hotkey = hotkey
        XCTAssertNotNil(profile.hotkeyData)
        XCTAssertEqual(profile.hotkey, hotkey)
    }

    func testHotkey_nilRoundTrip() {
        let profile = Profile(name: "No Hotkey")
        XCTAssertNil(profile.hotkey)
        XCTAssertNil(profile.hotkeyData)
        profile.hotkey = nil
        XCTAssertNil(profile.hotkeyData)
    }

    func testHotkey_encodeDecode_allKinds() {
        let profile = Profile(name: "All Kinds")
        let cases: [(keyCode: UInt16, modifierFlags: UInt, isFn: Bool, description: String)] = [
            (36, 0, false, "bareKey"),
            (0xFFFF, UInt(CGEventFlags.maskCommand.rawValue), false, "modifierCombo"),
            (0, UInt(CGEventFlags.maskCommand.rawValue), false, "keyWithModifiers"),
        ]
        for c in cases {
            let hotkey = UnifiedHotkey(keyCode: c.keyCode, modifierFlags: c.modifierFlags, isFn: c.isFn, isDoubleTap: false)
            profile.hotkey = hotkey
            XCTAssertEqual(profile.hotkey, hotkey, "Round-trip failed for \(c.description)")
        }
    }

    // MARK: - UnifiedHotkey.Kind derived from fields

    func testUnifiedHotkey_kind_bareKey() {
        let h = UnifiedHotkey(keyCode: 36, modifierFlags: 0, isFn: false, isDoubleTap: false)
        XCTAssertEqual(h.kind, .bareKey)
    }

    func testUnifiedHotkey_kind_keyWithModifiers() {
        let flags = UInt(CGEventFlags.maskCommand.rawValue)
        let h = UnifiedHotkey(keyCode: 36, modifierFlags: flags, isFn: false, isDoubleTap: false)
        XCTAssertEqual(h.kind, .keyWithModifiers)
    }

    func testUnifiedHotkey_kind_modifierCombo() {
        let flags = UInt(CGEventFlags.maskCommand.rawValue)
        let h = UnifiedHotkey(keyCode: UnifiedHotkey.modifierComboKeyCode, modifierFlags: flags, isFn: false, isDoubleTap: false)
        XCTAssertEqual(h.kind, .modifierCombo)
    }

    func testUnifiedHotkey_kind_fn() {
        let h = UnifiedHotkey(keyCode: 36, modifierFlags: 0, isFn: true, isDoubleTap: false)
        XCTAssertEqual(h.kind, .fn)
    }

    func testUnifiedHotkey_isDoubleTap_roundTrip() {
        let profile = Profile(name: "Double Tap")
        let hotkey = UnifiedHotkey(keyCode: 36, modifierFlags: 0, isFn: false, isDoubleTap: true)
        profile.hotkey = hotkey
        XCTAssertTrue(profile.hotkey?.isDoubleTap ?? false)
    }
}

