import XCTest
import DavyWhisperPluginSDK
@testable import DavyWhisper

@MainActor
final class ParaformerBundleResolutionTests: XCTestCase {

    private var tempDir: URL!
    private var plugin: ParaformerPlugin!
    private var mockHost: MockHostServices!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ParaformerResolution-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        mockHost = MockHostServices(pluginDataDirectory: tempDir)
        plugin = ParaformerPlugin()
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        plugin = nil
        mockHost = nil
        super.tearDown()
    }

    // MARK: - F1-3: Bundle 模型路径验证

    /// 验证 Bundle 中包含 Paraformer 模型文件（构建验证）
    /// Bundle-first 策略：应优先从 Bundle.main 解析
    func testResolveModelDir_bundleResources_found() {
        plugin.activate(host: mockHost)

        let result = plugin.resolveModelDir()
        XCTAssertNotNil(result, "Bundle should contain ParaformerModel resources")
        XCTAssertEqual(result?.lastPathComponent, "ParaformerModel")

        // 验证关键模型文件存在
        let modelFile = result?.appendingPathComponent("model.int8.onnx").path ?? ""
        let tokensFile = result?.appendingPathComponent("tokens.txt").path ?? ""
        XCTAssertTrue(FileManager.default.fileExists(atPath: modelFile), "model.int8.onnx must exist in bundle")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tokensFile), "tokens.txt must exist in bundle")
    }

    /// Bundle 优先级高于插件数据目录——即使插件数据目录也有模型，Bundle 路径优先返回
    func testResolveModelDir_bundleTakesPriorityOverPluginDataDir() throws {
        // 同时在插件数据目录创建模型文件
        let modelDir = tempDir.appendingPathComponent("models/paraformer", isDirectory: true)
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        try Data().write(to: modelDir.appendingPathComponent("model.int8.onnx"))
        try Data("token".utf8).write(to: modelDir.appendingPathComponent("tokens.txt"))

        plugin.activate(host: mockHost)

        let result = plugin.resolveModelDir()
        XCTAssertNotNil(result)
        // Bundle-first: 应返回 Bundle 路径（ParaformerModel），不是插件数据目录（paraformer）
        XCTAssertEqual(result?.lastPathComponent, "ParaformerModel",
                        "Bundle path should take priority over plugin data directory")
    }

    /// 插件数据目录中的标点模型可被正确解析
    func testResolvePunctuationModelPath_pluginDataDir_findsModel() throws {
        let puncDir = tempDir.appendingPathComponent("models/punctuation", isDirectory: true)
        try FileManager.default.createDirectory(at: puncDir, withIntermediateDirectories: true)
        try Data().write(to: puncDir.appendingPathComponent("model.int8.onnx"))

        plugin.activate(host: mockHost)

        let result = plugin.resolvePunctuationModelPath()
        XCTAssertNotNil(result, "Should find punctuation model in plugin data directory")
        XCTAssertTrue(result!.hasSuffix("model.int8.onnx"))
    }
}
