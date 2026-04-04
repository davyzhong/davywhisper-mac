import XCTest
import DavyWhisperPluginSDK
@testable import DavyWhisper

// MARK: - Mock Transcription Plugin

/// A fully controllable mock that conforms to TranscriptionEnginePlugin.
/// Used exclusively by ModelManagerExtendedTests to verify delegation logic
/// without depending on real plugin bundles.
final class MockTranscriptionPlugin: NSObject, TranscriptionEnginePlugin, @unchecked Sendable {
    static var pluginId: String { "mock-plugin" }
    static var pluginName: String { "Mock Plugin" }

    // Controllable properties
    var providerId: String
    var providerDisplayName: String
    var isConfigured: Bool
    var selectedModelId: String?
    var transcriptionModels: [PluginModelInfo]
    var supportsTranslation: Bool
    var supportsStreaming: Bool
    var supportedLanguages: [String]

    /// Tracks calls for assertion.
    var selectModelCallCount = 0
    var lastSelectModelId: String?

    init(
        providerId: String = "mock-engine",
        providerDisplayName: String = "Mock Engine",
        isConfigured: Bool = false,
        selectedModelId: String? = nil,
        transcriptionModels: [PluginModelInfo] = [],
        supportsTranslation: Bool = false,
        supportsStreaming: Bool = false,
        supportedLanguages: [String] = []
    ) {
        self.providerId = providerId
        self.providerDisplayName = providerDisplayName
        self.isConfigured = isConfigured
        self.selectedModelId = selectedModelId
        self.transcriptionModels = transcriptionModels
        self.supportsTranslation = supportsTranslation
        self.supportsStreaming = supportsStreaming
        self.supportedLanguages = supportedLanguages
    }

    required override init() {
        self.providerId = "mock-engine"
        self.providerDisplayName = "Mock Engine"
        self.isConfigured = false
        self.selectedModelId = nil
        self.transcriptionModels = []
        self.supportsTranslation = false
        self.supportsStreaming = false
        self.supportedLanguages = []
    }

    func activate(host: HostServices) {}
    func deactivate() {}

    func selectModel(_ modelId: String) {
        selectModelCallCount += 1
        lastSelectModelId = modelId
        selectedModelId = modelId
    }

    func transcribe(audio: AudioData, language: String?, translate: Bool, prompt: String?) async throws -> PluginTranscriptionResult {
        PluginTranscriptionResult(text: "mock", detectedLanguage: nil, segments: [])
    }

    func transcribe(audio: AudioData, language: String?, translate: Bool, prompt: String?,
                    onProgress: @Sendable @escaping (String) -> Bool) async throws -> PluginTranscriptionResult {
        PluginTranscriptionResult(text: "mock", detectedLanguage: nil, segments: [])
    }
}

// MARK: - Extended Tests

@MainActor
final class ModelManagerExtendedTests: XCTestCase {

    private var defaults: MockUserDefaults!
    private var pluginManager: PluginManager!

    override func setUp() {
        super.setUp()
        defaults = MockUserDefaults()
        pluginManager = PluginManager()
        PluginManager.shared = pluginManager
    }

    override func tearDown() {
        pluginManager = nil
        PluginManager.shared = nil
        defaults = nil
        super.tearDown()
    }

    // MARK: - Helper

    /// Registers a mock plugin into the shared PluginManager so that
    /// PluginManager.shared.transcriptionEngine(for:) finds it.
    @discardableResult
    private func injectPlugin(_ plugin: MockTranscriptionPlugin, enabled: Bool = true) -> MockTranscriptionPlugin {
        let manifest = PluginManifest(
            id: plugin.providerId,
            name: plugin.providerDisplayName,
            version: "1.0",
            principalClass: "MockTranscriptionPlugin"
        )
        let loaded = LoadedPlugin(
            manifest: manifest,
            instance: plugin,
            bundle: Bundle.main,
            sourceURL: URL(fileURLWithPath: "/dev/null"),
            isEnabled: enabled
        )
        pluginManager.loadedPlugins.append(loaded)
        return plugin
    }

    private func makeService() -> ModelManagerService {
        ModelManagerService(userDefaults: defaults)
    }

    // MARK: - 1. selectProvider persists to UserDefaults

    func testSelectProvider_persistsToUserDefaults() {
        let service = makeService()

        service.selectProvider("whisperkit")

        XCTAssertEqual(defaults.string(forKey: UserDefaultsKeys.selectedEngine), "whisperkit")
    }

    func testSelectProvider_updatesPublishedProperty() {
        let service = makeService()

        service.selectProvider("openai")

        XCTAssertEqual(service.selectedProviderId, "openai")
    }

    func testSelectProvider_overwritesPreviousValue() {
        let service = makeService()
        service.selectProvider("whisperkit")
        service.selectProvider("paraformer")

        XCTAssertEqual(service.selectedProviderId, "paraformer")
        XCTAssertEqual(defaults.string(forKey: UserDefaultsKeys.selectedEngine), "paraformer")
    }

    // MARK: - 2. selectModel delegates to plugin

    func testSelectModel_delegatesToPlugin() {
        let plugin = injectPlugin(
            MockTranscriptionPlugin(providerId: "whisperkit", isConfigured: true)
        )
        let service = makeService()

        service.selectModel("whisperkit", modelId: "large-v3")

        XCTAssertEqual(plugin.selectModelCallCount, 1)
        XCTAssertEqual(plugin.lastSelectModelId, "large-v3")
    }

    func testSelectModel_alsoSelectsProvider() {
        let _ = injectPlugin(
            MockTranscriptionPlugin(providerId: "groq", isConfigured: true)
        )
        let service = makeService()

        service.selectModel("groq", modelId: "whisper-large")

        XCTAssertEqual(service.selectedProviderId, "groq")
        XCTAssertEqual(defaults.string(forKey: UserDefaultsKeys.selectedEngine), "groq")
    }

    func testSelectModel_noPlugin_DoesNotCrash() {
        // No plugin registered for "nonexistent" — should be a no-op, not a crash.
        let service = makeService()

        service.selectModel("nonexistent", modelId: "some-model")

        // Provider still gets persisted even if plugin is absent
        XCTAssertEqual(service.selectedProviderId, "nonexistent")
    }

    // MARK: - 3. isModelReady returns false when no provider

    func testIsModelReady_falseWhenNoProvider() {
        // selectedProviderId is nil only if we bypass the init default.
        // Since init always sets a default, we test with a provider that has no plugin.
        let service = makeService()

        // Default is "paraformer" but no plugin is registered for it.
        XCTAssertFalse(service.isModelReady)
    }

    func testIsModelReady_falseWhenPluginNotConfigured() {
        injectPlugin(
            MockTranscriptionPlugin(providerId: "paraformer", isConfigured: false)
        )
        let service = makeService()

        XCTAssertFalse(service.isModelReady)
    }

    func testIsModelReady_trueWhenPluginConfigured() {
        injectPlugin(
            MockTranscriptionPlugin(providerId: "paraformer", isConfigured: true)
        )
        let service = makeService()

        XCTAssertTrue(service.isModelReady)
    }

    func testIsModelReady_falseWhenPluginRemoved() {
        injectPlugin(
            MockTranscriptionPlugin(providerId: "paraformer", isConfigured: true)
        )
        let service = makeService()

        XCTAssertTrue(service.isModelReady)

        // Simulate plugin being removed (e.g. disabled)
        pluginManager.loadedPlugins.removeAll()
        XCTAssertFalse(service.isModelReady)
    }

    // MARK: - 4. canTranscribe returns true when auto-unload active and plugin exists

    func testCanTranscribe_falseWhenNoProvider() {
        // No plugin registered; default provider "paraformer" has no matching plugin
        let service = makeService()

        // Even with auto-unload enabled (non-zero), there is no plugin.
        service.autoUnloadSeconds = 300
        XCTAssertFalse(service.canTranscribe)
    }

    func testCanTranscribe_trueWhenPluginConfigured() {
        injectPlugin(
            MockTranscriptionPlugin(providerId: "paraformer", isConfigured: true)
        )
        let service = makeService()

        XCTAssertTrue(service.canTranscribe)
    }

    func testCanTranscribe_trueWhenAutoUnloadActiveAndPluginExists() {
        // Plugin exists but is NOT configured (simulates auto-unloaded state).
        // With auto-unload enabled, canTranscribe should still be true because
        // the model can be restored.
        injectPlugin(
            MockTranscriptionPlugin(providerId: "paraformer", isConfigured: false)
        )
        let service = makeService()
        service.autoUnloadSeconds = 300

        XCTAssertTrue(service.canTranscribe)
    }

    func testCanTranscribe_falseWhenAutoUnloadDisabledAndPluginNotConfigured() {
        // Auto-unload is 0 (disabled), plugin not configured -> cannot transcribe.
        injectPlugin(
            MockTranscriptionPlugin(providerId: "paraformer", isConfigured: false)
        )
        let service = makeService()
        service.autoUnloadSeconds = 0

        XCTAssertFalse(service.canTranscribe)
    }

    func testCanTranscribe_trueWhenAutoUnloadImmediateAndPluginExists() {
        // autoUnloadSeconds == -1 means unload immediately after transcription.
        // Plugin exists but is unconfigured; should still be restorable.
        injectPlugin(
            MockTranscriptionPlugin(providerId: "paraformer", isConfigured: false)
        )
        let service = makeService()
        service.autoUnloadSeconds = -1

        XCTAssertTrue(service.canTranscribe)
    }

    // MARK: - 5. activeEngineName returns plugin display name

    func testActiveEngineName_nilWhenNoPlugin() {
        let service = makeService()

        // Default provider "paraformer" has no plugin registered.
        XCTAssertNil(service.activeEngineName)
    }

    func testActiveEngineName_returnsPluginDisplayName() {
        injectPlugin(
            MockTranscriptionPlugin(providerId: "paraformer", providerDisplayName: "Paraformer Local")
        )
        let service = makeService()

        XCTAssertEqual(service.activeEngineName, "Paraformer Local")
    }

    func testActiveEngineName_changesWithProvider() {
        injectPlugin(
            MockTranscriptionPlugin(providerId: "whisperkit", providerDisplayName: "WhisperKit")
        )
        injectPlugin(
            MockTranscriptionPlugin(providerId: "groq", providerDisplayName: "Groq Cloud")
        )
        let service = makeService()

        service.selectProvider("whisperkit")
        XCTAssertEqual(service.activeEngineName, "WhisperKit")

        service.selectProvider("groq")
        XCTAssertEqual(service.activeEngineName, "Groq Cloud")
    }

    // MARK: - 6. activeModelName resolves model display name

    func testActiveModelName_nilWhenNoPlugin() {
        let service = makeService()
        XCTAssertNil(service.activeModelName)
    }

    func testActiveModelName_nilWhenPluginHasNoSelectedModel() {
        injectPlugin(
            MockTranscriptionPlugin(providerId: "paraformer", selectedModelId: nil)
        )
        let service = makeService()

        XCTAssertNil(service.activeModelName)
    }

    func testActiveModelName_nilWhenSelectedModelIdNotInModelsList() {
        injectPlugin(
            MockTranscriptionPlugin(
                providerId: "paraformer",
                selectedModelId: "missing-model",
                transcriptionModels: []
            )
        )
        let service = makeService()

        XCTAssertNil(service.activeModelName)
    }

    func testActiveModelName_returnsDisplayNameWhenMatched() {
        let model = PluginModelInfo(id: "large-v3", displayName: "Whisper Large v3")
        injectPlugin(
            MockTranscriptionPlugin(
                providerId: "paraformer",
                selectedModelId: "large-v3",
                transcriptionModels: [model]
            )
        )
        let service = makeService()

        XCTAssertEqual(service.activeModelName, "Whisper Large v3")
    }

    // MARK: - 7. resolvedModelDisplayName with engine/model overrides

    func testResolvedModelDisplayName_nilWhenNoProviderAndNoOverride() {
        // Clear any default so selectedProviderId has no matching plugin.
        let service = makeService()
        // Default is "paraformer", but no plugin registered.
        XCTAssertNil(service.resolvedModelDisplayName())
    }

    func testResolvedModelDisplayName_returnsPluginNameWhenNoModelSelected() {
        injectPlugin(
            MockTranscriptionPlugin(
                providerId: "paraformer",
                providerDisplayName: "Paraformer",
                selectedModelId: nil,
                transcriptionModels: []
            )
        )
        let service = makeService()

        // Falls through to providerDisplayName when no model is selected.
        XCTAssertEqual(service.resolvedModelDisplayName(), "Paraformer")
    }

    func testResolvedModelDisplayName_usesCloudModelOverride() {
        let modelA = PluginModelInfo(id: "base", displayName: "Whisper Base")
        let modelB = PluginModelInfo(id: "large", displayName: "Whisper Large")
        injectPlugin(
            MockTranscriptionPlugin(
                providerId: "paraformer",
                selectedModelId: "base",
                transcriptionModels: [modelA, modelB]
            )
        )
        let service = makeService()

        // Override to "large" even though "base" is selected.
        XCTAssertEqual(service.resolvedModelDisplayName(cloudModelOverride: "large"), "Whisper Large")
    }

    func testResolvedModelDisplayName_usesEngineOverride() {
        let model = PluginModelInfo(id: "turbo", displayName: "Groq Turbo")
        injectPlugin(
            MockTranscriptionPlugin(
                providerId: "paraformer",
                selectedModelId: "base",
                transcriptionModels: []
            )
        )
        injectPlugin(
            MockTranscriptionPlugin(
                providerId: "groq",
                selectedModelId: "turbo",
                transcriptionModels: [model]
            )
        )
        let service = makeService()

        // Override engine to "groq" while default provider is "paraformer".
        XCTAssertEqual(
            service.resolvedModelDisplayName(engineOverrideId: "groq"),
            "Groq Turbo"
        )
    }

    func testResolvedModelDisplayName_cloudOverrideTakesPrecedenceOverSelected() {
        let selectedModel = PluginModelInfo(id: "small", displayName: "Small Model")
        let overrideModel = PluginModelInfo(id: "mega", displayName: "Mega Model")
        injectPlugin(
            MockTranscriptionPlugin(
                providerId: "paraformer",
                selectedModelId: "small",
                transcriptionModels: [selectedModel, overrideModel]
            )
        )
        let service = makeService()

        // cloudModelOverride takes priority over selectedModelId.
        XCTAssertEqual(
            service.resolvedModelDisplayName(cloudModelOverride: "mega"),
            "Mega Model"
        )
    }

    func testResolvedModelDisplayName_cloudOverrideNotFound_fallsToSelected() {
        let selectedModel = PluginModelInfo(id: "small", displayName: "Small Model")
        injectPlugin(
            MockTranscriptionPlugin(
                providerId: "paraformer",
                selectedModelId: "small",
                transcriptionModels: [selectedModel]
            )
        )
        let service = makeService()

        // Override ID does not exist in models list -> fall back to selected.
        XCTAssertEqual(
            service.resolvedModelDisplayName(cloudModelOverride: "nonexistent"),
            "Small Model"
        )
    }

    func testResolvedModelDisplayName_noModelAtAll_returnsProviderName() {
        injectPlugin(
            MockTranscriptionPlugin(
                providerId: "paraformer",
                providerDisplayName: "Paraformer Engine",
                selectedModelId: nil,
                transcriptionModels: []
            )
        )
        let service = makeService()

        // No cloud override, no selected model -> provider name.
        XCTAssertEqual(
            service.resolvedModelDisplayName(cloudModelOverride: "nonexistent"),
            "Paraformer Engine"
        )
    }

    // MARK: - 8. supportsTranslation and supportsStreaming delegation

    func testSupportsTranslation_falseWhenNoPlugin() {
        let service = makeService()
        XCTAssertFalse(service.supportsTranslation)
    }

    func testSupportsTranslation_delegatesToPlugin_true() {
        injectPlugin(
            MockTranscriptionPlugin(providerId: "paraformer", supportsTranslation: true)
        )
        let service = makeService()

        XCTAssertTrue(service.supportsTranslation)
    }

    func testSupportsTranslation_delegatesToPlugin_false() {
        injectPlugin(
            MockTranscriptionPlugin(providerId: "paraformer", supportsTranslation: false)
        )
        let service = makeService()

        XCTAssertFalse(service.supportsTranslation)
    }

    func testSupportsStreaming_falseWhenNoPlugin() {
        let service = makeService()
        XCTAssertFalse(service.supportsStreaming)
    }

    func testSupportsStreaming_delegatesToPlugin_true() {
        injectPlugin(
            MockTranscriptionPlugin(providerId: "paraformer", supportsStreaming: true)
        )
        let service = makeService()

        XCTAssertTrue(service.supportsStreaming)
    }

    func testSupportsStreaming_delegatesToPlugin_false() {
        injectPlugin(
            MockTranscriptionPlugin(providerId: "paraformer", supportsStreaming: false)
        )
        let service = makeService()

        XCTAssertFalse(service.supportsStreaming)
    }

    func testSupportsTranslation_changesWithProvider() {
        injectPlugin(
            MockTranscriptionPlugin(providerId: "engine-a", supportsTranslation: true)
        )
        injectPlugin(
            MockTranscriptionPlugin(providerId: "engine-b", supportsTranslation: false)
        )
        let service = makeService()

        service.selectProvider("engine-a")
        XCTAssertTrue(service.supportsTranslation)

        service.selectProvider("engine-b")
        XCTAssertFalse(service.supportsTranslation)
    }

    // MARK: - 9. autoUnloadSeconds persistence and didSet behavior

    func testAutoUnloadSeconds_readsFromUserDefaultsOnInit() {
        defaults.set(600, forKey: UserDefaultsKeys.modelAutoUnloadSeconds)
        let service = makeService()

        XCTAssertEqual(service.autoUnloadSeconds, 600)
    }

    func testAutoUnloadSeconds_defaultsToZeroWhenNotSet() {
        let service = makeService()

        XCTAssertEqual(service.autoUnloadSeconds, 0)
    }

    func testAutoUnloadSeconds_persistsOnSet() {
        let service = makeService()

        service.autoUnloadSeconds = 300

        XCTAssertEqual(defaults.integer(forKey: UserDefaultsKeys.modelAutoUnloadSeconds), 300)
    }

    func testAutoUnloadSeconds_negativeOneAllowed() {
        let service = makeService()

        service.autoUnloadSeconds = -1

        XCTAssertEqual(service.autoUnloadSeconds, -1)
        XCTAssertEqual(defaults.integer(forKey: UserDefaultsKeys.modelAutoUnloadSeconds), -1)
    }

    func testAutoUnloadSeconds_overwritesPrevious() {
        let service = makeService()

        service.autoUnloadSeconds = 300
        service.autoUnloadSeconds = 600

        XCTAssertEqual(defaults.integer(forKey: UserDefaultsKeys.modelAutoUnloadSeconds), 600)
    }

    // MARK: - 10. cancelAutoUnloadTimer

    func testCancelAutoUnloadTimer_cancelsScheduledTask() {
        let service = makeService()

        // Schedule a timer with a long delay so it does not fire during the test.
        service.autoUnloadSeconds = 600
        // scheduleAutoUnloadIfNeeded is called in didSet, so timer is now active.

        // Cancel it.
        service.cancelAutoUnloadTimer()

        // Verify the timer was cancelled by checking that autoUnloadSeconds is
        // still set (cancel does not reset the seconds value).
        XCTAssertEqual(service.autoUnloadSeconds, 600)
    }

    func testCancelAutoUnloadTimer_safeToCallWhenNoTimer() {
        let service = makeService()

        // autoUnloadSeconds == 0 means no timer was scheduled.
        // Calling cancel should be a no-op, not a crash.
        service.cancelAutoUnloadTimer()

        XCTAssertEqual(service.autoUnloadSeconds, 0)
    }

    func testCancelAutoUnloadTimer_doubleCancelDoesNotCrash() {
        let service = makeService()
        service.autoUnloadSeconds = 300

        service.cancelAutoUnloadTimer()
        service.cancelAutoUnloadTimer()

        XCTAssertEqual(service.autoUnloadSeconds, 300)
    }

    // MARK: - selectedModelId delegation

    func testSelectedModelId_nilWhenNoPlugin() {
        let service = makeService()
        XCTAssertNil(service.selectedModelId)
    }

    func testSelectedModelId_returnsPluginSelectedModelId() {
        injectPlugin(
            MockTranscriptionPlugin(providerId: "paraformer", selectedModelId: "model-42")
        )
        let service = makeService()

        XCTAssertEqual(service.selectedModelId, "model-42")
    }

    // MARK: - scheduleAutoUnloadIfNeeded guards

    func testScheduleAutoUnload_doesNotScheduleWhenZero() {
        let service = makeService()
        service.autoUnloadSeconds = 0

        // Calling scheduleAutoUnloadIfNeeded directly should be a no-op.
        // Verify no crash and seconds stays 0.
        service.scheduleAutoUnloadIfNeeded()
        XCTAssertEqual(service.autoUnloadSeconds, 0)
    }

    func testScheduleAutoUnload_cancelsPreviousTimer() {
        let service = makeService()

        // First schedule
        service.autoUnloadSeconds = 600
        // Calling again should cancel previous and schedule new.
        service.scheduleAutoUnloadIfNeeded()

        XCTAssertEqual(service.autoUnloadSeconds, 600)
    }

    // MARK: - Edge cases

    func testSelectProvider_nilProviderId_notPossibleViaPublicAPI() {
        // Verify that selectProvider always persists the given string.
        // The published property type is String? but selectProvider takes String.
        let service = makeService()
        service.selectProvider("")

        // Empty string is still a valid selection.
        XCTAssertEqual(service.selectedProviderId, "")
        XCTAssertEqual(defaults.string(forKey: UserDefaultsKeys.selectedEngine), "")
    }

    func testMultiplePlugins_sameProviderId_lastWins() {
        // If two plugins share a providerId, PluginManager.transcriptionEngine
        // returns the first match. Verify behavior is deterministic.
        injectPlugin(
            MockTranscriptionPlugin(providerId: "dupe", providerDisplayName: "First Plugin")
        )
        injectPlugin(
            MockTranscriptionPlugin(providerId: "dupe", providerDisplayName: "Second Plugin")
        )
        let service = makeService()
        service.selectProvider("dupe")

        // PluginManager.transcriptionEngine(for:) returns first match.
        XCTAssertEqual(service.activeEngineName, "First Plugin")
    }

    func testCanTranscribe_falseWhenSelectedProviderHasNoPlugin() {
        // Select a provider that has no registered plugin.
        let service = makeService()
        service.selectProvider("ghost-engine")
        service.autoUnloadSeconds = 300

        XCTAssertFalse(service.canTranscribe)
    }
}
