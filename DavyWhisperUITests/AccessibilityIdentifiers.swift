import Foundation

/// Centralized accessibility identifiers for all UI elements.
/// Using constants instead of string literals prevents typos and enables
/// IDE auto-complete in tests.
enum AccessibilityIdentifiers {

    // MARK: - Menu Bar

    enum MenuBar {
        /// The menu bar status item button
        static let statusItem = "com.davywhisper.menubar.statusitem"

        /// Start dictation menu item
        static let startDictation = "com.davywhisper.menubar.startDictation"

        /// Stop dictation menu item
        static let stopDictation = "com.davywhisper.menubar.stopDictation"

        /// Settings menu item
        static let openSettings = "com.davywhisper.menubar.openSettings"

        /// Quit menu item
        static let quit = "com.davywhisper.menubar.quit"
    }

    // MARK: - Settings Window

    enum Settings {
        /// Main settings window
        static let window = "com.davywhisper.settings.window"

        // Tab navigation
        static let tabGeneral = "com.davywhisper.settings.tab.general"
        static let tabRecording = "com.davywhisper.settings.tab.recording"
        static let tabFileTranscription = "com.davywhisper.settings.tab.fileTranscription"
        static let tabHistory = "com.davywhisper.settings.tab.history"
        static let tabDictionary = "com.davywhisper.settings.tab.dictionary"
        static let tabProfiles = "com.davywhisper.settings.tab.profiles"
        static let tabPrompts = "com.davywhisper.settings.tab.prompts"
        static let tabIntegrations = "com.davywhisper.settings.tab.integrations"
        static let tabAdvanced = "com.davywhisper.settings.tab.advanced"

        // General settings
        static let soundFeedbackToggle = "com.davywhisper.settings.general.soundFeedback"
        static let preserveClipboardToggle = "com.davywhisper.settings.general.preserveClipboard"
        static let indicatorStylePicker = "com.davywhisper.settings.general.indicatorStyle"
        static let languagePicker = "com.davywhisper.settings.general.language"

        // Recording settings
        static let microphonePicker = "com.davywhisper.settings.recording.microphone"
        static let hotkeyHybrid = "com.davywhisper.settings.recording.hotkey.hybrid"
        static let hotkeyPTT = "com.davywhisper.settings.recording.hotkey.ptt"
        static let hotkeyToggle = "com.davywhisper.settings.recording.hotkey.toggle"
        static let hotkeyPromptPalette = "com.davywhisper.settings.recording.hotkey.promptPalette"
        static let requestMicPermissionButton = "com.davywhisper.settings.recording.requestMicPermission"
        static let requestAccessibilityButton = "com.davywhisper.settings.recording.requestAccessibility"

        // History settings
        static let historyList = "com.davywhisper.settings.history.list"
        static let historySearchField = "com.davywhisper.settings.history.search"
        static let historyClearAllButton = "com.davywhisper.settings.history.clearAll"

        // Dictionary settings
        static let dictionaryList = "com.davywhisper.settings.dictionary.list"
        static let dictionaryAddButton = "com.davywhisper.settings.dictionary.add"
        static let dictionaryEntryTerm = "com.davywhisper.settings.dictionary.term"
        static let dictionaryEntryCorrection = "com.davywhisper.settings.dictionary.correction"
        static let dictionarySaveButton = "com.davywhisper.settings.dictionary.save"

        // Profiles settings
        static let profilesList = "com.davywhisper.settings.profiles.list"
        static let profilesAddButton = "com.davywhisper.settings.profiles.add"
        static let profileNameField = "com.davywhisper.settings.profiles.name"
        static let profileBundleIdField = "com.davywhisper.settings.profiles.bundleId"
        static let profileSaveButton = "com.davywhisper.settings.profiles.save"

        // Prompts settings
        static let promptsList = "com.davywhisper.settings.prompts.list"
        static let promptsAddButton = "com.davywhisper.settings.prompts.add"

        // Integrations (plugin) settings
        static let pluginList = "com.davywhisper.settings.integrations.pluginList"
        static let pluginRefreshButton = "com.davywhisper.settings.integrations.refresh"

        // Advanced settings
        static let hfMirrorToggle = "com.davywhisper.settings.advanced.hfMirror"
        static let apiServerPortField = "com.davywhisper.settings.advanced.apiServerPort"
        static let apiServerToggle = "com.davywhisper.settings.advanced.apiServer"
        static let resetAllSettingsButton = "com.davywhisper.settings.advanced.resetAll"
    }

    // MARK: - Setup Wizard

    enum SetupWizard {
        static let welcomeTitle = "com.davywhisper.setup.welcome.title"
        static let welcomeContinueButton = "com.davywhisper.setup.welcome.continue"
        static let permissionMicButton = "com.davywhisper.setup.permission.mic"
        static let permissionAccessibilityButton = "com.davywhisper.setup.permission.accessibility"
        static let finishDoneButton = "com.davywhisper.setup.finish.done"
    }

    // MARK: - Alert / Sheets

    enum Alerts {
        static let okButton = "com.davywhisper.alert.ok"
        static let cancelButton = "com.davywhisper.alert.cancel"
        static let deleteButton = "com.davywhisper.alert.delete"
    }
}
