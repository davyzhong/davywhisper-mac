import Foundation
import AppKit
import DavyWhisper

/// Manages advanced settings state: HuggingFace mirror toggle.
@MainActor
final class AdvancedSettingsViewModel: ObservableObject {

    // MARK: - HuggingFace Mirror

    var hfMirrorEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: UserDefaultsKeys.useHuggingFaceMirror) }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.useHuggingFaceMirror) }
    }
}
