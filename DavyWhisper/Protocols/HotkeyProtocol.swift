import Foundation

/// Abstracts global hotkey registration for testability.
/// The production implementation is HotkeyService.
@MainActor
protocol HotkeyProtocol: AnyObject {
    var currentMode: HotkeyService.HotkeyMode? { get }

    func registerProfileHotkeys(_ entries: [(id: UUID, hotkey: UnifiedHotkey)])
    func updateHotkey(_ hotkey: UnifiedHotkey, for slotType: HotkeySlotType)
    func clearHotkey(for slotType: HotkeySlotType)
    func isHotkeyAssigned(_ hotkey: UnifiedHotkey, excluding: HotkeySlotType) -> HotkeySlotType?
    func resetKeyDownTime()
    func cancelDictation()
}
