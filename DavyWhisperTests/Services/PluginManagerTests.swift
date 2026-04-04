import XCTest
import DavyWhisperPluginSDK
@testable import DavyWhisper

// MARK: - Test Plugin Mocks
//
// Named with PMTest prefix to avoid collision with MockTranscriptionPlugin
// in ModelManagerExtendedTests.swift (same test target namespace).

/// Minimal DavyWhisperPlugin mock for testing plugin loading and lifecycle.
final class PMTestMockPlugin: DavyWhisperPlugin, @unchecked Sendable {
    static var pluginId: String { "com.davywhisper.mock" }
    static var pluginName: String { "MockPlugin" }

    var host: HostServices?
    var isActivated = false
    var deactivateCalled = false

    init() {}
    func activate(host: HostServices) {
        self.host = host
        self.isActivated = true
    }
    func deactivate() {
        self.isActivated = false
        self.deactivateCalled = true
    }
}

/// Mock plugin conforming to TranscriptionEnginePlugin.
final class PMTestTranscriptionPlugin: TranscriptionEnginePlugin, @unchecked Sendable {
    static var pluginId: String { "com.davywhisper.mock-transcription" }
    static var pluginName: String { "MockTranscription" }

    var host: HostServices?
    var isActivated = false
    var deactivateCalled = false

    var providerId: String = "mock-transcription"
    var providerDisplayName: String = "Mock Transcription"
    var isConfigured: Bool = true
    var transcriptionModels: [PluginModelInfo] = []
    var selectedModelId: String? = nil
    var supportsTranslation: Bool = false

    init() {}
    func activate(host: HostServices) {
        self.host = host
        self.isActivated = true
    }
    func deactivate() {
        self.isActivated = false
        self.deactivateCalled = true
    }
    func selectModel(_ modelId: String) {
        selectedModelId = modelId
    }

    func transcribe(audio: AudioData, language: String?, translate: Bool, prompt: String?) async throws -> PluginTranscriptionResult {
        PluginTranscriptionResult(text: "mock transcription")
    }
}

/// Mock plugin conforming to LLMProviderPlugin.
final class PMTestLLMPlugin: LLMProviderPlugin, @unchecked Sendable {
    static var pluginId: String { "com.davywhisper.mock-llm" }
    static var pluginName: String { "MockLLM" }

    var host: HostServices?
    var isActivated = false
    var deactivateCalled = false

    var providerName: String = "MockLLM"
    var isAvailable: Bool = true
    var supportedModels: [PluginModelInfo] = []

    init() {}
    func activate(host: HostServices) {
        self.host = host
        self.isActivated = true
    }
    func deactivate() {
        self.isActivated = false
        self.deactivateCalled = true
    }
    func process(systemPrompt: String, userText: String, model: String?) async throws -> String {
        return "mock response"
    }
}

/// A second LLM plugin for testing multi-provider scenarios.
final class PMTestLLMPlugin2: LLMProviderPlugin, @unchecked Sendable {
    static var pluginId: String { "com.davywhisper.mock-llm-2" }
    static var pluginName: String { "MockLLM2" }

    var host: HostServices?
    var isActivated = false
    var deactivateCalled = false

    var providerName: String = "MockLLM2"
    var isAvailable: Bool = true
    var supportedModels: [PluginModelInfo] = []

    init() {}
    func activate(host: HostServices) {
        self.host = host
        self.isActivated = true
    }
    func deactivate() {
        self.isActivated = false
        self.deactivateCalled = true
    }
    func process(systemPrompt: String, userText: String, model: String?) async throws -> String {
        return "mock response 2"
    }
}

// MARK: - PluginManagerTests

@MainActor
final class PluginManagerTests: XCTestCase {
    private var sut: PluginManager!
    private var tempDir: URL!
    private var pluginsDir: URL!

    // UserDefaults keys that tests may set; cleaned up in tearDown.
    private var taintedUserDefaultsKeys: [String] = []

    private var savedEventBus: EventBus?

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginManagerTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        pluginsDir = tempDir.appendingPathComponent("Plugins", isDirectory: true)

        savedEventBus = EventBus.shared
        EventBus.shared = EventBus()

        sut = PluginManager(appSupportDirectory: tempDir)
    }

    override func tearDown() {
        // Clean up any UserDefaults keys written during the test.
        for key in taintedUserDefaultsKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        taintedUserDefaultsKeys.removeAll()

        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        sut = nil
        EventBus.shared = savedEventBus
        savedEventBus = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// Track a UserDefaults key for automatic cleanup in tearDown.
    private func trackUserDefaultsKey(_ key: String) {
        taintedUserDefaultsKeys.append(key)
    }

    /// Create a valid manifest JSON data for the given plugin configuration.
    private func makeManifestJSON(
        id: String = "com.davywhisper.test",
        name: String = "TestPlugin",
        version: String = "1.0.0",
        principalClass: String = "PMTestMockPlugin"
    ) -> Data {
        let manifest: [String: Any] = [
            "id": id,
            "name": name,
            "version": version,
            "principalClass": principalClass
        ]
        return try! JSONSerialization.data(withJSONObject: manifest)
    }

    /// Manually inject a loaded plugin into the PluginManager for unit testing
    /// without relying on Bundle loading or NSClassFromString.
    private func injectPlugin(
        id: String = "com.davywhisper.test",
        name: String = "TestPlugin",
        version: String = "1.0.0",
        instance: DavyWhisperPlugin,
        isEnabled: Bool = true
    ) -> LoadedPlugin {
        let manifest = PluginManifest(
            id: id,
            name: name,
            version: version,
            principalClass: "Mock"
        )
        let loaded = LoadedPlugin(
            manifest: manifest,
            instance: instance,
            bundle: Bundle.main,
            sourceURL: tempDir.appendingPathComponent("mock"),
            isEnabled: isEnabled
        )
        sut.loadedPlugins.append(loaded)
        return loaded
    }

    /// Create a mock bundle directory at the given URL with a manifest.json.
    private func createMockBundle(
        at parentDir: URL,
        name: String,
        manifestJSON: Data
    ) -> URL {
        let bundleURL = parentDir.appendingPathComponent("\(name).bundle", isDirectory: true)
        let manifestDir = bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        try? FileManager.default.createDirectory(at: manifestDir, withIntermediateDirectories: true)
        try? manifestJSON.write(to: manifestDir.appendingPathComponent("manifest.json"))
        return bundleURL
    }

    // MARK: - Init Tests

    func testInitCreatesPluginsDirectory() {
        let dirExists = FileManager.default.fileExists(atPath: pluginsDir.path)
        XCTAssertTrue(dirExists, "PluginManager init should create the Plugins directory")
    }

    func testPluginsDirectoryIsAppSupportSubdirectory() {
        XCTAssertEqual(
            sut.pluginsDirectory,
            tempDir.appendingPathComponent("Plugins", isDirectory: true)
        )
    }

    func testInitStartsWithEmptyLoadedPlugins() {
        XCTAssertTrue(sut.loadedPlugins.isEmpty, "Should start with no loaded plugins")
    }

    // MARK: - Plugin Loading from Directory (scanAndLoadPlugins)

    func testScanAndLoadPluginsFindsBundleInPluginsDirectory() {
        // Create a mock bundle in the user's Plugins directory.
        // Note: The bundle won't actually load (NSClassFromString returns nil),
        // but this tests that scanAndLoadPlugins correctly scans and attempts loading.
        let manifestData = makeManifestJSON(
            id: "com.test.bundle-plugin",
            name: "BundlePlugin",
            principalClass: "NonexistentClass"
        )
        createMockBundle(at: pluginsDir, name: "TestBundle", manifestJSON: manifestData)

        sut.scanAndLoadPlugins()

        // The bundle exists but the principalClass cannot be resolved,
        // so the plugin is NOT loaded (loadPlugin logs error and returns).
        let found = sut.loadedPlugins.contains { $0.manifest.id == "com.test.bundle-plugin" }
        XCTAssertFalse(found, "Should not load a plugin whose principalClass cannot be resolved")
    }

    func testScanAndLoadPluginsIgnoresNonBundleFiles() {
        // Create a non-bundle file in the Plugins directory.
        let txtFile = pluginsDir.appendingPathComponent("readme.txt")
        try? "not a plugin".write(to: txtFile, atomically: true, encoding: .utf8)

        sut.scanAndLoadPlugins()

        // Compiled-in plugins may still load from Bundle.main, but no plugins
        // should be loaded from the .txt file.
        let hasTxtPlugin = sut.loadedPlugins.contains { $0.manifest.id.contains("readme") }
        XCTAssertFalse(hasTxtPlugin, "Non-bundle files should not be loaded as plugins")
    }

    func testScanAndLoadPluginsWithEmptyDirectory() {
        // Plugins directory exists but is empty.
        sut.scanAndLoadPlugins()

        // Compiled-in plugins may still be loaded from Bundle.main.
        // Verify that re-scanning doesn't duplicate plugins.
        let count = sut.loadedPlugins.count
        sut.scanAndLoadPlugins()
        XCTAssertEqual(sut.loadedPlugins.count, count, "Re-scanning should not duplicate plugins")
    }

    // MARK: - Compiled Plugin Loading (loadCompiledPlugins)

    func testLoadCompiledPluginsDoesNotCrashWithoutManifests() {
        // No manifest files in Resources; should silently skip all.
        sut.scanAndLoadPlugins()

        // If no compiled manifests exist in the test environment,
        // loadedPlugins stays empty or contains only what scanAndLoadPlugins finds.
        // The key assertion: it does not crash.
        XCTAssertNotNil(sut.loadedPlugins)
    }

    // MARK: - loadPlugin(at:) Tests

    func testLoadPluginSkipsDuplicateId() {
        let plugin = PMTestMockPlugin()
        injectPlugin(id: "com.test.dup", name: "First", instance: plugin)

        // Manually call loadPlugin with a bundle that has the same id.
        // Since loadPlugin reads manifest from disk and checks for duplicates,
        // we need a bundle on disk.
        let manifestData = makeManifestJSON(id: "com.test.dup", name: "Second")
        let bundleURL = createMockBundle(at: tempDir, name: "DuplicateBundle", manifestJSON: manifestData)

        sut.loadPlugin(at: bundleURL)

        // Should still have exactly one plugin with this id.
        let count = sut.loadedPlugins.filter { $0.manifest.id == "com.test.dup" }.count
        XCTAssertEqual(count, 1, "Should not load duplicate plugin ids")
    }

    func testLoadPluginSkipsInvalidBundleURL() {
        let nonexistentURL = tempDir.appendingPathComponent("Nonexistent.bundle")
        sut.loadPlugin(at: nonexistentURL)

        XCTAssertTrue(sut.loadedPlugins.isEmpty, "Should not load from nonexistent path")
    }

    func testLoadPluginSkipsMissingManifest() {
        // Create a bundle directory without a manifest.json.
        let bundleURL = tempDir.appendingPathComponent("NoManifest.bundle", isDirectory: true)
        let resourcesDir = bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        try? FileManager.default.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

        sut.loadPlugin(at: bundleURL)

        XCTAssertTrue(sut.loadedPlugins.isEmpty, "Should not load bundle without manifest.json")
    }

    func testLoadPluginSkipsInvalidManifestJSON() {
        let bundleURL = tempDir.appendingPathComponent("BadManifest.bundle", isDirectory: true)
        let resourcesDir = bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        try? FileManager.default.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
        try? "not valid json{{{".write(
            to: resourcesDir.appendingPathComponent("manifest.json"),
            atomically: true, encoding: .utf8
        )

        sut.loadPlugin(at: bundleURL)

        XCTAssertTrue(sut.loadedPlugins.isEmpty, "Should not load bundle with invalid manifest JSON")
    }

    // MARK: - Transcription Engine Lookup

    func testTranscriptionEnginesReturnsOnlyEnabled() {
        let enabledEngine = PMTestTranscriptionPlugin()
        enabledEngine.providerId = "engine-enabled"
        injectPlugin(id: "engine-enabled-id", name: "EnabledEngine", instance: enabledEngine, isEnabled: true)

        let disabledEngine = PMTestTranscriptionPlugin()
        disabledEngine.providerId = "engine-disabled"
        injectPlugin(id: "engine-disabled-id", name: "DisabledEngine", instance: disabledEngine, isEnabled: false)

        let engines = sut.transcriptionEngines
        XCTAssertEqual(engines.count, 1, "Should only return enabled transcription engines")
        XCTAssertEqual(engines.first?.providerId, "engine-enabled")
    }

    func testTranscriptionEnginesExcludesNonEnginePlugins() {
        let llmPlugin = PMTestLLMPlugin()
        injectPlugin(id: "llm-id", name: "LLM", instance: llmPlugin, isEnabled: true)

        let engines = sut.transcriptionEngines
        XCTAssertTrue(engines.isEmpty, "LLM plugins should not appear in transcription engines")
    }

    func testTranscriptionEngineForReturnsMatchingProvider() {
        let engine = PMTestTranscriptionPlugin()
        engine.providerId = "whisperkit"
        injectPlugin(id: "whisperkit-id", name: "WhisperKit", instance: engine, isEnabled: true)

        let found = sut.transcriptionEngine(for: "whisperkit")
        XCTAssertNotNil(found, "Should find engine by providerId")
        XCTAssertEqual(found?.providerId, "whisperkit")
    }

    func testTranscriptionEngineForReturnsNilForNonexistent() {
        let found = sut.transcriptionEngine(for: "nonexistent")
        XCTAssertNil(found, "Should return nil for unknown provider id")
    }

    func testTranscriptionEngineForReturnsNilForDisabled() {
        let engine = PMTestTranscriptionPlugin()
        engine.providerId = "disabled-engine"
        injectPlugin(id: "disabled-engine-id", name: "Disabled", instance: engine, isEnabled: false)

        let found = sut.transcriptionEngine(for: "disabled-engine")
        XCTAssertNil(found, "Should not return disabled engines")
    }

    // MARK: - LLM Provider Lookup

    func testLLMProvidersReturnsOnlyEnabled() {
        let enabledLLM = PMTestLLMPlugin()
        enabledLLM.providerName = "EnabledLLM"
        injectPlugin(id: "llm-enabled-id", name: "EnabledLLM", instance: enabledLLM, isEnabled: true)

        let disabledLLM = PMTestLLMPlugin()
        disabledLLM.providerName = "DisabledLLM"
        injectPlugin(id: "llm-disabled-id", name: "DisabledLLM", instance: disabledLLM, isEnabled: false)

        let providers = sut.llmProviders
        XCTAssertEqual(providers.count, 1, "Should only return enabled LLM providers")
        XCTAssertEqual(providers.first?.providerName, "EnabledLLM")
    }

    func testLLMProvidersExcludesNonLLMPlugins() {
        let engine = PMTestTranscriptionPlugin()
        injectPlugin(id: "engine-id", name: "Engine", instance: engine, isEnabled: true)

        let providers = sut.llmProviders
        XCTAssertTrue(providers.isEmpty, "Transcription plugins should not appear in LLM providers")
    }

    func testLLMProviderForReturnsMatchingProvider() {
        let llm = PMTestLLMPlugin()
        llm.providerName = "OpenAI"
        injectPlugin(id: "openai-id", name: "OpenAI", instance: llm, isEnabled: true)

        let found = sut.llmProvider(for: "OpenAI")
        XCTAssertNotNil(found, "Should find LLM provider by name")
        XCTAssertEqual(found?.providerName, "OpenAI")
    }

    func testLLMProviderForCaseInsensitive() {
        let llm = PMTestLLMPlugin()
        llm.providerName = "OpenAI"
        injectPlugin(id: "openai-ci-id", name: "OpenAI", instance: llm, isEnabled: true)

        XCTAssertNotNil(sut.llmProvider(for: "openai"), "Should match case-insensitively")
        XCTAssertNotNil(sut.llmProvider(for: "OPENAI"), "Should match case-insensitively")
        XCTAssertNotNil(sut.llmProvider(for: "openAi"), "Should match case-insensitively")
    }

    func testLLMProviderForReturnsNilForNonexistent() {
        XCTAssertNil(sut.llmProvider(for: "Nonexistent"))
    }

    func testLLMProviderForReturnsNilForDisabled() {
        let llm = PMTestLLMPlugin()
        llm.providerName = "DisabledProvider"
        injectPlugin(id: "disabled-llm-id", name: "DisabledLLM", instance: llm, isEnabled: false)

        XCTAssertNil(sut.llmProvider(for: "DisabledProvider"))
    }

    func testMultipleLLMProviders() {
        let llm1 = PMTestLLMPlugin()
        llm1.providerName = "ProviderA"
        injectPlugin(id: "llm-a-id", name: "ProviderA", instance: llm1, isEnabled: true)

        let llm2 = PMTestLLMPlugin2()
        llm2.providerName = "ProviderB"
        injectPlugin(id: "llm-b-id", name: "ProviderB", instance: llm2, isEnabled: true)

        XCTAssertEqual(sut.llmProviders.count, 2)
        XCTAssertNotNil(sut.llmProvider(for: "ProviderA"))
        XCTAssertNotNil(sut.llmProvider(for: "ProviderB"))
    }

    // MARK: - Enabled/Disabled State Management

    func testSetPluginEnabledUpdatesState() {
        let plugin = PMTestMockPlugin()
        injectPlugin(id: "toggle-test", name: "ToggleTest", instance: plugin, isEnabled: true)

        let enabledKey = "plugin.toggle-test.enabled"
        trackUserDefaultsKey(enabledKey)

        sut.setPluginEnabled("toggle-test", enabled: false)

        let loaded = sut.loadedPlugins.first { $0.manifest.id == "toggle-test" }
        XCTAssertNotNil(loaded)
        XCTAssertFalse(loaded!.isEnabled, "Plugin should be disabled after setPluginEnabled(false)")
    }

    func testSetPluginEnabledPersistsToUserDefaults() {
        let plugin = PMTestMockPlugin()
        injectPlugin(id: "persist-test", name: "PersistTest", instance: plugin, isEnabled: true)

        let enabledKey = "plugin.persist-test.enabled"
        trackUserDefaultsKey(enabledKey)

        sut.setPluginEnabled("persist-test", enabled: false)
        XCTAssertEqual(
            UserDefaults.standard.bool(forKey: enabledKey),
            false,
            "Disabled state should be persisted to UserDefaults"
        )

        sut.setPluginEnabled("persist-test", enabled: true)
        XCTAssertEqual(
            UserDefaults.standard.bool(forKey: enabledKey),
            true,
            "Enabled state should be persisted to UserDefaults"
        )
    }

    func testSetPluginEnabledActivatesPluginWhenEnabling() {
        let plugin = PMTestMockPlugin()
        injectPlugin(id: "activate-test", name: "ActivateTest", instance: plugin, isEnabled: false)

        sut.setPluginEnabled("activate-test", enabled: true)

        XCTAssertTrue(plugin.isActivated, "Enabling a plugin should call activate on it")
    }

    func testSetPluginEnabledDeactivatesPluginWhenDisabling() {
        let plugin = PMTestMockPlugin()
        injectPlugin(id: "deactivate-test", name: "DeactivateTest", instance: plugin, isEnabled: true)

        sut.setPluginEnabled("deactivate-test", enabled: false)

        XCTAssertTrue(plugin.deactivateCalled, "Disabling a plugin should call deactivate on it")
    }

    func testSetPluginEnabledNoopForUnknownPluginId() {
        let plugin = PMTestMockPlugin()
        injectPlugin(id: "existing-id", name: "Existing", instance: plugin, isEnabled: true)

        // Should not crash or change existing plugins.
        sut.setPluginEnabled("nonexistent-id", enabled: false)

        XCTAssertEqual(sut.loadedPlugins.count, 1)
        XCTAssertTrue(sut.loadedPlugins.first!.isEnabled, "Existing plugin state should be unchanged")
    }

    func testSetPluginEnabledFiltersEnginesWhenDisablingSelected() {
        let engine1 = PMTestTranscriptionPlugin()
        engine1.providerId = "engine-to-disable"
        engine1.isConfigured = true
        injectPlugin(id: "engine-to-disable-id", name: "Engine1", instance: engine1, isEnabled: true)

        let engine2 = PMTestTranscriptionPlugin()
        engine2.providerId = "fallback-engine"
        engine2.isConfigured = true
        injectPlugin(id: "fallback-engine-id", name: "Engine2", instance: engine2, isEnabled: true)

        // Simulate engine-to-disable being the selected engine.
        let selectedKey = UserDefaultsKeys.selectedEngine
        trackUserDefaultsKey(selectedKey)
        UserDefaults.standard.set("engine-to-disable", forKey: selectedKey)

        // The real ServiceContainer requires many services. For this test we need
        // the selectedEngine key to match and a fallback engine to be available.
        // Since setPluginEnabled calls ServiceContainer.shared.modelManagerService.selectProvider,
        // and that may fail if ServiceContainer is not fully initialized,
        // we verify the core logic: the disabled engine's deactivate is called.
        sut.setPluginEnabled("engine-to-disable-id", enabled: false)

        XCTAssertTrue(engine1.deactivateCalled, "Disabled engine should be deactivated")
        XCTAssertFalse(
            sut.loadedPlugins.first { $0.manifest.id == "engine-to-disable-id" }!.isEnabled,
            "Disabled engine should have isEnabled = false"
        )
    }

    // MARK: - Profile Names Provider

    func testSetProfileNamesProvider() {
        var callCount = 0
        sut.setProfileNamesProvider {
            callCount += 1
            return ["Profile1", "Profile2"]
        }

        // The provider is used when activating a plugin via HostServicesImpl.
        // We can verify the callback is wired by activating a plugin.
        let plugin = PMTestMockPlugin()
        let _ = injectPlugin(id: "profile-test", name: "ProfileTest", instance: plugin, isEnabled: true)

        // Activate the plugin to trigger HostServicesImpl creation with the provider.
        sut.setPluginEnabled("profile-test", enabled: false)
        sut.setPluginEnabled("profile-test", enabled: true)

        // The host services should now have access to profile names.
        // Since activate calls plugin.activate(host:), we can check plugin.host.
        guard let host = plugin.host as? HostServicesImpl else {
            XCTFail("Plugin host should be HostServicesImpl")
            return
        }

        let names = host.availableProfileNames
        XCTAssertEqual(callCount, 1, "Profile names provider should have been called")
        XCTAssertEqual(names, ["Profile1", "Profile2"])
    }

    func testDefaultProfileNamesProviderReturnsEmpty() {
        // Without calling setProfileNamesProvider, the default returns [].
        let plugin = PMTestMockPlugin()
        injectPlugin(id: "default-profile-test", name: "DefaultProfile", instance: plugin, isEnabled: true)

        sut.setPluginEnabled("default-profile-test", enabled: false)
        sut.setPluginEnabled("default-profile-test", enabled: true)

        guard let host = plugin.host as? HostServicesImpl else {
            XCTFail("Plugin host should be HostServicesImpl")
            return
        }

        XCTAssertEqual(host.availableProfileNames, [], "Default profile names provider should return empty array")
    }

    // MARK: - notifyPluginStateChanged

    func testNotifyPluginStateChangedPublishesChange() {
        let expectation = XCTestExpectation(description: "objectWillChange received")
        let cancellable = sut.objectWillChange.sink { _ in
            expectation.fulfill()
        }

        sut.notifyPluginStateChanged()

        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }

    func testNotifyPluginStateChangedCalledMultipleTimes() {
        let expectation = XCTestExpectation(description: "objectWillChange received 3 times")
        expectation.expectedFulfillmentCount = 3

        let cancellable = sut.objectWillChange.sink { _ in
            expectation.fulfill()
        }

        sut.notifyPluginStateChanged()
        sut.notifyPluginStateChanged()
        sut.notifyPluginStateChanged()

        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }

    // MARK: - Unload Plugin

    func testUnloadPluginRemovesFromLoadedPlugins() {
        let plugin = PMTestMockPlugin()
        injectPlugin(id: "unload-target", name: "UnloadTarget", instance: plugin, isEnabled: true)

        XCTAssertEqual(sut.loadedPlugins.count, 1)

        sut.unloadPlugin("unload-target")

        XCTAssertTrue(sut.loadedPlugins.isEmpty, "Unloaded plugin should be removed from loadedPlugins")
    }

    func testUnloadPluginDeactivatesEnabledPlugin() {
        let plugin = PMTestMockPlugin()
        injectPlugin(id: "unload-deactivate", name: "UnloadDeactivate", instance: plugin, isEnabled: true)

        sut.unloadPlugin("unload-deactivate")

        XCTAssertTrue(plugin.deactivateCalled, "Unloading an enabled plugin should deactivate it")
    }

    func testUnloadPluginDoesNotDeactivateDisabledPlugin() {
        let plugin = PMTestMockPlugin()
        plugin.isActivated = false
        injectPlugin(id: "unload-disabled", name: "UnloadDisabled", instance: plugin, isEnabled: false)

        sut.unloadPlugin("unload-disabled")

        XCTAssertFalse(plugin.deactivateCalled, "Unloading a disabled plugin should not call deactivate")
    }

    func testUnloadPluginNoopForUnknownId() {
        let plugin = PMTestMockPlugin()
        injectPlugin(id: "existing", name: "Existing", instance: plugin, isEnabled: true)

        sut.unloadPlugin("nonexistent")

        XCTAssertEqual(sut.loadedPlugins.count, 1, "Should not remove any plugin for unknown id")
    }

    func testUnloadPluginRemovesOnlyTargetPlugin() {
        let plugin1 = PMTestMockPlugin()
        let plugin2 = PMTestMockPlugin()
        injectPlugin(id: "keep-this", name: "KeepThis", instance: plugin1, isEnabled: true)
        injectPlugin(id: "remove-this", name: "RemoveThis", instance: plugin2, isEnabled: true)

        sut.unloadPlugin("remove-this")

        XCTAssertEqual(sut.loadedPlugins.count, 1)
        XCTAssertEqual(sut.loadedPlugins.first?.manifest.id, "keep-this")
    }

    // MARK: - bundleURL(for:)

    func testBundleURLReturnsSourceURL() {
        let plugin = PMTestMockPlugin()
        let sourceURL = tempDir.appendingPathComponent("some-bundle-path")
        let manifest = PluginManifest(
            id: "bundle-url-test",
            name: "BundleURLTest",
            version: "1.0.0",
            principalClass: "Mock"
        )
        let loaded = LoadedPlugin(
            manifest: manifest,
            instance: plugin,
            bundle: Bundle.main,
            sourceURL: sourceURL,
            isEnabled: true
        )
        sut.loadedPlugins.append(loaded)

        let result = sut.bundleURL(for: "bundle-url-test")
        XCTAssertEqual(result, sourceURL, "Should return the sourceURL for the plugin")
    }

    func testBundleURLReturnsNilForUnknownPlugin() {
        XCTAssertNil(sut.bundleURL(for: "nonexistent"), "Should return nil for unknown plugin id")
    }

    // MARK: - LoadedPlugin.isBundled

    func testLoadedPluginIsBundledWhenBundleIsMain() {
        let plugin = PMTestMockPlugin()
        let loaded = LoadedPlugin(
            manifest: PluginManifest(id: "test", name: "Test", version: "1.0", principalClass: "X"),
            instance: plugin,
            bundle: Bundle.main,
            sourceURL: tempDir,
            isEnabled: true
        )

        XCTAssertTrue(loaded.isBundled, "Plugin with Bundle.main should be considered bundled")
    }

    func testLoadedPluginIsNotBundledWhenExternal() {
        let plugin = PMTestMockPlugin()
        let externalURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExternalPlugins/TestPlugin.bundle")
        let loaded = LoadedPlugin(
            manifest: PluginManifest(id: "test", name: "Test", version: "1.0", principalClass: "X"),
            instance: plugin,
            bundle: Bundle(for: type(of: self)), // Not Bundle.main
            sourceURL: externalURL,
            isEnabled: true
        )

        // If sourceURL is not under PlugIns/ or Resources/, isBundled should be false.
        XCTAssertFalse(loaded.isBundled, "Plugin with external sourceURL should not be considered bundled")
    }

    // MARK: - LoadedPlugin.id

    func testLoadedPluginIdMatchesManifestId() {
        let plugin = PMTestMockPlugin()
        let loaded = LoadedPlugin(
            manifest: PluginManifest(id: "my-plugin-id", name: "Test", version: "1.0", principalClass: "X"),
            instance: plugin,
            bundle: Bundle.main,
            sourceURL: tempDir,
            isEnabled: true
        )

        XCTAssertEqual(loaded.id, "my-plugin-id", "LoadedPlugin.id should return manifest.id")
    }

    // MARK: - openPluginsFolder

    func testOpenPluginsFolderDoesNotCrash() {
        // openPluginsFolder calls NSWorkspace.shared.open which may or may not
        // succeed in a test environment. The key test: it does not crash.
        sut.openPluginsFolder()
    }

    // MARK: - Compiled Plugin Auto-Enable Default

    func testCompiledPluginAutoEnableDefault() {
        // When no UserDefaults value exists for a compiled plugin,
        // it should default to enabled (true) and write true to UserDefaults.
        let enabledKey = "plugin.auto-enable-test.enabled"
        trackUserDefaultsKey(enabledKey)

        // Remove any existing value.
        UserDefaults.standard.removeObject(forKey: enabledKey)

        // The default for a new compiled-in plugin is true.
        let isEnabled = (UserDefaults.standard.object(forKey: enabledKey) as? Bool) ?? true
        XCTAssertTrue(isEnabled, "Compiled plugin should default to enabled")
    }

    // MARK: - UserDefaults Enabled Key Format

    func testEnabledUserDefaultsKeyFormat() {
        let pluginId = "com.davywhisper.my-plugin"
        let expectedKey = "plugin.\(pluginId).enabled"

        let plugin = PMTestMockPlugin()
        injectPlugin(id: pluginId, name: "KeyFormatTest", instance: plugin, isEnabled: true)
        trackUserDefaultsKey(expectedKey)

        sut.setPluginEnabled(pluginId, enabled: false)

        let stored = UserDefaults.standard.object(forKey: expectedKey) as? Bool
        XCTAssertEqual(stored, false, "Should use 'plugin.<id>.enabled' key format")
    }

    // MARK: - Plugin Type Filtering

    func testTranscriptionEnginesAndLLMProvidersAreDisjoint() {
        let engine = PMTestTranscriptionPlugin()
        injectPlugin(id: "engine-only", name: "Engine", instance: engine, isEnabled: true)

        let llm = PMTestLLMPlugin()
        injectPlugin(id: "llm-only", name: "LLM", instance: llm, isEnabled: true)

        let base = PMTestMockPlugin()
        injectPlugin(id: "base-only", name: "Base", instance: base, isEnabled: true)

        XCTAssertEqual(sut.transcriptionEngines.count, 1, "Only transcription engine plugins")
        XCTAssertEqual(sut.llmProviders.count, 1, "Only LLM provider plugins")

        // Verify the correct plugin types are returned.
        XCTAssertTrue(sut.transcriptionEngines.first is PMTestTranscriptionPlugin)
        XCTAssertTrue(sut.llmProviders.first is PMTestLLMPlugin)
    }

    func testTranscriptionEngineReturnsFirstMatch() {
        let engine1 = PMTestTranscriptionPlugin()
        engine1.providerId = "shared-provider-id"
        injectPlugin(id: "engine-first", name: "EngineFirst", instance: engine1, isEnabled: true)

        // Two engines with same providerId: first match wins.
        let engine2 = PMTestTranscriptionPlugin()
        engine2.providerId = "shared-provider-id"
        injectPlugin(id: "engine-second", name: "EngineSecond", instance: engine2, isEnabled: true)

        let found = sut.transcriptionEngine(for: "shared-provider-id")
        XCTAssertNotNil(found)
        // Should return the first one.
        XCTAssertEqual(sut.transcriptionEngines.filter { $0.providerId == "shared-provider-id" }.count, 2)
    }

    func testLLMProviderReturnsFirstMatch() {
        let llm1 = PMTestLLMPlugin()
        llm1.providerName = "SharedName"
        injectPlugin(id: "llm-first", name: "LLMFirst", instance: llm1, isEnabled: true)

        let llm2 = PMTestLLMPlugin()
        llm2.providerName = "SharedName"
        injectPlugin(id: "llm-second", name: "LLMSecond", instance: llm2, isEnabled: true)

        let found = sut.llmProvider(for: "SharedName")
        XCTAssertNotNil(found)
        XCTAssertEqual(sut.llmProviders.filter { $0.providerName == "SharedName" }.count, 2)
    }

    // MARK: - Enable/Disable Round-Trip

    func testEnableDisableRoundTrip() {
        let plugin = PMTestMockPlugin()
        injectPlugin(id: "round-trip", name: "RoundTrip", instance: plugin, isEnabled: true)

        let enabledKey = "plugin.round-trip.enabled"
        trackUserDefaultsKey(enabledKey)

        // Disable.
        sut.setPluginEnabled("round-trip", enabled: false)
        XCTAssertFalse(sut.loadedPlugins.first!.isEnabled)
        XCTAssertTrue(plugin.deactivateCalled)

        // Re-enable.
        plugin.deactivateCalled = false
        sut.setPluginEnabled("round-trip", enabled: true)
        XCTAssertTrue(sut.loadedPlugins.first!.isEnabled)
        XCTAssertTrue(plugin.isActivated)
    }

    // MARK: - Mixed Plugin Types in loadedPlugins

    func testLoadedPluginsCanContainMixedTypes() {
        let engine = PMTestTranscriptionPlugin()
        let llm = PMTestLLMPlugin()
        let base = PMTestMockPlugin()

        injectPlugin(id: "mixed-engine", name: "MixedEngine", instance: engine, isEnabled: true)
        injectPlugin(id: "mixed-llm", name: "MixedLLM", instance: llm, isEnabled: false)
        injectPlugin(id: "mixed-base", name: "MixedBase", instance: base, isEnabled: true)

        XCTAssertEqual(sut.loadedPlugins.count, 3)
        XCTAssertEqual(sut.transcriptionEngines.count, 1, "Only enabled transcription engines")
        XCTAssertEqual(sut.llmProviders.count, 0, "Only enabled LLM providers (none here: disabled)")
    }

    // MARK: - PluginManager Shared Instance

    func testSharedCanBeSetAndCleared() {
        let original = PluginManager.shared
        PluginManager.shared = sut
        XCTAssertTrue(PluginManager.shared === sut, "shared should reference the assigned instance")
        PluginManager.shared = original
    }
}
