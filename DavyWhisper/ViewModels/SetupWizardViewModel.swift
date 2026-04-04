import Foundation
import DavyWhisperPluginSDK

/// Manages setup wizard state: step navigation, readiness checks, and plugin orchestration.
/// Extracted from SetupWizardView to enable unit testing.
@MainActor
final class SetupWizardViewModel: ObservableObject {

    // MARK: - Step Management

    @Published var currentStep: Int {
        didSet { UserDefaults.standard.set(currentStep, forKey: UserDefaultsKeys.setupWizardCurrentStep) }
    }

    let totalSteps = 6

    // MARK: - Hotkey Mode

    @Published var selectedHotkeyMode: HotkeySlotType

    // MARK: - Dependencies

    private let pluginManager: PluginManager
    private let registryService: PluginRegistryService
    private let modelManager: ModelManagerService
    private let dictationViewModel: DictationViewModel
    private let promptProcessingService: PromptProcessingService

    // MARK: - Init

    init(
        pluginManager: PluginManager = PluginManager.shared,
        registryService: PluginRegistryService = PluginRegistryService.shared,
        modelManager: ModelManagerService = ServiceContainer.shared.modelManagerService,
        dictationViewModel: DictationViewModel = DictationViewModel.shared,
        promptProcessingService: PromptProcessingService
    ) {
        let saved = UserDefaults.standard.integer(forKey: UserDefaultsKeys.setupWizardCurrentStep)
        self.currentStep = min(saved, 5)

        self.pluginManager = pluginManager
        self.registryService = registryService
        self.modelManager = modelManager
        self.dictationViewModel = dictationViewModel
        self.promptProcessingService = promptProcessingService

        if UserDefaults.standard.data(forKey: UserDefaultsKeys.hybridHotkey) != nil {
            _selectedHotkeyMode = Published(initialValue: .hybrid)
        } else if UserDefaults.standard.data(forKey: UserDefaultsKeys.pttHotkey) != nil {
            _selectedHotkeyMode = Published(initialValue: .pushToTalk)
        } else if UserDefaults.standard.data(forKey: UserDefaultsKeys.toggleHotkey) != nil {
            _selectedHotkeyMode = Published(initialValue: .toggle)
        } else {
            _selectedHotkeyMode = Published(initialValue: .hybrid)
        }
    }

    // MARK: - Step Titles

    var stepTitle: String {
        switch currentStep {
        case 1: return String(localized: "Permissions")
        case 2: return String(localized: "Transcription Engine")
        case 3: return String(localized: "Hotkey")
        case 4: return String(localized: "Prompts & AI")
        case 5: return String(localized: "Try It Out")
        default: return String(localized: "Setup")
        }
    }

    // MARK: - Navigation

    var canProceed: Bool {
        switch currentStep {
        case 1: return !dictationViewModel.needsMicPermission
        case 2: return hasAnyEngineReady
        case 3: return true
        case 4: return true
        default: return true
        }
    }

    func advanceStep() {
        currentStep += 1
    }

    func goBack() {
        currentStep -= 1
    }

    func completeSetup() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.setupWizardCompleted)
    }

    // MARK: - Engine Readiness

    var hasAnyEngineReady: Bool {
        pluginManager.transcriptionEngines.contains { $0.isConfigured }
    }

    var hasAnyHotkeySet: Bool {
        [UserDefaultsKeys.hybridHotkey, UserDefaultsKeys.pttHotkey, UserDefaultsKeys.toggleHotkey]
            .contains { UserDefaults.standard.data(forKey: $0) != nil }
    }

    var hasAnyLLMProvider: Bool {
        if #available(macOS 26, *) {
            if promptProcessingService.isAppleIntelligenceAvailable { return true }
        }
        return !pluginManager.llmProviders.isEmpty
    }

    @available(macOS 26, *)
    var isAppleIntelligenceAvailable: Bool {
        promptProcessingService.isAppleIntelligenceAvailable
    }

    // MARK: - Plugin Checks

    var kimiAlreadyInstalled: Bool {
        pluginManager.loadedPlugins.contains { $0.manifest.id == "com.davywhisper.kimi" }
    }

    let recommendedManifestIds: Set<String> = [
        "com.davywhisper.whisperkit",
        "com.davywhisper.deepgram"
    ]

    // MARK: - Hotkey Labels

    func hotkeyLabel(for mode: HotkeySlotType) -> String {
        switch mode {
        case .hybrid: return dictationViewModel.hybridHotkeyLabel
        case .pushToTalk: return dictationViewModel.pttHotkeyLabel
        case .toggle: return dictationViewModel.toggleHotkeyLabel
        case .promptPalette: return dictationViewModel.promptPaletteHotkeyLabel
        }
    }

    func hotkeyModeTitle(for mode: HotkeySlotType) -> String {
        switch mode {
        case .hybrid: return String(localized: "Hybrid")
        case .pushToTalk: return String(localized: "Push-to-Talk")
        case .toggle: return String(localized: "Toggle")
        case .promptPalette: return String(localized: "Prompt Palette")
        }
    }

    // MARK: - Hotkey Recording

    func recordHotkey(_ hotkey: UnifiedHotkey, for mode: HotkeySlotType) {
        if let conflict = dictationViewModel.isHotkeyAssigned(hotkey, excluding: mode) {
            dictationViewModel.clearHotkey(for: conflict)
        }
        dictationViewModel.setHotkey(hotkey, for: mode)
    }

    func clearHotkey(for mode: HotkeySlotType) {
        dictationViewModel.clearHotkey(for: mode)
    }

    // MARK: - Plugin Installation

    func installPlugin(_ registryPlugin: RegistryPlugin) async {
        await registryService.downloadAndInstall(registryPlugin)
        pluginManager.setPluginEnabled(registryPlugin.id, enabled: true)
    }

    // MARK: - Engine Selection

    func selectProvider(_ providerId: String?) {
        guard let providerId else { return }
        modelManager.selectProvider(providerId)
    }

    func autoSelectFirstEngine(from engineIds: [String], currentSelected: String?) -> String? {
        if let current = currentSelected, engineIds.contains(current) {
            return current
        }
        return engineIds.first
    }
}
