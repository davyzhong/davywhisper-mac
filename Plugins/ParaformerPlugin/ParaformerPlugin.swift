import Foundation
import SwiftUI
import DavyWhisperPluginSDK
import os.log

private let pfLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DavyWhisper", category: "ParaformerPlugin")

// MARK: - Plugin Entry Point

@objc(ParaformerPlugin)
final class ParaformerPlugin: NSObject, TranscriptionEnginePlugin, PluginSettingsActivityReporting, @unchecked Sendable {
    static let pluginId = "com.davywhisper.paraformer"
    static let pluginName = "Paraformer"

    fileprivate var host: HostServices?
    fileprivate var recognizer: SherpaOnnxOfflineRecognizer?
    fileprivate var punctuation: SherpaOnnxOfflinePunctuationWrapper?
    fileprivate var loadedModelId: String?
    fileprivate var modelState: ParaformerModelState = .notLoaded

    required override init() {
        super.init()
    }

    func activate(host: HostServices) {
        self.host = host
        Task {
            await loadBundledModel()
        }
    }

    func deactivate() {
        recognizer = nil
        punctuation = nil
        loadedModelId = nil
        modelState = .notLoaded
        host = nil
    }

    // MARK: - TranscriptionEnginePlugin

    var providerId: String { "paraformer" }
    var providerDisplayName: String { "Paraformer (中文优化)" }

    var isConfigured: Bool { recognizer != nil }

    var transcriptionModels: [PluginModelInfo] {
        guard loadedModelId != nil else { return [] }
        return [PluginModelInfo(
            id: "paraformer-zh-small",
            displayName: "Paraformer Small",
            sizeDescription: "~79 MB",
            languageCount: 3
        )]
    }

    var selectedModelId: String? { loadedModelId }
    var supportsTranslation: Bool { false }
    var supportsStreaming: Bool { false }

    var supportedLanguages: [String] {
        ["zh", "en", "yue"]
    }

    func selectModel(_ modelId: String) {
        // Only bundled small model supported currently
    }

    func transcribe(
        audio: AudioData,
        language: String?,
        translate: Bool,
        prompt: String?
    ) async throws -> PluginTranscriptionResult {
        guard let recognizer else {
            throw PluginTranscriptionError.notConfigured
        }

        // 1. ASR recognition
        let result = recognizer.decode(samples: audio.samples, sampleRate: 16_000)
        var text = result.text

        // 2. Punctuation restoration
        if let punctuation, !text.isEmpty {
            text = punctuation.addPunct(text: text)
        }

        // 3. Build segments from result
        let segments: [PluginTranscriptionSegment]
        if result.segmentCount > 0 && result.segmentTimestamps.count > 0 {
            segments = (0..<result.segmentCount).map { i in
                let start = i < result.segmentTimestamps.count ? Double(result.segmentTimestamps[i]) : 0
                let duration = i < result.segmentDurations.count ? Double(result.segmentDurations[i]) : 0
                let segText = i < result.segmentTexts.count ? result.segmentTexts[i] : ""
                return PluginTranscriptionSegment(text: segText, start: start, end: start + duration)
            }
        } else {
            segments = [PluginTranscriptionSegment(text: text, start: 0, end: audio.duration)]
        }

        let detectedLang = result.lang.isEmpty ? "zh" : result.lang

        return PluginTranscriptionResult(
            text: text,
            detectedLanguage: detectedLang,
            segments: segments
        )
    }

    func transcribe(
        audio: AudioData,
        language: String?,
        translate: Bool,
        prompt: String?,
        onProgress: @Sendable @escaping (String) -> Bool
    ) async throws -> PluginTranscriptionResult {
        return try await transcribe(audio: audio, language: language, translate: translate, prompt: prompt)
    }

    // MARK: - Model Management

    private func resolveModelDir() -> URL? {
        // 1. Bundle resources (pre-bundled model)
        if let url = Bundle.main.url(forResource: "ParaformerModel", withExtension: nil),
           FileManager.default.fileExists(atPath: url.appendingPathComponent("model.int8.onnx").path) {
            return url
        }
        // 2. Plugin data directory (downloaded model)
        if let dir = host?.pluginDataDirectory {
            let modelDir = dir.appendingPathComponent("models/paraformer")
            if FileManager.default.fileExists(atPath: modelDir.appendingPathComponent("model.int8.onnx").path) {
                return modelDir
            }
        }
        return nil
    }

    private func resolvePunctuationModelPath() -> String? {
        // 1. Bundle resources
        if let url = Bundle.main.url(forResource: "PunctuationModel", withExtension: nil,
                                     subdirectory: "ParaformerModel"),
           FileManager.default.fileExists(atPath: url.appendingPathComponent("model.int8.onnx").path) {
            return url.appendingPathComponent("model.int8.onnx").path
        }
        // 2. Plugin data directory
        if let dir = host?.pluginDataDirectory {
            let path = dir.appendingPathComponent("models/punctuation/model.int8.onnx").path
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return nil
    }

    private func loadBundledModel() async {
        guard let modelDir = resolveModelDir() else {
            pfLogger.info("No Paraformer model found, skipping load")
            modelState = .notLoaded
            return
        }

        modelState = .loading

        let modelPath = modelDir.appendingPathComponent("model.int8.onnx").path
        let tokensPath = modelDir.appendingPathComponent("tokens.txt").path

        // Paraformer offline model config
        let paraformerConfig = sherpaOnnxOfflineParaformerModelConfig(
            model: modelPath
        )

        let modelConfig = sherpaOnnxOfflineModelConfig(
            tokens: tokensPath,
            paraformer: paraformerConfig,
            numThreads: 4,
            provider: "cpu",
            debug: 0,
            modelingUnit: "cjkchar"
        )

        let featConfig = sherpaOnnxFeatureConfig(sampleRate: 16000, featureDim: 80)
        var config = sherpaOnnxOfflineRecognizerConfig(
            featConfig: featConfig,
            modelConfig: modelConfig
        )

        recognizer = SherpaOnnxOfflineRecognizer(config: &config)

        // Initialize punctuation model
        if let puncPath = resolvePunctuationModelPath() {
            let puncModelConfig = sherpaOnnxOfflinePunctuationModelConfig(
                ctTransformer: puncPath,
                numThreads: 1,
                debug: 0,
                provider: "cpu"
            )
            var puncConfig = sherpaOnnxOfflinePunctuationConfig(model: puncModelConfig)
            punctuation = SherpaOnnxOfflinePunctuationWrapper(config: &puncConfig)
            pfLogger.info("Loaded punctuation model from \(puncPath)")
        }

        loadedModelId = "paraformer-zh-small"
        modelState = .ready

        host?.notifyCapabilitiesChanged()
        pfLogger.info("ParaformerPlugin loaded: model=\(modelPath)")
    }

    @objc func triggerRestoreModel() {
        Task { await loadBundledModel() }
    }

    func unloadModel() {
        recognizer = nil
        punctuation = nil
        loadedModelId = nil
        modelState = .notLoaded
        host?.notifyCapabilitiesChanged()
    }

    // MARK: - Settings Activity

    var currentSettingsActivity: PluginSettingsActivity? {
        switch modelState {
        case .notLoaded, .ready:
            return nil
        case .loading:
            return PluginSettingsActivity(message: "Loading Paraformer model...")
        case .error(let message):
            return PluginSettingsActivity(message: message, isError: true)
        }
    }

    var settingsView: AnyView? {
        AnyView(ParaformerSettingsView(plugin: self))
    }
}

// MARK: - Model State

enum ParaformerModelState: Equatable {
    case notLoaded
    case loading
    case ready
    case error(String)

    static func == (lhs: ParaformerModelState, rhs: ParaformerModelState) -> Bool {
        switch (lhs, rhs) {
        case (.notLoaded, .notLoaded): true
        case (.loading, .loading): true
        case (.ready, .ready): true
        case let (.error(a), .error(b)): a == b
        default: false
        }
    }
}

// MARK: - Settings View

private struct ParaformerSettingsView: View {
    let plugin: ParaformerPlugin
    @State private var modelState: ParaformerModelState = .notLoaded

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Paraformer (中文优化)")
                .font(.headline)

            Text("基于阿里巴巴达摩院 Paraformer 非自回归语音识别。中文准确率业界领先，支持自动标点恢复。")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 8) {
                switch modelState {
                case .ready:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("模型已加载，随时可用")
                        .font(.body)
                case .loading:
                    ProgressView()
                        .controlSize(.small)
                    Text("正在加载模型...")
                        .font(.body)
                case .error(let msg):
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .notLoaded:
                    Image(systemName: "circle.dashed")
                        .foregroundStyle(.secondary)
                    Text("模型未加载")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            if case .ready = modelState {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Paraformer Small (79MB, int8)", systemImage: "cpu")
                    Label("支持语言：中文、英文、粤语", systemImage: "globe")
                    Label("自动标点恢复已启用", systemImage: "text.append")
                    Label("本地运行，无需网络和 API 密钥", systemImage: "wifi.slash")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            if case .error = modelState {
                Button("重新加载") {
                    plugin.triggerRestoreModel()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .onAppear {
            modelState = plugin.modelState
        }
    }
}
