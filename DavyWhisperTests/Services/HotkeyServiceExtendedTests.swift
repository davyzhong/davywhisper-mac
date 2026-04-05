import XCTest
import Carbon.HIToolbox
@testable import DavyWhisper

// MARK: - HotkeyService Extended Tests
//
// Tests focus on UnifiedHotkey (Codable, Equatable, Kind), HotkeySlotType,
// displayName/keyName, conflict detection, and state management.
// We do NOT test actual CGEventTap or NSEvent monitor setup since those
// require accessibility permissions and a real window server session.

@MainActor
final class HotkeyServiceExtendedTests: XCTestCase {

    private var service: HotkeyService!
    private var savedHotkeys: [String: Data?] = [:]

    override func setUp() {
        super.setUp()
        // Save existing hotkey defaults so we can restore them
        for slotType in HotkeySlotType.allCases {
            savedHotkeys[slotType.defaultsKey] = UserDefaults.standard.data(forKey: slotType.defaultsKey)
        }
        // Clear all stored hotkeys for test isolation
        for slotType in HotkeySlotType.allCases {
            UserDefaults.standard.removeObject(forKey: slotType.defaultsKey)
        }
        service = HotkeyService()
    }

    override func tearDown() {
        service.suspendMonitoring()
        service = nil
        // Restore saved hotkey defaults
        for (key, value) in savedHotkeys {
            if let data = value {
                UserDefaults.standard.set(data, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    // MARK: - UnifiedHotkey: Initialization

    func testUnifiedHotkey_defaultInit() {
        let hotkey = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        XCTAssertEqual(hotkey.keyCode, 0x00)
        XCTAssertEqual(hotkey.modifierFlags, 0)
        XCTAssertFalse(hotkey.isFn)
        XCTAssertFalse(hotkey.isDoubleTap)
    }

    func testUnifiedHotkey_initWithDoubleTap() {
        let hotkey = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false, isDoubleTap: true)
        XCTAssertTrue(hotkey.isDoubleTap)
    }

    func testUnifiedHotkey_modifierComboKeyCode_sentinel() {
        XCTAssertEqual(UnifiedHotkey.modifierComboKeyCode, 0xFFFF)
    }

    // MARK: - UnifiedHotkey: Kind

    func testUnifiedHotkey_kind_fn() {
        let hotkey = UnifiedHotkey(keyCode: 0, modifierFlags: 0, isFn: true)
        XCTAssertEqual(hotkey.kind, .fn)
    }

    func testUnifiedHotkey_kind_fnWithDoubleTap() {
        let hotkey = UnifiedHotkey(keyCode: 0, modifierFlags: 0, isFn: true, isDoubleTap: true)
        XCTAssertEqual(hotkey.kind, .fn)
    }

    func testUnifiedHotkey_kind_modifierOnly_leftCommand() {
        // Left Command keyCode = 0x37
        let hotkey = UnifiedHotkey(keyCode: 0x37, modifierFlags: 0, isFn: false)
        XCTAssertEqual(hotkey.kind, .modifierOnly)
    }

    func testUnifiedHotkey_kind_modifierOnly_leftShift() {
        // Left Shift keyCode = 0x38
        let hotkey = UnifiedHotkey(keyCode: 0x38, modifierFlags: 0, isFn: false)
        XCTAssertEqual(hotkey.kind, .modifierOnly)
    }

    func testUnifiedHotkey_kind_modifierOnly_leftOption() {
        // Left Option keyCode = 0x3A
        let hotkey = UnifiedHotkey(keyCode: 0x3A, modifierFlags: 0, isFn: false)
        XCTAssertEqual(hotkey.kind, .modifierOnly)
    }

    func testUnifiedHotkey_kind_modifierOnly_leftControl() {
        // Left Control keyCode = 0x3B
        let hotkey = UnifiedHotkey(keyCode: 0x3B, modifierFlags: 0, isFn: false)
        XCTAssertEqual(hotkey.kind, .modifierOnly)
    }

    func testUnifiedHotkey_kind_modifierCombo() {
        // CMD+OPT with sentinel keyCode
        let flags = NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.option.rawValue
        let hotkey = UnifiedHotkey(keyCode: UnifiedHotkey.modifierComboKeyCode, modifierFlags: flags, isFn: false)
        XCTAssertEqual(hotkey.kind, .modifierCombo)
    }

    func testUnifiedHotkey_kind_modifierCombo_sentinelWithNoFlags_isBareKey() {
        // Sentinel keyCode with no flags is not a modifierCombo
        let hotkey = UnifiedHotkey(keyCode: UnifiedHotkey.modifierComboKeyCode, modifierFlags: 0, isFn: false)
        // modifierFlags == 0, so it doesn't match modifierCombo, falls through to bareKey
        XCTAssertEqual(hotkey.kind, .bareKey)
    }

    func testUnifiedHotkey_kind_keyWithModifiers() {
        // CMD+A
        let flags = NSEvent.ModifierFlags.command.rawValue
        let hotkey = UnifiedHotkey(keyCode: 0x00, modifierFlags: flags, isFn: false)
        XCTAssertEqual(hotkey.kind, .keyWithModifiers)
    }

    func testUnifiedHotkey_kind_bareKey() {
        // Just "A" with no modifiers
        let hotkey = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        XCTAssertEqual(hotkey.kind, .bareKey)
    }

    // MARK: - UnifiedHotkey: Equatable

    func testUnifiedHotkey_equal() {
        let a = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0x100, isFn: false)
        let b = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0x100, isFn: false)
        XCTAssertEqual(a, b)
    }

    func testUnifiedHotkey_notEqual_keyCode() {
        let a = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        let b = UnifiedHotkey(keyCode: 0x01, modifierFlags: 0, isFn: false)
        XCTAssertNotEqual(a, b)
    }

    func testUnifiedHotkey_notEqual_modifierFlags() {
        let a = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        let b = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0x100, isFn: false)
        XCTAssertNotEqual(a, b)
    }

    func testUnifiedHotkey_notEqual_isFn() {
        let a = UnifiedHotkey(keyCode: 0, modifierFlags: 0, isFn: false)
        let b = UnifiedHotkey(keyCode: 0, modifierFlags: 0, isFn: true)
        XCTAssertNotEqual(a, b)
    }

    func testUnifiedHotkey_notEqual_isDoubleTap() {
        let a = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false, isDoubleTap: false)
        let b = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false, isDoubleTap: true)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - UnifiedHotkey: Codable

    func testUnifiedHotkey_encodeDecode() throws {
        let original = UnifiedHotkey(keyCode: 0x0F, modifierFlags: 0x100, isFn: false, isDoubleTap: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UnifiedHotkey.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertTrue(decoded.isDoubleTap)
    }

    func testUnifiedHotkey_decode_backwardCompatible_missingDoubleTap() throws {
        // Simulate old format without isDoubleTap field
        let json = """
        {"keyCode": 15, "modifierFlags": 256, "isFn": false}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(UnifiedHotkey.self, from: json)
        XCTAssertEqual(decoded.keyCode, 15)
        XCTAssertEqual(decoded.modifierFlags, 256)
        XCTAssertFalse(decoded.isFn)
        XCTAssertFalse(decoded.isDoubleTap) // default
    }

    func testUnifiedHotkey_encodeDecode_fnKey() throws {
        let original = UnifiedHotkey(keyCode: 0, modifierFlags: 0, isFn: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UnifiedHotkey.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertTrue(decoded.isFn)
    }

    // MARK: - HotkeySlotType

    func testHotkeySlotType_allCases() {
        XCTAssertEqual(HotkeySlotType.allCases.count, 2)
        XCTAssertTrue(HotkeySlotType.allCases.contains(.hybrid))
        XCTAssertTrue(HotkeySlotType.allCases.contains(.promptPalette))
    }

    func testHotkeySlotType_defaultsKeys() {
        XCTAssertEqual(HotkeySlotType.hybrid.defaultsKey, UserDefaultsKeys.hybridHotkey)
        XCTAssertEqual(HotkeySlotType.promptPalette.defaultsKey, UserDefaultsKeys.promptPaletteHotkey)
    }

    func testHotkeySlotType_rawValue() {
        XCTAssertEqual(HotkeySlotType.hybrid.rawValue, "hybrid")
        XCTAssertEqual(HotkeySlotType.promptPalette.rawValue, "promptPalette")
    }

    // MARK: - displayName

    func testDisplayName_fnKey() {
        let hotkey = UnifiedHotkey(keyCode: 0, modifierFlags: 0, isFn: true)
        XCTAssertEqual(HotkeyService.displayName(for: hotkey), "Fn")
    }

    func testDisplayName_fnKeyDoubleTap() {
        let hotkey = UnifiedHotkey(keyCode: 0, modifierFlags: 0, isFn: true, isDoubleTap: true)
        XCTAssertEqual(HotkeyService.displayName(for: hotkey), "Fn x2")
    }

    func testDisplayName_bareKey() {
        let hotkey = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        let name = HotkeyService.displayName(for: hotkey)
        // KeyCode 0x00 is "A" on QWERTY
        XCTAssertTrue(name.contains("A"))
    }

    func testDisplayName_commandKey() {
        let flags = NSEvent.ModifierFlags.command.rawValue
        let hotkey = UnifiedHotkey(keyCode: 0x00, modifierFlags: flags, isFn: false)
        let name = HotkeyService.displayName(for: hotkey)
        XCTAssertTrue(name.contains("A"))
        XCTAssertTrue(name.contains("\u{2318}")) // Command symbol
    }

    func testDisplayName_commandOptionKey() {
        let flags = NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.option.rawValue
        let hotkey = UnifiedHotkey(keyCode: 0x00, modifierFlags: flags, isFn: false)
        let name = HotkeyService.displayName(for: hotkey)
        XCTAssertTrue(name.contains("\u{2318}")) // Command
        XCTAssertTrue(name.contains("\u{2325}")) // Option
    }

    func testDisplayName_modifierCombo_cmdOpt() {
        let flags = NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.option.rawValue
        let hotkey = UnifiedHotkey(keyCode: UnifiedHotkey.modifierComboKeyCode, modifierFlags: flags, isFn: false)
        let name = HotkeyService.displayName(for: hotkey)
        XCTAssertTrue(name.contains("\u{2318}"))
        XCTAssertTrue(name.contains("\u{2325}"))
    }

    func testDisplayName_doubleTap_suffix() {
        let flags = NSEvent.ModifierFlags.command.rawValue
        let hotkey = UnifiedHotkey(keyCode: 0x00, modifierFlags: flags, isFn: false, isDoubleTap: true)
        let name = HotkeyService.displayName(for: hotkey)
        XCTAssertTrue(name.hasSuffix(" x2"))
    }

    // MARK: - keyName

    func testKeyName_returnKey() {
        XCTAssertEqual(HotkeyService.keyName(for: 0x24), "\u{23CE}") // Return
    }

    func testKeyName_tabKey() {
        XCTAssertEqual(HotkeyService.keyName(for: 0x30), "\u{21E5}") // Tab
    }

    func testKeyName_spaceKey() {
        XCTAssertEqual(HotkeyService.keyName(for: 0x31), "\u{2423}") // Space
    }

    func testKeyName_deleteKey() {
        XCTAssertEqual(HotkeyService.keyName(for: 0x33), "\u{232B}") // Delete
    }

    func testKeyName_escapeKey() {
        XCTAssertEqual(HotkeyService.keyName(for: 0x35), "\u{238B}") // Escape
    }

    func testKeyName_f1ThroughF12() {
        let expected: [(UInt16, String)] = [
            (0x7A, "F1"), (0x78, "F2"), (0x63, "F3"), (0x76, "F4"),
            (0x60, "F5"), (0x61, "F6"), (0x62, "F7"), (0x64, "F8"),
            (0x65, "F9"), (0x6D, "F10"), (0x67, "F11"), (0x6F, "F12"),
        ]
        for (keyCode, expectedName) in expected {
            XCTAssertEqual(HotkeyService.keyName(for: keyCode), expectedName, "keyCode \(keyCode)")
        }
    }

    func testKeyName_arrowKeys() {
        XCTAssertEqual(HotkeyService.keyName(for: 0x7E), "\u{2191}") // Up
        XCTAssertEqual(HotkeyService.keyName(for: 0x7D), "\u{2193}") // Down
        XCTAssertEqual(HotkeyService.keyName(for: 0x7B), "\u{2190}") // Left
        XCTAssertEqual(HotkeyService.keyName(for: 0x7C), "\u{2192}") // Right
    }

    func testKeyName_leftCommand() {
        XCTAssertEqual(HotkeyService.keyName(for: 0x37), "Left Command")
    }

    func testKeyName_rightCommand() {
        XCTAssertEqual(HotkeyService.keyName(for: 0x36), "Right Command")
    }

    func testKeyName_unknownKey() {
        let name = HotkeyService.keyName(for: 0xFF)
        XCTAssertTrue(name.hasPrefix("Key "))
    }

    // MARK: - modifierKeyCodes

    func testModifierKeyCodes_containsExpectedKeys() {
        let expectedCodes: Set<UInt16> = [0x37, 0x36, 0x38, 0x3C, 0x3A, 0x3D, 0x3B, 0x3E]
        XCTAssertEqual(HotkeyService.modifierKeyCodes, expectedCodes)
    }

    // MARK: - updateHotkey / clearHotkey

    func testUpdateHotkey_savesToDefaults() throws {
        let hotkey = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        service.updateHotkey(hotkey, for: .hybrid)

        let data = UserDefaults.standard.data(forKey: HotkeySlotType.hybrid.defaultsKey)
        XCTAssertNotNil(data)
        let decoded = try JSONDecoder().decode(UnifiedHotkey.self, from: XCTUnwrap(data))
        XCTAssertEqual(decoded, hotkey)
    }

    func testClearHotkey_removesFromDefaults() {
        let hotkey = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        service.updateHotkey(hotkey, for: .hybrid)
        service.clearHotkey(for: .hybrid)
        XCTAssertNil(UserDefaults.standard.data(forKey: HotkeySlotType.hybrid.defaultsKey))
    }

    // MARK: - isHotkeyAssigned

    func testIsHotkeyAssigned_noConflict_returnsNil() {
        let hotkey = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        XCTAssertNil(service.isHotkeyAssigned(hotkey, excluding: .hybrid))
    }

    func testIsHotkeyAssigned_sameHotkeyInOtherSlot_returnsSlot() {
        let hotkey = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        service.updateHotkey(hotkey, for: .promptPalette)
        let result = service.isHotkeyAssigned(hotkey, excluding: .hybrid)
        XCTAssertEqual(result, .promptPalette)
    }

    func testIsHotkeyAssigned_sameHotkeyExcludingSelf_returnsNil() {
        let hotkey = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        service.updateHotkey(hotkey, for: .hybrid)
        // Excluding hybrid, the same hotkey should not conflict with itself
        let result = service.isHotkeyAssigned(hotkey, excluding: .hybrid)
        XCTAssertNil(result)
    }

    func testIsHotkeyAssigned_doubleTapConflict() {
        let singleTap = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false, isDoubleTap: false)
        let doubleTap = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false, isDoubleTap: true)
        service.updateHotkey(singleTap, for: .promptPalette)
        let result = service.isHotkeyAssigned(doubleTap, excluding: .hybrid)
        XCTAssertEqual(result, .promptPalette)
    }

    func testIsHotkeyAssigned_differentKey_noConflict() {
        let hotkey1 = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        let hotkey2 = UnifiedHotkey(keyCode: 0x01, modifierFlags: 0, isFn: false)
        service.updateHotkey(hotkey1, for: .promptPalette)
        XCTAssertNil(service.isHotkeyAssigned(hotkey2, excluding: .hybrid))
    }

    // MARK: - cancelDictation

    func testCancelDictation_resetsState() {
        service.cancelDictation()
        XCTAssertNil(service.currentMode)
    }

    func testCancelDictation_clearsActiveProfileId() {
        service.cancelDictation()
        XCTAssertNil(service.activeProfileId)
    }

    // MARK: - resetKeyDownTime

    func testResetKeyDownTime_doesNotCrash() {
        // Should not crash even when not recording
        service.resetKeyDownTime()
    }

    // MARK: - suspendMonitoring / resumeMonitoring

    func testSuspendMonitoring_doesNotCrash() {
        service.suspendMonitoring()
    }

    func testResumeMonitoring_doesNotCrash() {
        service.resumeMonitoring()
    }

    func testSuspendAndResumeMonitoring() {
        service.suspendMonitoring()
        service.resumeMonitoring()
        // Should be able to suspend again after resume
        service.suspendMonitoring()
    }

    // MARK: - registerProfileHotkeys

    func testRegisterProfileHotkeys_registersEntries() {
        let profileId = UUID()
        let hotkey = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        service.registerProfileHotkeys([(id: profileId, hotkey: hotkey)])
        // No crash means success; internal state is private
    }

    func testRegisterProfileHotkeys_replacesExisting() {
        let profileId1 = UUID()
        let profileId2 = UUID()
        let hotkey1 = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        let hotkey2 = UnifiedHotkey(keyCode: 0x01, modifierFlags: 0, isFn: false)

        service.registerProfileHotkeys([(id: profileId1, hotkey: hotkey1)])
        service.registerProfileHotkeys([(id: profileId2, hotkey: hotkey2)])
        // Second call should replace first set
    }

    func testRegisterProfileHotkeys_emptyArray() {
        service.registerProfileHotkeys([])
        // Should work without error
    }

    // MARK: - isHotkeyAssignedToProfile

    func testIsHotkeyAssignedToProfile_noProfiles_returnsNil() {
        let hotkey = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        XCTAssertNil(service.isHotkeyAssignedToProfile(hotkey, excludingProfileId: nil))
    }

    func testIsHotkeyAssignedToProfile_matchingProfile_returnsId() {
        let profileId = UUID()
        let hotkey = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        service.registerProfileHotkeys([(id: profileId, hotkey: hotkey)])

        let result = service.isHotkeyAssignedToProfile(hotkey, excludingProfileId: nil)
        XCTAssertEqual(result, profileId)
    }

    func testIsHotkeyAssignedToProfile_excludingSelf_returnsNil() {
        let profileId = UUID()
        let hotkey = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        service.registerProfileHotkeys([(id: profileId, hotkey: hotkey)])

        let result = service.isHotkeyAssignedToProfile(hotkey, excludingProfileId: profileId)
        XCTAssertNil(result)
    }

    func testIsHotkeyAssignedToProfile_doubleTapConflict() {
        let profileId = UUID()
        let singleTap = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false, isDoubleTap: false)
        let doubleTap = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false, isDoubleTap: true)
        service.registerProfileHotkeys([(id: profileId, hotkey: singleTap)])

        let result = service.isHotkeyAssignedToProfile(doubleTap, excludingProfileId: nil)
        XCTAssertEqual(result, profileId)
    }

    // MARK: - isHotkeyAssignedToGlobalSlot

    func testIsHotkeyAssignedToGlobalSlot_noHotkeys_returnsNil() {
        let hotkey = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        XCTAssertNil(service.isHotkeyAssignedToGlobalSlot(hotkey))
    }

    func testIsHotkeyAssignedToGlobalSlot_matchingHotkey_returnsSlot() {
        let hotkey = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        service.updateHotkey(hotkey, for: .promptPalette)
        let result = service.isHotkeyAssignedToGlobalSlot(hotkey)
        XCTAssertEqual(result, .promptPalette)
    }

    func testIsHotkeyAssignedToGlobalSlot_differentHotkey_returnsNil() {
        let hotkey1 = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        let hotkey2 = UnifiedHotkey(keyCode: 0x01, modifierFlags: 0, isFn: false)
        service.updateHotkey(hotkey1, for: .hybrid)
        XCTAssertNil(service.isHotkeyAssignedToGlobalSlot(hotkey2))
    }

    // MARK: - HotkeyService.HotkeyMode

    func testHotkeyMode_rawValues() {
        XCTAssertEqual(HotkeyService.HotkeyMode.pushToTalk.rawValue, "pushToTalk")
        XCTAssertEqual(HotkeyService.HotkeyMode.toggle.rawValue, "toggle")
    }

    // MARK: - Multiple slots with different hotkeys

    func testMultipleSlots_differentHotkeys_noConflict() {
        let h1 = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        let h2 = UnifiedHotkey(keyCode: 0x01, modifierFlags: 0, isFn: false)

        service.updateHotkey(h1, for: .hybrid)
        service.updateHotkey(h2, for: .promptPalette)

        XCTAssertNil(service.isHotkeyAssigned(h1, excluding: .hybrid))
        XCTAssertNil(service.isHotkeyAssigned(h2, excluding: .promptPalette))
    }

    func testMultipleSlots_sameHotkey_conflicts() {
        let hotkey = UnifiedHotkey(keyCode: 0x00, modifierFlags: 0, isFn: false)
        service.updateHotkey(hotkey, for: .hybrid)
        service.updateHotkey(hotkey, for: .promptPalette)

        let conflict1 = service.isHotkeyAssigned(hotkey, excluding: .hybrid)
        XCTAssertNotNil(conflict1)

        let conflict2 = service.isHotkeyAssigned(hotkey, excluding: .promptPalette)
        XCTAssertNotNil(conflict2)
    }
}
