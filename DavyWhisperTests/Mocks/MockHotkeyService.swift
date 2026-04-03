import Foundation
@testable import DavyWhisper

/// Mock HotkeyService for unit testing.
@MainActor
final class MockHotkeyService: HotkeyProtocol {

    // MARK: - State

    var currentMode: HotkeyService.HotkeyMode?

    // MARK: - Call counting

    var registerProfileHotkeysCallCount = 0
    var updateHotkeyCallCount = 0
    var clearHotkeyCallCount = 0
    var isHotkeyAssignedCallCount = 0
    var resetKeyDownTimeCallCount = 0
    var cancelDictationCallCount = 0

    // MARK: - Recorded calls

    private(set) var registeredProfileEntries: [(id: UUID, hotkey: UnifiedHotkey)] = []
    private(set) var updatedHotkeys: [(hotkey: UnifiedHotkey, slotType: HotkeySlotType)] = []
    private(set) var clearedSlots: [HotkeySlotType] = []
    private(set) var hotkeyAssignmentChecks: [(hotkey: UnifiedHotkey, excluding: HotkeySlotType)] = []

    // MARK: - Stubs

    var currentModeStub: HotkeyService.HotkeyMode?
    var updateHotkeyStub: ((UnifiedHotkey, HotkeySlotType) -> Void)?
    var isHotkeyAssignedStub: ((UnifiedHotkey, HotkeySlotType) -> HotkeySlotType?)?
    var registerProfileHotkeysStub: (([(id: UUID, hotkey: UnifiedHotkey)]) -> Void)?

    // MARK: - Protocol methods

    var registeredHotkeys: [UnifiedHotkey] {
        registeredProfileEntries.map(\.hotkey)
    }

    func registerProfileHotkeys(_ entries: [(id: UUID, hotkey: UnifiedHotkey)]) {
        registerProfileHotkeysCallCount += 1
        registeredProfileEntries = entries
        registerProfileHotkeysStub?(entries)
    }

    func updateHotkey(_ hotkey: UnifiedHotkey, for slotType: HotkeySlotType) {
        updateHotkeyCallCount += 1
        updatedHotkeys.append((hotkey, slotType))
        updateHotkeyStub?(hotkey, slotType)
    }

    func clearHotkey(for slotType: HotkeySlotType) {
        clearHotkeyCallCount += 1
        clearedSlots.append(slotType)
    }

    func isHotkeyAssigned(_ hotkey: UnifiedHotkey, excluding: HotkeySlotType) -> HotkeySlotType? {
        isHotkeyAssignedCallCount += 1
        hotkeyAssignmentChecks.append((hotkey, excluding))
        return isHotkeyAssignedStub?(hotkey, excluding)
    }

    func resetKeyDownTime() {
        resetKeyDownTimeCallCount += 1
    }

    func cancelDictation() {
        cancelDictationCallCount += 1
    }

    // MARK: - Convenience helpers

    func simulateModeChange(to mode: HotkeyService.HotkeyMode) {
        currentMode = mode
    }

    func reset() {
        currentMode = nil
        registerProfileHotkeysCallCount = 0
        updateHotkeyCallCount = 0
        clearHotkeyCallCount = 0
        isHotkeyAssignedCallCount = 0
        resetKeyDownTimeCallCount = 0
        cancelDictationCallCount = 0
        registeredProfileEntries = []
        updatedHotkeys = []
        clearedSlots = []
        hotkeyAssignmentChecks = []
        currentModeStub = nil
        updateHotkeyStub = nil
        isHotkeyAssignedStub = nil
        registerProfileHotkeysStub = nil
    }
}
