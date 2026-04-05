import XCTest
import DavyWhisperPluginSDK
@testable import DavyWhisper

// MARK: - OpenAICompatiblePlugin Tests

@MainActor
final class OpenAICompatiblePluginTests: XCTestCase {
    private var plugin: OpenAICompatiblePlugin!
    private var mockHost: MockHostServices!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenAICompatTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        mockHost = MockHostServices(pluginDataDirectory: tempDir)
        plugin = OpenAICompatiblePlugin()
        plugin.activate(host: mockHost)
    }

    override func tearDown() {
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        plugin = nil
        mockHost = nil
        super.tearDown()
    }

    // MARK: - Metadata

    func testPluginId() {
        XCTAssertEqual(OpenAICompatiblePlugin.pluginId, "com.davywhisper.openai-compatible")
    }

    func testPluginName() {
        XCTAssertEqual(OpenAICompatiblePlugin.pluginName, "OpenAI Compatible")
    }

    // MARK: - Availability

    func testNotAvailableWithoutAPIKey() {
        XCTAssertFalse(plugin.isAvailable)
    }

    func testAvailableAfterSettingAPIKey() {
        plugin.saveAPIKey("sk-test")
        XCTAssertTrue(plugin.isAvailable)
    }

    func testNotAvailableWithEmptyAPIKey() {
        plugin.saveAPIKey("")
        XCTAssertFalse(plugin.isAvailable)
    }

    // MARK: - Preset Selection

    func testDefaultPresetIsDeepSeek() {
        let preset = plugin.activePreset
        XCTAssertEqual(preset.id, "deepseek")
        XCTAssertEqual(preset.baseURL, "https://api.deepseek.com/v1")
    }

    func testSwitchToCustomPreset() {
        plugin.setActivePreset(.custom)
        let preset = plugin.activePreset
        XCTAssertEqual(preset.id, "custom")
    }

    // MARK: - Custom Base URL (regression: customBaseURL was ignored by process())

    func testCustomPresetReturnsStoredBaseURL() {
        plugin.setActivePreset(.custom)
        plugin.setCustomBaseURL("https://idealab.example.com/api/openai/v1")

        let preset = plugin.activePreset
        XCTAssertEqual(preset.baseURL, "https://idealab.example.com/api/openai/v1",
                       "Custom preset must resolve to the stored customBaseURL, not empty string")
    }

    func testCustomPresetReturnsEmptyWhenNoURLSet() {
        plugin.setActivePreset(.custom)
        // Don't set customBaseURL

        let preset = plugin.activePreset
        // Falls through to base which has empty URL — this is expected
        // (process() will throw "请先配置 API 地址")
        XCTAssertEqual(preset.id, "custom")
    }

    func testCustomBaseURLPersists() {
        plugin.setCustomBaseURL("https://api.custom-provider.com/v1")
        XCTAssertEqual(plugin.customBaseURL, "https://api.custom-provider.com/v1")
    }

    // MARK: - Model Selection

    func testDeepSeekPresetModels() {
        let models = plugin.supportedModels
        XCTAssertEqual(models.count, 2)
        XCTAssertTrue(models.contains(where: { $0.id == "deepseek-chat" }))
        XCTAssertTrue(models.contains(where: { $0.id == "deepseek-reasoner" }))
    }

    func testCustomPresetHasNoModels() {
        plugin.setActivePreset(.custom)
        XCTAssertTrue(plugin.supportedModels.isEmpty)
    }

    func testSelectModel() {
        plugin.selectModel("deepseek-reasoner")
        XCTAssertEqual(plugin.selectedModelId, "deepseek-reasoner")
    }

    // MARK: - Process Error Cases

    func testProcessThrowsWithoutAPIKey() async {
        do {
            _ = try await plugin.process(systemPrompt: "sys", userText: "hello", model: nil)
            XCTFail("Should have thrown notConfigured")
        } catch let error as PluginChatError {
            if case .notConfigured = error {
                // Expected
            } else {
                XCTFail("Wrong error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testProcessThrowsWithCustomPresetButNoURL() async {
        plugin.saveAPIKey("sk-test")
        plugin.setActivePreset(.custom)
        // Don't set customBaseURL

        do {
            _ = try await plugin.process(systemPrompt: "sys", userText: "hello", model: nil)
            XCTFail("Should have thrown apiError")
        } catch let error as PluginChatError {
            if case .apiError(let message) = error {
                XCTAssertTrue(message.contains("API 地址"), "Expected baseURL error, got: \(message)")
            } else {
                XCTFail("Wrong error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - API Key Management

    func testSaveAndRemoveAPIKey() {
        plugin.saveAPIKey("sk-test-key")
        XCTAssertEqual(plugin.currentAPIKey, "sk-test-key")

        plugin.removeAPIKey()
        XCTAssertNil(plugin.currentAPIKey)
    }

    // MARK: - ProviderPreset Equality

    func testPresetEqualityById() {
        let a = ProviderPreset.deepSeek
        let b = ProviderPreset.deepSeek
        XCTAssertEqual(a, b)
    }

    func testPresetInequality() {
        XCTAssertNotEqual(ProviderPreset.deepSeek, ProviderPreset.custom)
    }

    func testAllCasesContainsBothPresets() {
        XCTAssertEqual(ProviderPreset.allCases.count, 2)
    }
}
