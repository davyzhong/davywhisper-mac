import XCTest
import SwiftUI
import DavyWhisperPluginSDK
@testable import DavyWhisper

// MARK: - Mock Transcription Engine Plugin

/// Minimal mock for testing `hasAnyEngineReady` and `transcriptionEngines`.
final class MockTranscriptionEnginePlugin: TranscriptionEnginePlugin, @unchecked Sendable {
    static var pluginId: String { "mock-engine" }
    static var pluginName: String { "Mock Engine" }

    var providerId: String
    var providerDisplayName: String
    var isConfigured: Bool
    var transcriptionModels: [PluginModelInfo] = []
    var selectedModelId: String?
    var supportsTranslation: Bool = false
    var settingsView: AnyView? { nil }

    required init() {
        self.providerId = "mock"
        self.providerDisplayName = "Mock"
        self.isConfigured = false
    }

    func selectModel(_ modelId: String) {}
    func transcribe(audio: AudioData, language: String?, translate: Bool, prompt: String?) async throws -> PluginTranscriptionResult {
        PluginTranscriptionResult(text: "")
    }
    func activate(host: HostServices) {}
    func deactivate() {}

    init(providerId: String = "mock", providerDisplayName: String = "Mock", isConfigured: Bool = false) {
        self.providerId = providerId
        self.providerDisplayName = providerDisplayName
        self.isConfigured = isConfigured
    }
}

// MARK: - Mock LLM Provider Plugin

/// Minimal mock for testing `hasAnyLLMProvider` and `llmProviders`.
final class MockLLMProviderPlugin: LLMProviderPlugin, @unchecked Sendable {
    static var pluginId: String { "mock-llm" }
    static var pluginName: String { "Mock LLM" }

    var providerName: String
    var isAvailable: Bool = true
    var supportedModels: [PluginModelInfo] = []
    var settingsView: AnyView? { nil }

    required init() {
        self.providerName = "Mock LLM"
    }

    func process(systemPrompt: String, userText: String, model: String?) async throws -> String {
        return ""
    }
    func activate(host: HostServices) {}
    func deactivate() {}

    init(providerName: String = "Mock LLM") {
        self.providerName = providerName
    }
}

@MainActor
final class SetupWizardViewModelTests: XCTestCase {

    var container: TestServiceContainer!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        container = try! TestServiceContainer()
    }

    override func tearDown() {
        // Clean UserDefaults keys used by SetupWizardViewModel
        let keys = [
            UserDefaultsKeys.setupWizardCurrentStep,
            UserDefaultsKeys.setupWizardCompleted,
            UserDefaultsKeys.hybridHotkey,
            UserDefaultsKeys.promptPaletteHotkey
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        container.tearDown()
        container = nil
        super.tearDown()
    }

    // MARK: - Helper: Create ViewModel from Container

    private func makeViewModel() -> SetupWizardViewModel {
        SetupWizardViewModel(
            pluginManager: container.pluginManager,
            registryService: container.pluginRegistryService,
            modelManager: container.modelManagerService,
            dictationViewModel: container.dictationViewModel,
            promptProcessingService: container.promptProcessingService
        )
    }

    // MARK: - Step Navigation

    func testCurrentStep_defaultsToZero_whenNoSavedValue() {
        let vm = makeViewModel()
        // UserDefaults has no saved value -> integer returns 0 -> min(0, 5) = 0
        XCTAssertEqual(vm.currentStep, 0)
    }

    func testCurrentStep_restoresFromUserDefaults() {
        UserDefaults.standard.set(3, forKey: UserDefaultsKeys.setupWizardCurrentStep)
        let vm = makeViewModel()
        XCTAssertEqual(vm.currentStep, 3)
    }

    func testCurrentStep_clampsToMaxFive() {
        UserDefaults.standard.set(99, forKey: UserDefaultsKeys.setupWizardCurrentStep)
        let vm = makeViewModel()
        XCTAssertEqual(vm.currentStep, 5)
    }

    func testTotalSteps_isSix() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.totalSteps, 6)
    }

    func testAdvanceStep_incrementsStep() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.currentStep, 0)
        vm.advanceStep()
        XCTAssertEqual(vm.currentStep, 1)
        vm.advanceStep()
        XCTAssertEqual(vm.currentStep, 2)
    }

    func testAdvanceStep_persistsToUserDefaults() {
        let vm = makeViewModel()
        vm.advanceStep()
        XCTAssertEqual(UserDefaults.standard.integer(forKey: UserDefaultsKeys.setupWizardCurrentStep), 1)
    }

    func testGoBack_decrementsStep() {
        UserDefaults.standard.set(3, forKey: UserDefaultsKeys.setupWizardCurrentStep)
        let vm = makeViewModel()
        XCTAssertEqual(vm.currentStep, 3)
        vm.goBack()
        XCTAssertEqual(vm.currentStep, 2)
    }

    func testGoBack_persistsToUserDefaults() {
        UserDefaults.standard.set(2, forKey: UserDefaultsKeys.setupWizardCurrentStep)
        let vm = makeViewModel()
        vm.goBack()
        XCTAssertEqual(UserDefaults.standard.integer(forKey: UserDefaultsKeys.setupWizardCurrentStep), 1)
    }

    // MARK: - stepTitle

    func testStepTitle_forEachStep() {
        let vm = makeViewModel()
        let expectedTitles: [Int: Bool] = [
            0: false, // "Setup" — not a named step
            1: true,  // "Permissions"
            2: true,  // "Transcription Engine"
            3: true,  // "Hotkey"
            4: true,  // "Prompts & AI"
            5: true,  // "Try It Out"
        ]
        for (step, shouldHaveTitle) in expectedTitles {
            vm.currentStep = step
            XCTAssertFalse(vm.stepTitle.isEmpty, "stepTitle should not be empty for step \(step)")
            if step == 0 {
                // Default case returns "Setup"
                XCTAssertEqual(vm.stepTitle, String(localized: "Setup"))
            }
        }
    }

    // MARK: - canProceed

    func testCanProceed_stepZero_returnsTrue() {
        let vm = makeViewModel()
        vm.currentStep = 0
        XCTAssertTrue(vm.canProceed)
    }

    func testCanProceed_stepOne_dependsOnMicPermission() {
        let vm = makeViewModel()
        vm.currentStep = 1
        // In test environment, mic permission is typically not granted
        // so needsMicPermission is true, making canProceed false
        let expected = !container.dictationViewModel.needsMicPermission
        XCTAssertEqual(vm.canProceed, expected)
    }

    func testCanProceed_stepTwo_dependsOnEngineReady() {
        let vm = makeViewModel()
        vm.currentStep = 2
        // No plugins loaded in test container, so hasAnyEngineReady is false
        XCTAssertFalse(vm.hasAnyEngineReady)
        XCTAssertFalse(vm.canProceed)
    }

    func testCanProceed_stepThree_returnsTrue() {
        let vm = makeViewModel()
        vm.currentStep = 3
        XCTAssertTrue(vm.canProceed)
    }

    func testCanProceed_stepFour_returnsTrue() {
        let vm = makeViewModel()
        vm.currentStep = 4
        XCTAssertTrue(vm.canProceed)
    }

    func testCanProceed_stepFive_returnsTrue() {
        let vm = makeViewModel()
        vm.currentStep = 5
        XCTAssertTrue(vm.canProceed)
    }

    // MARK: - hasAnyEngineReady

    func testHasAnyEngineReady_falseWhenNoEngines() {
        let vm = makeViewModel()
        // TestServiceContainer starts with no loaded plugins
        XCTAssertFalse(vm.hasAnyEngineReady)
    }

    func testHasAnyEngineReady_falseWhenEnginesNotConfigured() {
        let mockEngine = MockTranscriptionEnginePlugin(isConfigured: false)
        let loadedPlugin = makeLoadedPlugin(engine: mockEngine, isEnabled: true)
        container.pluginManager.loadedPlugins = [loadedPlugin]
        let vm = makeViewModel()
        XCTAssertFalse(vm.hasAnyEngineReady)
    }

    func testHasAnyEngineReady_trueWhenEngineConfigured() {
        let mockEngine = MockTranscriptionEnginePlugin(isConfigured: true)
        let loadedPlugin = makeLoadedPlugin(engine: mockEngine, isEnabled: true)
        container.pluginManager.loadedPlugins = [loadedPlugin]
        let vm = makeViewModel()
        XCTAssertTrue(vm.hasAnyEngineReady)
    }

    func testHasAnyEngineReady_falseWhenEngineDisabled() {
        let mockEngine = MockTranscriptionEnginePlugin(isConfigured: true)
        let loadedPlugin = makeLoadedPlugin(engine: mockEngine, isEnabled: false)
        container.pluginManager.loadedPlugins = [loadedPlugin]
        let vm = makeViewModel()
        // transcriptionEngines filters by isEnabled
        XCTAssertFalse(vm.hasAnyEngineReady)
    }

    func testHasAnyEngineReady_trueWhenAtLeastOneConfigured() {
        let unconfigured = MockTranscriptionEnginePlugin(providerId: "a", isConfigured: false)
        let configured = MockTranscriptionEnginePlugin(providerId: "b", isConfigured: true)
        container.pluginManager.loadedPlugins = [
            makeLoadedPlugin(engine: unconfigured, isEnabled: true),
            makeLoadedPlugin(engine: configured, isEnabled: true)
        ]
        let vm = makeViewModel()
        XCTAssertTrue(vm.hasAnyEngineReady)
    }

    // MARK: - hasAnyHotkeySet

    func testHasAnyHotkeySet_falseWhenNoHotkeys() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.hasAnyHotkeySet)
    }

    func testHasAnyHotkeySet_trueWhenHybridHotkeySet() {
        let hotkey = UnifiedHotkey(keyCode: 0x0C, modifierFlags: 0, isFn: false, isDoubleTap: false)
        let data = try! JSONEncoder().encode(hotkey)
        UserDefaults.standard.set(data, forKey: UserDefaultsKeys.hybridHotkey)
        let vm = makeViewModel()
        XCTAssertTrue(vm.hasAnyHotkeySet)
    }

    // MARK: - hasAnyLLMProvider

    func testHasAnyLLMProvider_falseWhenNoProviders() {
        let vm = makeViewModel()
        // TestServiceContainer has no loaded plugins by default
        XCTAssertFalse(vm.hasAnyLLMProvider)
    }

    func testHasAnyLLMProvider_trueWhenLLMProviderLoaded() {
        let mockLLM = MockLLMProviderPlugin(providerName: "Kimi")
        container.pluginManager.loadedPlugins = [
            makeLoadedPlugin(llmProvider: mockLLM, isEnabled: true)
        ]
        let vm = makeViewModel()
        XCTAssertTrue(vm.hasAnyLLMProvider)
    }

    func testHasAnyLLMProvider_falseWhenProviderDisabled() {
        let mockLLM = MockLLMProviderPlugin(providerName: "Kimi")
        container.pluginManager.loadedPlugins = [
            makeLoadedPlugin(llmProvider: mockLLM, isEnabled: false)
        ]
        let vm = makeViewModel()
        XCTAssertFalse(vm.hasAnyLLMProvider)
    }

    // MARK: - kimiAlreadyInstalled

    func testKimiAlreadyInstalled_falseWhenNotInstalled() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.kimiAlreadyInstalled)
    }

    func testKimiAlreadyInstalled_trueWhenKimiPluginLoaded() {
        let mockEngine = MockTranscriptionEnginePlugin()
        let manifest = PluginManifest(id: "com.davywhisper.kimi", name: "Kimi", version: "1.0", principalClass: "MockTranscriptionEnginePlugin")
        let plugin = makeLoadedPlugin(engine: mockEngine, isEnabled: true, manifest: manifest)
        container.pluginManager.loadedPlugins = [plugin]
        let vm = makeViewModel()
        XCTAssertTrue(vm.kimiAlreadyInstalled)
    }

    // MARK: - recommendedManifestIds

    func testRecommendedManifestIds_containsExpectedIds() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.recommendedManifestIds.contains("com.davywhisper.whisperkit"))
        XCTAssertTrue(vm.recommendedManifestIds.contains("com.davywhisper.deepgram"))
        XCTAssertEqual(vm.recommendedManifestIds.count, 2)
    }

    // MARK: - selectedHotkeyMode initialization

    func testSelectedHotkeyMode_defaultsToHybridWhenNoHotkeysSet() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.selectedHotkeyMode, .hybrid)
    }

    func testSelectedHotkeyMode_hybridWhenHybridHotkeySet() {
        let hotkey = UnifiedHotkey(keyCode: 0x0C, modifierFlags: 0, isFn: false, isDoubleTap: false)
        let data = try! JSONEncoder().encode(hotkey)
        UserDefaults.standard.set(data, forKey: UserDefaultsKeys.hybridHotkey)
        let vm = makeViewModel()
        XCTAssertEqual(vm.selectedHotkeyMode, .hybrid)
    }

    // MARK: - hotkeyLabel

    func testHotkeyLabel_returnsLabelsFromDictationViewModel() {
        let vm = makeViewModel()
        let labels = [
            vm.hotkeyLabel(for: .hybrid),
            vm.hotkeyLabel(for: .promptPalette)
        ]
        for label in labels {
            XCTAssertNotNil(label)
        }
    }

    // MARK: - hotkeyModeTitle

    func testHotkeyModeTitle_returnsCorrectTitles() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.hotkeyModeTitle(for: .hybrid).isEmpty)
        XCTAssertFalse(vm.hotkeyModeTitle(for: .promptPalette).isEmpty)
    }

    func testHotkeyModeTitle_returnsDistinctTitles() {
        let vm = makeViewModel()
        let titles = Set([
            vm.hotkeyModeTitle(for: .hybrid),
            vm.hotkeyModeTitle(for: .promptPalette)
        ])
        XCTAssertEqual(titles.count, 2)
    }

    // MARK: - recordHotkey

    func testRecordHotkey_setsHotkeyWithoutConflict() {
        let vm = makeViewModel()
        let hotkey = UnifiedHotkey(keyCode: 0x0C, modifierFlags: UInt(CGEventFlags.maskCommand.rawValue), isFn: false, isDoubleTap: false)
        vm.recordHotkey(hotkey, for: .hybrid)
        let savedData = UserDefaults.standard.data(forKey: UserDefaultsKeys.hybridHotkey)
        XCTAssertNotNil(savedData)
    }

    // MARK: - clearHotkey

    func testClearHotkey_removesHotkeyFromSlot() {
        let vm = makeViewModel()
        let hotkey = UnifiedHotkey(keyCode: 0x0C, modifierFlags: UInt(CGEventFlags.maskCommand.rawValue), isFn: false, isDoubleTap: false)
        vm.recordHotkey(hotkey, for: .hybrid)
        XCTAssertNotNil(UserDefaults.standard.data(forKey: UserDefaultsKeys.hybridHotkey))

        vm.clearHotkey(for: .hybrid)
        XCTAssertNil(UserDefaults.standard.data(forKey: UserDefaultsKeys.hybridHotkey))
    }

    // MARK: - completeSetup

    func testCompleteSetup_setsUserDefaultsFlag() {
        let vm = makeViewModel()
        XCTAssertFalse(UserDefaults.standard.bool(forKey: UserDefaultsKeys.setupWizardCompleted))
        vm.completeSetup()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: UserDefaultsKeys.setupWizardCompleted))
    }

    // MARK: - selectProvider

    func testSelectProvider_updatesModelManagerProvider() {
        let vm = makeViewModel()
        vm.selectProvider("test-provider")
        XCTAssertEqual(container.modelManagerService.selectedProviderId, "test-provider")
    }

    func testSelectProvider_nilDoesNothing() {
        let vm = makeViewModel()
        let before = container.modelManagerService.selectedProviderId
        vm.selectProvider(nil)
        XCTAssertEqual(container.modelManagerService.selectedProviderId, before)
    }

    // MARK: - autoSelectFirstEngine

    func testAutoSelectFirstEngine_keepsCurrentIfValid() {
        let vm = makeViewModel()
        let result = vm.autoSelectFirstEngine(from: ["a", "b", "c"], currentSelected: "b")
        XCTAssertEqual(result, "b")
    }

    func testAutoSelectFirstEngine_picksFirstIfCurrentInvalid() {
        let vm = makeViewModel()
        let result = vm.autoSelectFirstEngine(from: ["a", "b", "c"], currentSelected: "z")
        XCTAssertEqual(result, "a")
    }

    func testAutoSelectFirstEngine_picksFirstIfCurrentNil() {
        let vm = makeViewModel()
        let result = vm.autoSelectFirstEngine(from: ["a", "b", "c"], currentSelected: nil)
        XCTAssertEqual(result, "a")
    }

    func testAutoSelectFirstEngine_returnsNilIfListEmpty() {
        let vm = makeViewModel()
        let result = vm.autoSelectFirstEngine(from: [], currentSelected: nil)
        XCTAssertNil(result)
    }

    func testAutoSelectFirstEngine_keepsCurrentIfInList() {
        let vm = makeViewModel()
        let result = vm.autoSelectFirstEngine(from: ["x"], currentSelected: "x")
        XCTAssertEqual(result, "x")
    }

    // MARK: - currentStep persistence across instances

    func testCurrentStep_persistsAcrossViewModelInstances() {
        let vm1 = makeViewModel()
        vm1.advanceStep()
        vm1.advanceStep()
        XCTAssertEqual(vm1.currentStep, 2)

        // Create a new ViewModel — it should read step 2 from UserDefaults
        let vm2 = makeViewModel()
        XCTAssertEqual(vm2.currentStep, 2)
    }

    // MARK: - canProceed changes with engine state

    func testCanProceed_stepTwo_updatesWhenEngineBecomesConfigured() {
        let vm = makeViewModel()
        vm.currentStep = 2

        // Initially no engines
        XCTAssertFalse(vm.canProceed)

        // Add a configured engine
        let mockEngine = MockTranscriptionEnginePlugin(isConfigured: true)
        container.pluginManager.loadedPlugins = [
            makeLoadedPlugin(engine: mockEngine, isEnabled: true)
        ]

        // Now canProceed should be true
        XCTAssertTrue(vm.canProceed)
    }

    // MARK: - Helper: Create LoadedPlugin

    private func makeLoadedPlugin(
        engine: TranscriptionEnginePlugin,
        isEnabled: Bool,
        manifest: PluginManifest? = nil
    ) -> LoadedPlugin {
        let m = manifest ?? PluginManifest(
            id: engine.providerId,
            name: engine.providerDisplayName,
            version: "1.0",
            principalClass: "MockTranscriptionEnginePlugin"
        )
        return LoadedPlugin(
            manifest: m,
            instance: engine,
            bundle: Bundle.main,
            sourceURL: URL(fileURLWithPath: "/dev/null"),
            isEnabled: isEnabled
        )
    }

    private func makeLoadedPlugin(
        llmProvider: LLMProviderPlugin,
        isEnabled: Bool
    ) -> LoadedPlugin {
        let manifest = PluginManifest(
            id: "mock-llm-\(llmProvider.providerName)",
            name: llmProvider.providerName,
            version: "1.0",
            principalClass: "MockLLMProviderPlugin"
        )
        return LoadedPlugin(
            manifest: manifest,
            instance: llmProvider,
            bundle: Bundle.main,
            sourceURL: URL(fileURLWithPath: "/dev/null"),
            isEnabled: isEnabled
        )
    }
}
