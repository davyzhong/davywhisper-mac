import Foundation
import DavyWhisperPluginSDK

/// Tier B: abstracts plugin-manager access for testability.
public protocol ModelManaging: AnyObject {
    var transcriptionEngines: [String] { get }
    func transcriptionEngine(for name: String) -> TranscriptionEnginePlugin?
    func defaultEngine() -> TranscriptionEnginePlugin?
    func setProviderSelection(provider: String)
    func restoreProviderSelection()
    func setProfileNamesProvider(_ provider: @escaping () -> [String])
    func validateSelectionAfterPluginLoad()
}
