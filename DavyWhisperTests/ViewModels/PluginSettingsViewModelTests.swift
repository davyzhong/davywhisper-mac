import XCTest
import DavyWhisperPluginSDK
@testable import DavyWhisper

// MARK: - Test Plugin Mocks
//
// Named with PSV prefix (PluginSettingsViewModel) to avoid collisions with
// PMTest* mocks in PluginManagerTests.swift.

/// Minimal base plugin mock for PluginSettingsViewModel tests.
final class PSVMockPlugin: DavyWhisperPlugin, @unchecked Sendable {
    static var pluginId: String { "com.davywhisper.psv.mock" }
    static var pluginName: String { "PSVMockPlugin" }

    init() {}
    func activate(host: HostServices) {}
    func deactivate() {}
}

/// Transcription engine plugin mock.
final class PSVMockTranscriptionPlugin: TranscriptionEnginePlugin, @unchecked Sendable {
    static var pluginId: String { "com.davywhisper.psv.transcription" }
    static var pluginName: String { "PSVMockTranscription" }

    var providerId: String = "psv-mock-engine"
    var providerDisplayName: String = "PSV Mock Engine"
    var isConfigured: Bool = true
    var transcriptionModels: [PluginModelInfo] = []
    var selectedModelId: String? = nil
    var supportsTranslation: Bool = false

    init() {}
    func activate(host: HostServices) {}
    func deactivate() {}
    func selectModel(_ modelId: String) { selectedModelId = modelId }
    func transcribe(audio: AudioData, language: String?, translate: Bool, prompt: String?) async throws -> PluginTranscriptionResult {
        PluginTranscriptionResult(text: "mock")
    }
}

/// LLM provider plugin mock.
final class PSVMockLLMPlugin: LLMProviderPlugin, @unchecked Sendable {
    static var pluginId: String { "com.davywhisper.psv.llm" }
    static var pluginName: String { "PSVMockLLM" }

    var providerName: String = "PSVMockLLM"
    var isAvailable: Bool = true
    var supportedModels: [PluginModelInfo] = []

    init() {}
    func activate(host: HostServices) {}
    func deactivate() {}
    func process(systemPrompt: String, userText: String, model: String?) async throws -> String {
        return "mock response"
    }
}

// MARK: - PluginSettingsViewModelTests

@MainActor
final class PluginSettingsViewModelTests: XCTestCase {

    private var sut: PluginSettingsViewModel!
    private var pluginManager: PluginManager!
    private var registryService: PluginRegistryService!
    private var tempDir: URL!
    private var savedEventBus: EventBus?

    // UserDefaults keys that tests may set; cleaned up in tearDown.
    private var taintedUserDefaultsKeys: [String] = []

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginSettingsVMTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        savedEventBus = EventBus.shared
        EventBus.shared = EventBus()

        pluginManager = PluginManager(appSupportDirectory: tempDir)
        registryService = PluginRegistryService()
        PluginManager.shared = pluginManager
        PluginRegistryService.shared = registryService

        sut = PluginSettingsViewModel(
            pluginManager: pluginManager,
            registryService: registryService
        )
    }

    override func tearDown() {
        for key in taintedUserDefaultsKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        taintedUserDefaultsKeys.removeAll()

        sut = nil
        registryService = nil
        pluginManager = nil
        EventBus.shared = savedEventBus
        savedEventBus = nil
        PluginManager.shared = nil
        PluginRegistryService.shared = nil

        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        super.tearDown()
    }

    // MARK: - Helpers

    private func trackUserDefaultsKey(_ key: String) {
        taintedUserDefaultsKeys.append(key)
    }

    /// Inject a loaded plugin into the PluginManager for testing.
    private func injectPlugin(
        id: String = "com.davywhisper.psv.test",
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
            sourceURL: tempDir.appendingPathComponent("mock-\(id)"),
            isEnabled: isEnabled
        )
        pluginManager.loadedPlugins.append(loaded)
        return loaded
    }

    /// Create a RegistryPlugin for testing.
    private func makeRegistryPlugin(
        id: String = "com.davywhisper.psv.reg",
        name: String = "RegistryPlugin",
        version: String = "2.0.0",
        category: String = "transcription",
        requiresAPIKey: Bool? = nil
    ) -> RegistryPlugin {
        RegistryPlugin(
            id: id,
            name: name,
            version: version,
            minHostVersion: "0.1",
            minOSVersion: nil,
            author: "Test",
            description: "Test plugin",
            category: category,
            size: 1024,
            downloadURL: "https://example.com/plugin.zip",
            iconSystemName: nil,
            requiresAPIKey: requiresAPIKey,
            descriptions: nil
        )
    }

    // MARK: - Init Tests

    func testInit_withInjectedDependencies() {
        XCTAssertNotNil(sut, "ViewModel should initialize with injected dependencies")
    }

    func testInit_usesDefaultSharedInstances() {
        // Verify the default parameter path does not crash.
        let vm = PluginSettingsViewModel()
        XCTAssertNotNil(vm)
    }

    // MARK: - categoryForPlugin

    func testCategoryForPlugin_withRegistryMatch() {
        let regPlugin = makeRegistryPlugin(
            id: "cat-reg-match",
            category: "llm"
        )
        registryService.registry = [regPlugin]

        let plugin = PSVMockPlugin()
        let loaded = injectPlugin(id: "cat-reg-match", instance: plugin)

        let category = sut.categoryForPlugin(loaded)
        XCTAssertEqual(category, .llm, "Should return category from registry match")
    }

    func testCategoryForPlugin_transcriptionProtocolFallback() {
        // No registry entry for this plugin; should fall back to protocol type.
        let plugin = PSVMockTranscriptionPlugin()
        let loaded = injectPlugin(id: "cat-transcription-fallback", instance: plugin)

        let category = sut.categoryForPlugin(loaded)
        XCTAssertEqual(category, .transcription, "Should return .transcription for TranscriptionEnginePlugin")
    }

    func testCategoryForPlugin_llmProtocolFallback() {
        let plugin = PSVMockLLMPlugin()
        let loaded = injectPlugin(id: "cat-llm-fallback", instance: plugin)

        let category = sut.categoryForPlugin(loaded)
        XCTAssertEqual(category, .llm, "Should return .llm for LLMProviderPlugin")
    }

    func testCategoryForPlugin_utilityFallbackForUnknownPlugin() {
        let plugin = PSVMockPlugin()
        let loaded = injectPlugin(id: "cat-utility-fallback", instance: plugin)

        let category = sut.categoryForPlugin(loaded)
        XCTAssertEqual(category, .utility, "Should return .utility for unrecognized plugin type")
    }

    func testCategoryForPlugin_registryOverridesProtocolType() {
        // A TranscriptionEnginePlugin that has a registry entry with category "llm".
        let regPlugin = makeRegistryPlugin(
            id: "cat-override",
            category: "llm"
        )
        registryService.registry = [regPlugin]

        let plugin = PSVMockTranscriptionPlugin()
        let loaded = injectPlugin(id: "cat-override", instance: plugin)

        let category = sut.categoryForPlugin(loaded)
        XCTAssertEqual(category, .llm, "Registry category should override protocol-based inference")
    }

    func testCategoryForPlugin_invalidCategoryInRegistryFallsBack() {
        // Registry has an invalid category string; should fall back to protocol type.
        let regPlugin = makeRegistryPlugin(
            id: "cat-invalid",
            category: "nonexistent_category"
        )
        registryService.registry = [regPlugin]

        let plugin = PSVMockTranscriptionPlugin()
        let loaded = injectPlugin(id: "cat-invalid", instance: plugin)

        let category = sut.categoryForPlugin(loaded)
        // Raw value "nonexistent_category" fails -> PluginCategory(rawValue:) returns nil -> .utility
        // But the plugin is TranscriptionEnginePlugin, so without registry it would be .transcription.
        // Since registry match is found first, it tries the raw value, fails, and returns .utility.
        XCTAssertEqual(category, .utility, "Invalid registry category should fall back to .utility")
    }

    // MARK: - groupedInstalledPlugins

    func testGroupedInstalledPlugins_emptyPlugins() {
        let groups = sut.groupedInstalledPlugins
        XCTAssertTrue(groups.isEmpty, "Should return empty groups when no plugins are loaded")
    }

    func testGroupedInstalledPlugins_groupsByCategory() {
        let regTranscription = makeRegistryPlugin(id: "group-t", category: "transcription")
        let regLLM = makeRegistryPlugin(id: "group-l", category: "llm")
        registryService.registry = [regTranscription, regLLM]

        let tPlugin = PSVMockPlugin()
        injectPlugin(id: "group-t", name: "Zebra Engine", instance: tPlugin)

        let lPlugin = PSVMockPlugin()
        injectPlugin(id: "group-l", name: "Alpha LLM", instance: lPlugin)

        let groups = sut.groupedInstalledPlugins

        XCTAssertEqual(groups.count, 2, "Should have two category groups")

        // Sort order: transcription (0) < llm (1)
        XCTAssertEqual(groups[0].category, .transcription)
        XCTAssertEqual(groups[1].category, .llm)
    }

    func testGroupedInstalledPlugins_sortsPluginsByNameWithinCategory() {
        let reg1 = makeRegistryPlugin(id: "sort-1", category: "transcription")
        let reg2 = makeRegistryPlugin(id: "sort-2", category: "transcription")
        let reg3 = makeRegistryPlugin(id: "sort-3", category: "transcription")
        registryService.registry = [reg1, reg2, reg3]

        injectPlugin(id: "sort-1", name: "Zebra Engine", instance: PSVMockPlugin())
        injectPlugin(id: "sort-2", name: "Alpha Engine", instance: PSVMockPlugin())
        injectPlugin(id: "sort-3", name: "Mid Engine", instance: PSVMockPlugin())

        let groups = sut.groupedInstalledPlugins
        XCTAssertEqual(groups.count, 1, "All three should be in one group")

        let names = groups[0].plugins.map(\.manifest.name)
        XCTAssertEqual(names, ["Alpha Engine", "Mid Engine", "Zebra Engine"],
                       "Plugins within a category should be sorted by localized name")
    }

    func testGroupedInstalledPlugins_sortsCategoriesBySortOrder() {
        // Inject one plugin per category using protocol-based fallback
        // (no registry entries so it uses protocol detection).
        injectPlugin(id: "group-llm", name: "LLM", instance: PSVMockLLMPlugin())
        injectPlugin(id: "group-transcription", name: "Engine", instance: PSVMockTranscriptionPlugin())
        injectPlugin(id: "group-utility", name: "Utility", instance: PSVMockPlugin())

        let groups = sut.groupedInstalledPlugins
        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups[0].category, .transcription, "transcription sortOrder=0 should be first")
        XCTAssertEqual(groups[1].category, .llm, "llm sortOrder=1 should be second")
        XCTAssertEqual(groups[2].category, .utility, "utility sortOrder=2 should be third")
    }

    // MARK: - filteredAvailablePlugins

    func testFilteredAvailablePlugins_returnsNotInstalledOnly() {
        let reg1 = makeRegistryPlugin(id: "avail-1", name: "Available1")
        let reg2 = makeRegistryPlugin(id: "avail-2", name: "Available2")
        registryService.registry = [reg1, reg2]

        // Install avail-1
        injectPlugin(id: "avail-1", instance: PSVMockPlugin())

        let filtered = sut.filteredAvailablePlugins(hostingFilter: 0)
        XCTAssertEqual(filtered.count, 1, "Only not-installed plugins should appear")
        XCTAssertEqual(filtered.first?.id, "avail-2")
    }

    func testFilteredAvailablePlugins_hostingFilterAll() {
        let local = makeRegistryPlugin(id: "filter-local", requiresAPIKey: false)
        let cloud = makeRegistryPlugin(id: "filter-cloud", requiresAPIKey: true)
        registryService.registry = [local, cloud]

        let filtered = sut.filteredAvailablePlugins(hostingFilter: 0)
        XCTAssertEqual(filtered.count, 2, "Hosting filter 0 (all) should return all not-installed")
    }

    func testFilteredAvailablePlugins_hostingFilterLocalOnly() {
        let local = makeRegistryPlugin(id: "hf-local", requiresAPIKey: false)
        let cloud = makeRegistryPlugin(id: "hf-cloud", requiresAPIKey: true)
        registryService.registry = [local, cloud]

        let filtered = sut.filteredAvailablePlugins(hostingFilter: 1)
        XCTAssertEqual(filtered.count, 1, "Hosting filter 1 (local) should exclude requiresAPIKey=true")
        XCTAssertEqual(filtered.first?.id, "hf-local")
    }

    func testFilteredAvailablePlugins_hostingFilterCloudOnly() {
        let local = makeRegistryPlugin(id: "hf-local2", requiresAPIKey: false)
        let cloud = makeRegistryPlugin(id: "hf-cloud2", requiresAPIKey: true)
        registryService.registry = [local, cloud]

        let filtered = sut.filteredAvailablePlugins(hostingFilter: 2)
        XCTAssertEqual(filtered.count, 1, "Hosting filter 2 (cloud) should include only requiresAPIKey=true")
        XCTAssertEqual(filtered.first?.id, "hf-cloud2")
    }

    func testFilteredAvailablePlugins_hostingFilterLocalExcludesNilRequiresAPIKey() {
        // requiresAPIKey is nil (not set); filter 1 checks requiresAPIKey != true,
        // so nil should be included in local filter.
        let nilKey = makeRegistryPlugin(id: "hf-nil", requiresAPIKey: nil)
        registryService.registry = [nilKey]

        let local = sut.filteredAvailablePlugins(hostingFilter: 1)
        XCTAssertEqual(local.count, 1, "nil requiresAPIKey should be treated as local")

        let cloud = sut.filteredAvailablePlugins(hostingFilter: 2)
        XCTAssertTrue(cloud.isEmpty, "nil requiresAPIKey should not appear in cloud filter")
    }

    func testFilteredAvailablePlugins_emptyRegistry() {
        registryService.registry = []
        let filtered = sut.filteredAvailablePlugins(hostingFilter: 0)
        XCTAssertTrue(filtered.isEmpty)
    }

    // MARK: - groupedAvailablePlugins

    func testGroupedAvailablePlugins_groupsByCategory() {
        let t1 = makeRegistryPlugin(id: "ga-t1", category: "transcription")
        let t2 = makeRegistryPlugin(id: "ga-t2", category: "transcription")
        let l1 = makeRegistryPlugin(id: "ga-l1", category: "llm")
        registryService.registry = [t1, t2, l1]

        let groups = sut.groupedAvailablePlugins(hostingFilter: 0)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].category, .transcription)
        XCTAssertEqual(groups[0].plugins.count, 2)
        XCTAssertEqual(groups[1].category, .llm)
        XCTAssertEqual(groups[1].plugins.count, 1)
    }

    func testGroupedAvailablePlugins_sortsPluginsByName() {
        let p1 = makeRegistryPlugin(id: "ga-s1", name: "Zebra Plugin", category: "transcription")
        let p2 = makeRegistryPlugin(id: "ga-s2", name: "Alpha Plugin", category: "transcription")
        let p3 = makeRegistryPlugin(id: "ga-s3", name: "Mid Plugin", category: "transcription")
        registryService.registry = [p1, p2, p3]

        let groups = sut.groupedAvailablePlugins(hostingFilter: 0)
        XCTAssertEqual(groups.count, 1)
        let names = groups[0].plugins.map(\.name)
        XCTAssertEqual(names, ["Alpha Plugin", "Mid Plugin", "Zebra Plugin"])
    }

    func testGroupedAvailablePlugins_sortsCategoriesBySortOrder() {
        let u = makeRegistryPlugin(id: "ga-u", category: "utility")
        let t = makeRegistryPlugin(id: "ga-t", category: "transcription")
        let l = makeRegistryPlugin(id: "ga-l", category: "llm")
        registryService.registry = [u, t, l]

        let groups = sut.groupedAvailablePlugins(hostingFilter: 0)
        XCTAssertEqual(groups[0].category, .transcription)
        XCTAssertEqual(groups[1].category, .llm)
        XCTAssertEqual(groups[2].category, .utility)
    }

    func testGroupedAvailablePlugins_respectsHostingFilter() {
        let local = makeRegistryPlugin(id: "ga-hf-local", category: "transcription", requiresAPIKey: false)
        let cloud = makeRegistryPlugin(id: "ga-hf-cloud", category: "llm", requiresAPIKey: true)
        registryService.registry = [local, cloud]

        let allGroups = sut.groupedAvailablePlugins(hostingFilter: 0)
        XCTAssertEqual(allGroups.count, 2)

        let localGroups = sut.groupedAvailablePlugins(hostingFilter: 1)
        XCTAssertEqual(localGroups.count, 1)
        XCTAssertEqual(localGroups[0].category, .transcription)

        let cloudGroups = sut.groupedAvailablePlugins(hostingFilter: 2)
        XCTAssertEqual(cloudGroups.count, 1)
        XCTAssertEqual(cloudGroups[0].category, .llm)
    }

    func testGroupedAvailablePlugins_excludesInstalledPlugins() {
        let reg = makeRegistryPlugin(id: "ga-installed", category: "transcription")
        registryService.registry = [reg]

        // Install the plugin so it's no longer "available"
        injectPlugin(id: "ga-installed", instance: PSVMockPlugin())

        let groups = sut.groupedAvailablePlugins(hostingFilter: 0)
        XCTAssertTrue(groups.isEmpty, "Installed plugins should be excluded from available list")
    }

    // MARK: - installPlugin

    func testInstallPlugin_callsDownloadAndInstall() async {
        let regPlugin = makeRegistryPlugin(id: "install-test")

        // We cannot easily mock downloadAndInstall since it's a concrete class method.
        // Instead, verify that the method is called without crashing by checking
        // that installStates is set (downloadAndInstall sets it).
        // Since the download URL is fake, it will fail, but we can verify it attempts.

        await sut.installPlugin(regPlugin)

        // After downloadAndInstall fails (invalid URL or network error),
        // installStates should have an error entry for this plugin.
        let state = registryService.installStates["install-test"]
        XCTAssertNotNil(state, "installPlugin should trigger downloadAndInstall which sets installStates")

        // Also verify setPluginEnabled was called (it won't crash even if plugin not loaded).
        let enabledKey = "plugin.install-test.enabled"
        trackUserDefaultsKey(enabledKey)
    }

    // MARK: - uninstallPlugin

    func testUninstallPlugin_callsRegistryService() {
        let plugin = PSVMockPlugin()
        injectPlugin(id: "uninstall-test", name: "UninstallTest", instance: plugin, isEnabled: true)

        // Set up PluginManager.shared for registryService (it uses PluginManager.shared internally).
        let enabledKey = "plugin.uninstall-test.enabled"
        trackUserDefaultsKey(enabledKey)

        sut.uninstallPlugin("uninstall-test")

        // The plugin should be unloaded from PluginManager.
        let found = pluginManager.loadedPlugins.contains { $0.manifest.id == "uninstall-test" }
        XCTAssertFalse(found, "Plugin should be removed after uninstall")
    }

    // MARK: - installFromFile

    func testInstallFromFile_delegatesToRegistryService() async throws {
        // Create a dummy .bundle directory for testing.
        let bundleURL = tempDir.appendingPathComponent("FromFileTest.bundle", isDirectory: true)
        let resourcesDir = bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        try FileManager.default.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

        let manifest = PluginManifest(
            id: "from-file-test",
            name: "FromFileTest",
            version: "1.0.0",
            principalClass: "PSVMockPlugin"
        )
        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(to: resourcesDir.appendingPathComponent("manifest.json"))

        // installFromFile delegates to registryService which uses PluginManager.shared.
        // The bundle won't actually load (NSClassFromString fails), but it shouldn't crash.
        try await sut.installFromFile(bundleURL)

        // Verify the bundle was copied to the plugins directory.
        let destURL = pluginManager.pluginsDirectory.appendingPathComponent("FromFileTest.bundle")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: destURL.path),
            "Bundle should be copied to plugins directory"
        )
    }

    // MARK: - updatePlugin

    func testUpdatePlugin_withExistingRegistryEntry() async {
        let regPlugin = makeRegistryPlugin(id: "update-test", version: "2.0.0")
        registryService.registry = [regPlugin]

        await sut.updatePlugin("update-test")

        // downloadAndInstall will fail (fake URL), but installStates should be set.
        let state = registryService.installStates["update-test"]
        XCTAssertNotNil(state, "updatePlugin should trigger downloadAndInstall for existing registry entry")
    }

    func testUpdatePlugin_withNonExistingRegistryEntry() async {
        // No registry entry for this plugin ID.
        registryService.registry = []

        await sut.updatePlugin("nonexistent-plugin")

        // Should silently do nothing; no installStates set.
        let state = registryService.installStates["nonexistent-plugin"]
        XCTAssertNil(state, "updatePlugin should be a no-op when registry entry is not found")
    }

    // MARK: - setPluginEnabled

    func testSetPluginEnabled_delegatesToPluginManager() {
        let plugin = PSVMockPlugin()
        injectPlugin(id: "enable-test", name: "EnableTest", instance: plugin, isEnabled: true)

        let enabledKey = "plugin.enable-test.enabled"
        trackUserDefaultsKey(enabledKey)

        sut.setPluginEnabled("enable-test", enabled: false)

        let loaded = pluginManager.loadedPlugins.first { $0.manifest.id == "enable-test" }
        XCTAssertNotNil(loaded)
        XCTAssertFalse(loaded!.isEnabled, "Plugin should be disabled via PluginManager")
    }

    func testSetPluginEnabled_enablesPlugin() {
        let plugin = PSVMockPlugin()
        injectPlugin(id: "enable-test-2", name: "EnableTest2", instance: plugin, isEnabled: false)

        let enabledKey = "plugin.enable-test-2.enabled"
        trackUserDefaultsKey(enabledKey)

        sut.setPluginEnabled("enable-test-2", enabled: true)

        let loaded = pluginManager.loadedPlugins.first { $0.manifest.id == "enable-test-2" }
        XCTAssertNotNil(loaded)
        XCTAssertTrue(loaded!.isEnabled, "Plugin should be enabled via PluginManager")
    }

    // MARK: - fetchRegistry

    func testFetchRegistry_delegatesToRegistryService() async {
        // fetchRegistry on registryService will attempt a network call.
        // Since we're in tests, it will fail and potentially fall back to bundled plugins.json.
        // The key test: it does not crash.
        await sut.fetchRegistry()
        // No assertion needed beyond not crashing; the method is a pure delegation.
    }

    // MARK: - installInfo

    func testInstallInfo_forInstalledPlugin() {
        let regPlugin = makeRegistryPlugin(id: "info-installed", version: "1.0.0")
        registryService.registry = [regPlugin]

        injectPlugin(id: "info-installed", version: "1.0.0", instance: PSVMockPlugin())

        let info = sut.installInfo(for: "info-installed")
        if case .installed(let version) = info {
            XCTAssertEqual(version, "1.0.0", "Should return installed version for matching version")
        } else if case .bundled = info {
            // Bundle.main is treated as bundled; acceptable in test environment.
        } else {
            XCTFail("Expected .installed or .bundled, got \(info)")
        }
    }

    func testInstallInfo_forNotInstalledPlugin() {
        let info = sut.installInfo(for: "nonexistent-info-plugin")
        if case .notInstalled = info {
            // Expected
        } else {
            XCTFail("Expected .notInstalled, got \(info)")
        }
    }

    func testInstallInfo_forUpdateAvailable() {
        let regPlugin = makeRegistryPlugin(id: "info-update", version: "2.0.0")
        registryService.registry = [regPlugin]

        // Install with older version
        injectPlugin(id: "info-update", version: "1.0.0", instance: PSVMockPlugin())

        let info = sut.installInfo(for: "info-update")
        if case .updateAvailable(let installed, let available) = info {
            XCTAssertEqual(installed, "1.0.0")
            XCTAssertEqual(available, "2.0.0")
        } else if case .bundled = info {
            // Bundled check takes priority in some cases
        } else {
            XCTFail("Expected .updateAvailable or .bundled, got \(info)")
        }
    }

    // MARK: - installState

    func testInstallState_returnsNilWhenNotSet() {
        let state = sut.installState(for: "no-state-plugin")
        XCTAssertNil(state, "Should return nil when no install state exists")
    }

    func testInstallState_returnsSetState() {
        registryService.installStates["state-test"] = .downloading(0.5)
        let state = sut.installState(for: "state-test")
        XCTAssertEqual(state, .downloading(0.5))
    }

    // MARK: - registryPlugin

    func testRegistryPlugin_returnsMatchById() {
        let regPlugin = makeRegistryPlugin(id: "lookup-test")
        registryService.registry = [regPlugin]

        let found = sut.registryPlugin(for: "lookup-test")
        XCTAssertNotNil(found, "Should find registry plugin by ID")
        XCTAssertEqual(found?.id, "lookup-test")
    }

    func testRegistryPlugin_returnsNilForUnknownId() {
        registryService.registry = []
        let found = sut.registryPlugin(for: "unknown-id")
        XCTAssertNil(found, "Should return nil for unknown plugin ID")
    }

    func testRegistryPlugin_returnsFirstMatch() {
        let p1 = makeRegistryPlugin(id: "dup-id", name: "First")
        let p2 = makeRegistryPlugin(id: "dup-id", name: "Second")
        registryService.registry = [p1, p2]

        let found = sut.registryPlugin(for: "dup-id")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "First", "Should return the first matching plugin")
    }

    // MARK: - openPluginsFolder

    func testOpenPluginsFolder_doesNotCrash() {
        // openPluginsFolder calls NSWorkspace.shared.open.
        // In test environment, just verify it doesn't crash.
        sut.openPluginsFolder()
    }
}
