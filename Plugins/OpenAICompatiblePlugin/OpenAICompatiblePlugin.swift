import Foundation
import SwiftUI
import DavyWhisperPluginSDK

// MARK: - Provider Preset

struct ProviderPreset: Identifiable, Hashable, CaseIterable {
    let id: String
    let displayName: String
    let baseURL: String
    let models: [PluginModelInfo]
    let icon: String

    static func == (lhs: ProviderPreset, rhs: ProviderPreset) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static let allCases: [ProviderPreset] = [
        .glm, .kimi, .minimax, .qwen, .deepSeek, .custom
    ]

    static let glm = ProviderPreset(
        id: "glm",
        displayName: "智谱 GLM",
        baseURL: "https://open.bigmodel.cn/api/paas/v4",
        models: [
            PluginModelInfo(id: "glm-4-flash", displayName: "GLM-4 Flash", sizeDescription: "快速经济"),
            PluginModelInfo(id: "glm-4", displayName: "GLM-4", sizeDescription: "均衡"),
            PluginModelInfo(id: "glm-4-plus", displayName: "GLM-4 Plus", sizeDescription: "最高质量"),
        ],
        icon: "sparkles"
    )

    static let kimi = ProviderPreset(
        id: "kimi",
        displayName: "Moonshot Kimi",
        baseURL: "https://api.moonshot.cn/v1",
        models: [
            PluginModelInfo(id: "moonshot-v1-8k", displayName: "Moonshot V1 8K", sizeDescription: "8K 上下文"),
            PluginModelInfo(id: "moonshot-v1-32k", displayName: "Moonshot V1 32K", sizeDescription: "32K 上下文"),
            PluginModelInfo(id: "moonshot-v1-128k", displayName: "Moonshot V1 128K", sizeDescription: "128K 上下文"),
        ],
        icon: "moon.stars.fill"
    )

    static let minimax = ProviderPreset(
        id: "minimax",
        displayName: "MiniMax",
        baseURL: "https://api.minimax.chat/v1",
        models: [
            PluginModelInfo(id: "MiniMax-Text-01", displayName: "MiniMax Text 01", sizeDescription: "最新模型"),
            PluginModelInfo(id: "abab6.5s-chat", displayName: "ABAB 6.5S Chat", sizeDescription: "对话模型"),
        ],
        icon: "bubble.left.and.bubble.right.fill"
    )

    static let qwen = ProviderPreset(
        id: "qwen",
        displayName: "通义千问",
        baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
        models: [
            PluginModelInfo(id: "qwen-plus", displayName: "Qwen Plus", sizeDescription: "均衡"),
            PluginModelInfo(id: "qwen-max", displayName: "Qwen Max", sizeDescription: "最高质量"),
            PluginModelInfo(id: "qwen-flash", displayName: "Qwen Flash", sizeDescription: "快速经济"),
        ],
        icon: "cloud.fill"
    )

    static let deepSeek = ProviderPreset(
        id: "deepseek",
        displayName: "DeepSeek",
        baseURL: "https://api.deepseek.com/v1",
        models: [
            PluginModelInfo(id: "deepseek-chat", displayName: "DeepSeek Chat", sizeDescription: "通用对话"),
            PluginModelInfo(id: "deepseek-reasoner", displayName: "DeepSeek Reasoner", sizeDescription: "深度推理"),
        ],
        icon: "bolt.fill"
    )

    static let custom = ProviderPreset(
        id: "custom",
        displayName: "自定义 OpenAI 兼容",
        baseURL: "",
        models: [],
        icon: "gearshape.fill"
    )
}

// MARK: - Plugin Entry Point

@objc(OpenAICompatiblePlugin)
final class OpenAICompatiblePlugin: NSObject, LLMProviderPlugin, @unchecked Sendable {
    static let pluginId = "com.davywhisper.openai-compatible"
    static let pluginName = "OpenAI Compatible"

    fileprivate var host: HostServices?

    // MARK: - LLMProviderPlugin

    var providerName: String {
        activePreset.displayName
    }

    var isAvailable: Bool {
        guard let key = currentAPIKey, !key.isEmpty else { return false }
        return true
    }

    var supportedModels: [PluginModelInfo] {
        activePreset.models
    }

    func process(systemPrompt: String, userText: String, model: String?) async throws -> String {
        guard let apiKey = currentAPIKey, !apiKey.isEmpty else {
            throw PluginChatError.notConfigured
        }

        let preset = activePreset
        guard !preset.baseURL.isEmpty else {
            throw PluginChatError.apiError("请先配置 API 地址")
        }

        let modelId = model ?? selectedModelId ?? preset.models.first?.id ?? ""

        let helper = PluginOpenAIChatHelper(baseURL: preset.baseURL)
        return try await helper.process(
            apiKey: apiKey,
            model: modelId,
            systemPrompt: systemPrompt,
            userText: userText
        )
    }

    // MARK: - Lifecycle

    func activate(host: HostServices) {
        self.host = host
    }

    func deactivate() {
        host = nil
    }

    // MARK: - Settings View

    var settingsView: AnyView? {
        AnyView(OpenAICompatibleSettingsView(plugin: self))
    }

    // MARK: - State Accessors

    var activePreset: ProviderPreset {
        let presetId = host?.userDefault(forKey: "activeProvider") as? String ?? ""
        return ProviderPreset.allCases.first { $0.id == presetId } ?? .glm
    }

    var currentAPIKey: String? {
        host?.loadSecret(key: "api-key")
    }

    var selectedModelId: String? {
        host?.userDefault(forKey: "selectedModel") as? String
    }

    // MARK: - Actions

    func setActivePreset(_ preset: ProviderPreset) {
        host?.setUserDefault(preset.id, forKey: "activeProvider")
        host?.notifyCapabilitiesChanged()
    }

    func saveAPIKey(_ key: String) {
        do {
            try host?.storeSecret(key: "api-key", value: key)
        } catch {
            print("[OpenAICompatiblePlugin] Failed to store API key: \(error)")
        }
        host?.notifyCapabilitiesChanged()
    }

    func removeAPIKey() {
        do {
            try host?.storeSecret(key: "api-key", value: "")
        } catch {
            print("[OpenAICompatiblePlugin] Failed to remove API key: \(error)")
        }
        host?.notifyCapabilitiesChanged()
    }

    func selectModel(_ modelId: String) {
        host?.setUserDefault(modelId, forKey: "selectedModel")
    }

    func validateAPIKey(_ key: String, baseURL: String) async -> Bool {
        guard !key.isEmpty, !baseURL.isEmpty else { return false }
        guard let url = URL(string: "\(baseURL)/models") else { return false }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (_, response) = try await PluginHTTPClient.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }

    func setCustomBaseURL(_ url: String) {
        host?.setUserDefault(url, forKey: "customBaseURL")
    }

    var customBaseURL: String {
        host?.userDefault(forKey: "customBaseURL") as? String ?? ""
    }
}

// MARK: - Settings View

private struct OpenAICompatibleSettingsView: View {
    let plugin: OpenAICompatiblePlugin
    @State private var apiKeyInput = ""
    @State private var isValidating = false
    @State private var validationResult: Bool?
    @State private var showApiKey = false
    @State private var selectedPreset: ProviderPreset = .glm
    @State private var selectedModel = ""
    @State private var customURL = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Provider Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("LLM 提供商")
                    .font(.headline)

                Picker("提供商", selection: $selectedPreset) {
                    ForEach(ProviderPreset.allCases) { preset in
                        Label(preset.displayName, systemImage: preset.icon)
                            .tag(preset)
                    }
                }
                .labelsHidden()
                .onChange(of: selectedPreset) {
                    plugin.setActivePreset(selectedPreset)
                    validationResult = nil
                    loadState()
                }
            }

            // Custom Base URL (for custom preset)
            if selectedPreset.id == "custom" {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API 地址")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("https://api.example.com/v1", text: $customURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: customURL) {
                            plugin.setCustomBaseURL(customURL)
                        }
                }
            }

            Divider()

            // API Key
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    if showApiKey {
                        TextField("API Key", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("输入 API Key", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        showApiKey.toggle()
                    } label: {
                        Image(systemName: showApiKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)

                    if plugin.isAvailable {
                        Button("移除") {
                            apiKeyInput = ""
                            validationResult = nil
                            plugin.removeAPIKey()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundStyle(.red)
                    } else {
                        Button("保存") {
                            saveAPIKey()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if isValidating {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.small)
                        Text("验证中...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let result = validationResult {
                    HStack(spacing: 4) {
                        Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result ? .green : .red)
                        Text(result ? "有效" : "无效")
                            .font(.caption)
                            .foregroundStyle(result ? .green : .red)
                    }
                }
            }

            // Model Selection (only when configured)
            if plugin.isAvailable && !selectedPreset.models.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("模型")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker("模型", selection: $selectedModel) {
                        ForEach(selectedPreset.models, id: \.id) { model in
                            Text("\(model.displayName) (\(model.sizeDescription))").tag(model.id)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: selectedModel) {
                        plugin.selectModel(selectedModel)
                    }
                }
            }

            Spacer()

            Text("API Key 安全存储于系统钥匙串")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 360)
        .onAppear {
            loadState()
        }
    }

    private func loadState() {
        selectedPreset = plugin.activePreset
        apiKeyInput = plugin.currentAPIKey ?? ""
        selectedModel = plugin.selectedModelId ?? selectedPreset.models.first?.id ?? ""
        customURL = plugin.customBaseURL
    }

    private func saveAPIKey() {
        let trimmedKey = apiKeyInput.trimmingCharacters(in: .whitespaces)
        guard !trimmedKey.isEmpty else { return }

        plugin.saveAPIKey(trimmedKey)

        let baseURL = selectedPreset.id == "custom" ? customURL : selectedPreset.baseURL
        guard !baseURL.isEmpty else { return }

        isValidating = true
        validationResult = nil

        Task {
            let isValid = await plugin.validateAPIKey(trimmedKey, baseURL: baseURL)
            await MainActor.run {
                isValidating = false
                validationResult = isValid
            }
        }
    }
}
