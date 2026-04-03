import XCTest
@testable import DavyWhisper

final class UnifiedHotkeyTests: XCTestCase {

    // MARK: - Codable

    func testCodable_roundTrip() throws {
        let hotkey = UnifiedHotkey(
            keyCode: 0x0C, modifierFlags: 0x100, isFn: false, isDoubleTap: false
        )
        let data = try JSONEncoder().encode(hotkey)
        let decoded = try JSONDecoder().decode(UnifiedHotkey.self, from: data)
        XCTAssertEqual(decoded, hotkey)
    }

    func testCodable_backwardCompatibleWithoutIsDoubleTap() throws {
        // Old JSON without isDoubleTap should decode with default false
        let oldJSON = """
        {"keyCode":18,"modifierFlags":2048,"isFn":false}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(UnifiedHotkey.self, from: oldJSON)
        XCTAssertEqual(decoded.isDoubleTap, false)
        XCTAssertEqual(decoded.keyCode, 18)
        XCTAssertEqual(decoded.modifierFlags, 2048)
    }

    // MARK: - Kind Computation

    func testKind_fnKey() {
        let h = UnifiedHotkey(keyCode: 0x03, modifierFlags: 0, isFn: true)
        XCTAssertEqual(h.kind, .fn)
    }

    func testKind_modifierOnly() {
        // Left Command = 0x37, no modifierFlags on the key itself
        let h = UnifiedHotkey(keyCode: 0x37, modifierFlags: 0, isFn: false)
        XCTAssertEqual(h.kind, .modifierOnly)
    }

    func testKind_modifierCombo() {
        // modifierComboKeyCode (0xFFFF) with modifiers = modifier combo
        let h = UnifiedHotkey(
            keyCode: UnifiedHotkey.modifierComboKeyCode,
            modifierFlags: 0x100,
            isFn: false
        )
        XCTAssertEqual(h.kind, .modifierCombo)
    }

    func testKind_keyWithModifiers() {
        let h = UnifiedHotkey(keyCode: 0x0C, modifierFlags: 0x100, isFn: false)
        XCTAssertEqual(h.kind, .keyWithModifiers)
    }

    func testKind_bareKey() {
        let h = UnifiedHotkey(keyCode: 0x0C, modifierFlags: 0, isFn: false)
        XCTAssertEqual(h.kind, .bareKey)
    }

    // MARK: - Equatable

    func testEquatable_sameValues() {
        let a = UnifiedHotkey(keyCode: 1, modifierFlags: 2, isFn: false, isDoubleTap: false)
        let b = UnifiedHotkey(keyCode: 1, modifierFlags: 2, isFn: false, isDoubleTap: false)
        XCTAssertEqual(a, b)
    }

    func testEquatable_differentIsDoubleTap() {
        let a = UnifiedHotkey(keyCode: 1, modifierFlags: 2, isFn: false, isDoubleTap: false)
        let b = UnifiedHotkey(keyCode: 1, modifierFlags: 2, isFn: false, isDoubleTap: true)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - modifierComboKeyCode

    func testModifierComboKeyCode_sentinelValue() {
        XCTAssertEqual(UnifiedHotkey.modifierComboKeyCode, 0xFFFF)
        // Should be different from any real keyCode
        XCTAssertNotEqual(UnifiedHotkey.modifierComboKeyCode, 0x37) // Command
        XCTAssertNotEqual(UnifiedHotkey.modifierComboKeyCode, 0x0C) // K
    }

    // MARK: - isDoubleTap in Codable

    func testCodable_withDoubleTap() throws {
        let h = UnifiedHotkey(keyCode: 1, modifierFlags: 2, isFn: false, isDoubleTap: true)
        let data = try JSONEncoder().encode(h)
        let decoded = try JSONDecoder().decode(UnifiedHotkey.self, from: data)
        XCTAssertEqual(decoded.isDoubleTap, true)
    }

    func testCodable_explicitFalseStillEncodes() throws {
        let h = UnifiedHotkey(keyCode: 1, modifierFlags: 2, isFn: false, isDoubleTap: false)
        let data = try JSONEncoder().encode(h)
        let decoded = try JSONDecoder().decode(UnifiedHotkey.self, from: data)
        XCTAssertEqual(decoded.isDoubleTap, false)
    }
}

// MARK: - HotkeySlotType Tests

final class HotkeySlotTypeTests: XCTestCase {

    func testAllCases_haveDefaultsKey() {
        for slot in HotkeySlotType.allCases {
            XCTAssertFalse(slot.defaultsKey.isEmpty)
        }
    }

    func testDefaultsKey_uniquePerCase() {
        let keys = HotkeySlotType.allCases.map(\.defaultsKey)
        XCTAssertEqual(keys.count, Set(keys).count, "HotkeySlotType defaultsKeys must be unique")
    }

    func testRawValues_knownCases() {
        XCTAssertEqual(HotkeySlotType.hybrid.rawValue, "hybrid")
        XCTAssertEqual(HotkeySlotType.pushToTalk.rawValue, "pushToTalk")
        XCTAssertEqual(HotkeySlotType.toggle.rawValue, "toggle")
        XCTAssertEqual(HotkeySlotType.promptPalette.rawValue, "promptPalette")
    }
}
