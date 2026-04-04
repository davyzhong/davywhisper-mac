import XCTest
import DavyWhisperPluginSDK
@testable import DavyWhisper

// MARK: - GLM Plugin Tests

@MainActor
final class GLMPluginTests: XCTestCase {
    private var plugin: GLMPlugin!
    private var mockHost: MockHostServices!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GLMTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        mockHost = MockHostServices(pluginDataDirectory: tempDir)
        plugin = GLMPlugin()
        plugin.activate(host: mockHost)
    }

    override func tearDown() {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        plugin = nil
        mockHost = nil
        super.tearDown()
    }

    func testMetadata() {
        XCTAssertEqual(GLMPlugin.pluginId, "com.davywhisper.glm")
        XCTAssertEqual(GLMPlugin.pluginName, "GLM")
        XCTAssertEqual(plugin.providerName, "GLM (Zhipu AI)")
    }

    func testNotAvailableWithoutAPIKey() {
        XCTAssertFalse(plugin.isAvailable)
    }

    func testAvailableAfterSettingAPIKey() throws {
        try plugin.saveAPIKey("sk-test")
        XCTAssertTrue(plugin.isAvailable)
    }

    func testSupportedModels() {
        let models = plugin.supportedModels
        XCTAssertEqual(models.count, 4)
        XCTAssertTrue(models.contains(where: { $0.id == "glm-4-flash" }))
        XCTAssertTrue(models.contains(where: { $0.id == "glm-4-air" }))
        XCTAssertTrue(models.contains(where: { $0.id == "glm-4-plus" }))
        XCTAssertTrue(models.contains(where: { $0.id == "glm-4-long" }))
    }

    func testDefaultModelSelected() {
        XCTAssertEqual(plugin.selectedModelId, "glm-4-flash")
    }

    func testModelSelection() {
        plugin.selectModel("glm-4-plus")
        XCTAssertEqual(plugin.selectedModelId, "glm-4-plus")
    }

    func testModelPersistsInUserDefaults() {
        plugin.selectModel("glm-4-long")
        XCTAssertEqual(mockHost.userDefault(forKey: "glm-selected-model") as? String, "glm-4-long")
    }

    func testSettingsView() {
        XCTAssertNotNil(plugin.settingsView)
    }

    func testProcessThrowsWithoutKey() async {
        do {
            _ = try await plugin.process(systemPrompt: "test", userText: "hello", model: nil)
            XCTFail("Should throw when no API key set")
        } catch {
            // Expected
        }
    }

    func testActivateDeactivate() {
        let fresh = GLMPlugin()
        fresh.activate(host: mockHost)
        XCTAssertNotNil(fresh.selectedModelId)
        fresh.deactivate()
        XCTAssertFalse(fresh.isAvailable)
    }

    func testCurrentAPIKeyRoundTrip() throws {
        XCTAssertNil(plugin.currentAPIKey)
        try plugin.saveAPIKey("sk-glm-test")
        XCTAssertEqual(plugin.currentAPIKey, "sk-glm-test")
    }
}

// MARK: - Kimi Plugin Tests

@MainActor
final class KimiPluginTests: XCTestCase {
    private var plugin: KimiPlugin!
    private var mockHost: MockHostServices!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("KimiTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        mockHost = MockHostServices(pluginDataDirectory: tempDir)
        plugin = KimiPlugin()
        plugin.activate(host: mockHost)
    }

    override func tearDown() {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        plugin = nil
        mockHost = nil
        super.tearDown()
    }

    func testMetadata() {
        XCTAssertEqual(KimiPlugin.pluginId, "com.davywhisper.kimi")
        XCTAssertEqual(KimiPlugin.pluginName, "Kimi")
        XCTAssertEqual(plugin.providerName, "Kimi")
    }

    func testNotAvailableWithoutAPIKey() {
        XCTAssertFalse(plugin.isAvailable)
    }

    func testAvailableAfterSettingAPIKey() throws {
        try plugin.saveAPIKey("sk-test")
        XCTAssertTrue(plugin.isAvailable)
    }

    func testSupportedModels() {
        let models = plugin.supportedModels
        XCTAssertEqual(models.count, 4)
        XCTAssertTrue(models.contains(where: { $0.id == "moonshot-v1-8k" }))
        XCTAssertTrue(models.contains(where: { $0.id == "moonshot-v1-128k" }))
    }

    func testDefaultModelSelected() {
        XCTAssertEqual(plugin.selectedModelId, "moonshot-v1-8k")
    }

    func testModelSelection() {
        plugin.selectModel("moonshot-v1-128k")
        XCTAssertEqual(plugin.selectedModelId, "moonshot-v1-128k")
    }

    func testModelPersistsInUserDefaults() {
        plugin.selectModel("moonshot-v1-32k")
        XCTAssertEqual(mockHost.userDefault(forKey: "kimi-selected-model") as? String, "moonshot-v1-32k")
    }

    func testSettingsView() {
        XCTAssertNotNil(plugin.settingsView)
    }

    func testProcessThrowsWithoutKey() async {
        do {
            _ = try await plugin.process(systemPrompt: "test", userText: "hello", model: nil)
            XCTFail("Should throw when no API key set")
        } catch {
            // Expected
        }
    }

    func testActivateDeactivate() {
        let fresh = KimiPlugin()
        fresh.activate(host: mockHost)
        XCTAssertNotNil(fresh.selectedModelId)
        fresh.deactivate()
        XCTAssertFalse(fresh.isAvailable)
    }

    func testCurrentAPIKeyRoundTrip() throws {
        XCTAssertNil(plugin.currentAPIKey)
        try plugin.saveAPIKey("sk-kimi-test")
        XCTAssertEqual(plugin.currentAPIKey, "sk-kimi-test")
    }
}

// MARK: - MiniMax Plugin Tests

@MainActor
final class MiniMaxPluginTests: XCTestCase {
    private var plugin: MiniMaxPlugin!
    private var mockHost: MockHostServices!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiniMaxTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        mockHost = MockHostServices(pluginDataDirectory: tempDir)
        plugin = MiniMaxPlugin()
        plugin.activate(host: mockHost)
    }

    override func tearDown() {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        plugin = nil
        mockHost = nil
        super.tearDown()
    }

    func testMetadata() {
        XCTAssertEqual(MiniMaxPlugin.pluginId, "com.davywhisper.minimax")
        XCTAssertEqual(MiniMaxPlugin.pluginName, "MiniMax")
        XCTAssertEqual(plugin.providerName, "MiniMax")
    }

    func testNotAvailableWithoutAPIKey() {
        XCTAssertFalse(plugin.isAvailable)
    }

    func testAvailableAfterSettingAPIKey() throws {
        try plugin.saveAPIKey("sk-test")
        XCTAssertTrue(plugin.isAvailable)
    }

    func testSupportedModels() {
        let models = plugin.supportedModels
        XCTAssertEqual(models.count, 3)
        XCTAssertTrue(models.contains(where: { $0.id == "MiniMax-Text-01" }))
        XCTAssertTrue(models.contains(where: { $0.id == "abab6.5s-chat" }))
    }

    func testDefaultModelSelected() {
        XCTAssertEqual(plugin.selectedModelId, "MiniMax-Text-01")
    }

    func testModelSelection() {
        plugin.selectModel("abab6.5s-chat")
        XCTAssertEqual(plugin.selectedModelId, "abab6.5s-chat")
    }

    func testModelPersistsInUserDefaults() {
        plugin.selectModel("abab6.5s-chat")
        XCTAssertEqual(mockHost.userDefault(forKey: "minimax-selected-model") as? String, "abab6.5s-chat")
    }

    func testSettingsView() {
        XCTAssertNotNil(plugin.settingsView)
    }

    func testProcessThrowsWithoutKey() async {
        do {
            _ = try await plugin.process(systemPrompt: "test", userText: "hello", model: nil)
            XCTFail("Should throw when no API key set")
        } catch {
            // Expected
        }
    }

    func testActivateDeactivate() {
        let fresh = MiniMaxPlugin()
        fresh.activate(host: mockHost)
        XCTAssertNotNil(fresh.selectedModelId)
        fresh.deactivate()
        XCTAssertFalse(fresh.isAvailable)
    }

    func testCurrentAPIKeyRoundTrip() throws {
        XCTAssertNil(plugin.currentAPIKey)
        try plugin.saveAPIKey("sk-minimax-test")
        XCTAssertEqual(plugin.currentAPIKey, "sk-minimax-test")
    }
}

// MARK: - Bailian Plugin Tests

@MainActor
final class BailianPluginTests: XCTestCase {
    private var plugin: BailianPlugin!
    private var mockHost: MockHostServices!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BailianTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        mockHost = MockHostServices(pluginDataDirectory: tempDir)
        plugin = BailianPlugin()
        plugin.activate(host: mockHost)
    }

    override func tearDown() {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        plugin = nil
        mockHost = nil
        super.tearDown()
    }

    func testMetadata() {
        XCTAssertEqual(BailianPlugin.pluginId, "com.davywhisper.bailian")
        XCTAssertEqual(BailianPlugin.pluginName, "Bailian")
        XCTAssertEqual(plugin.providerName, "Bailian (Aliyun DashScope)")
    }

    func testNotAvailableWithoutAPIKey() {
        XCTAssertFalse(plugin.isAvailable)
    }

    func testAvailableAfterSettingAPIKey() throws {
        try plugin.saveAPIKey("sk-test")
        XCTAssertTrue(plugin.isAvailable)
    }

    func testSupportedModels() {
        let models = plugin.supportedModels
        XCTAssertEqual(models.count, 4)
        XCTAssertTrue(models.contains(where: { $0.id == "qwen-plus" }))
        XCTAssertTrue(models.contains(where: { $0.id == "qwen-turbo" }))
        XCTAssertTrue(models.contains(where: { $0.id == "qwen-max" }))
        XCTAssertTrue(models.contains(where: { $0.id == "qwen-long" }))
    }

    func testDefaultModelSelected() {
        XCTAssertEqual(plugin.selectedModelId, "qwen-plus")
    }

    func testModelSelection() {
        plugin.selectModel("qwen-max")
        XCTAssertEqual(plugin.selectedModelId, "qwen-max")
    }

    func testModelPersistsInUserDefaults() {
        plugin.selectModel("qwen-long")
        XCTAssertEqual(mockHost.userDefault(forKey: "bailian-selected-model") as? String, "qwen-long")
    }

    func testSettingsView() {
        XCTAssertNotNil(plugin.settingsView)
    }

    func testProcessThrowsWithoutKey() async {
        do {
            _ = try await plugin.process(systemPrompt: "test", userText: "hello", model: nil)
            XCTFail("Should throw when no API key set")
        } catch {
            // Expected
        }
    }

    func testActivateDeactivate() {
        let fresh = BailianPlugin()
        fresh.activate(host: mockHost)
        XCTAssertNotNil(fresh.selectedModelId)
        fresh.deactivate()
        XCTAssertFalse(fresh.isAvailable)
    }

    func testCurrentAPIKeyRoundTrip() throws {
        XCTAssertNil(plugin.currentAPIKey)
        try plugin.saveAPIKey("sk-bailian-test")
        XCTAssertEqual(plugin.currentAPIKey, "sk-bailian-test")
    }
}
