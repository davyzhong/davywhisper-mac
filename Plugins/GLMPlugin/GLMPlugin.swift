import Foundation
import SwiftUI
import DavyWhisperPluginSDK

@objc(GLMPlugin)
final class GLMPlugin: NSObject, LLMProviderPlugin, @unchecked Sendable {
    static let pluginId = "com.davywhisper.glm"
    static let pluginName = "GLM"

    private var host: HostServices?
    private var _selectedModelId: String?

    // MARK: - Provider Config (now user-configurable)
    private let baseURLKey = "glm-base-url"
    private let defaultBaseURL = "https://open.bigmodel.cn/api/coding/paas/v4"
    private let apiKeyKeychainKey = "glm-api-key"
    private let modelKey = "glm-selected-model"

    // Common models for suggestion (includes Coding Plan)
    private let suggestedModels: [PluginModelInfo] = [
        PluginModelInfo(id: "glm-4-flash", displayName: "GLM-4 Flash", sizeDescription: "Fast", languageCount: 1),
        PluginModelInfo(id: "glm-4-air", displayName: "GLM-4 Air", sizeDescription: "Balanced", languageCount: 1),
        PluginModelInfo(id: "glm-4-plus", displayName: "GLM-4 Plus", sizeDescription: "Advanced", languageCount: 1),
        PluginModelInfo(id: "glm-4-long", displayName: "GLM-4 Long", sizeDescription: "Long context", languageCount: 1),
        // Coding Plan models
        PluginModelInfo(id: "glm-5-flash", displayName: "GLM-5 Flash (Coding Plan)", sizeDescription: "Latest", languageCount: 1),
        PluginModelInfo(id: "glm-5-air", displayName: "GLM-5 Air (Coding Plan)", sizeDescription: "Latest", languageCount: 1),
        PluginModelInfo(id: "glm-5-plus", displayName: "GLM-5 Plus (Coding Plan)", sizeDescription: "Latest", languageCount: 1),
    ]

    required override init() { super.init() }

    func activate(host: HostServices) {
        self.host = host
        _selectedModelId = host.userDefault(forKey: modelKey) as? String
    }

    func deactivate() { host = nil }

    // MARK: - LLMProviderPlugin

    var providerName: String { "GLM (Zhipu AI)" }

    var isAvailable: Bool { currentAPIKey != nil && !currentBaseURL.isEmpty }

    var supportedModels: [PluginModelInfo] { suggestedModels }

    var selectedModelId: String? { _selectedModelId }

    var settingsView: AnyView? { AnyView(GLMSettingsView(plugin: self)) }

    func selectModel(_ modelId: String) {
        _selectedModelId = modelId
        host?.setUserDefault(modelId, forKey: modelKey)
    }

    func process(systemPrompt: String, userText: String, model: String?) async throws -> String {
        guard let apiKey = currentAPIKey else {
            throw PluginChatError.notConfigured
        }
        let helper = PluginOpenAIChatHelper(baseURL: currentBaseURL)
        let modelId = model ?? _selectedModelId ?? "glm-4-flash"
        return try await helper.process(apiKey: apiKey, model: modelId, systemPrompt: systemPrompt, userText: userText)
    }

    // MARK: - Configuration Access

    var currentBaseURL: String {
        host?.loadBaseURL() as? String ?? defaultBaseURL
    }

    func saveBaseURL(_ url: String) {
        try? host?.storeBaseURL(url)
    }

    // MARK: - Keychain (deprecated - using database storage)

    var currentAPIKey: String? { host?.loadSecret(key: apiKeyKeychainKey) }

    func saveAPIKey(_ key: String) throws {
        try host?.storeSecret(key: apiKeyKeychainKey, value: key)
    }

    // MARK: - Connection Test (baseURL + API key only, no model required)

    func testConnection() async throws {
        guard let apiKey = currentAPIKey else {
            throw PluginChatError.notConfigured
        }
        let helper = PluginOpenAIChatHelper(baseURL: currentBaseURL)
        // Use a minimal test request with a common model
        _ = try await helper.process(apiKey: apiKey, model: "glm-4-flash", systemPrompt: "test", userText: "hi")
    }
}

// MARK: - Settings View

private struct GLMSettingsView: View {
    let plugin: GLMPlugin
    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    @State private var selectedModelId: String?
    @State private var customModelId: String = ""
    @State private var useCustomModel: Bool = false
    @State private var isValidating = false
    @State private var isTestingConnection = false
    @State private var validationResult: ValidationResult?

    private enum ValidationResult {
        case valid, invalid(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GLM (智谱清言)")
                .font(.headline)

            Text("智谱 AI 大语言模型。支持 GLM-4/GLM-5 系列，包括 Coding Plan。")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            // Base URL Configuration
            VStack(alignment: .leading, spacing: 6) {
                Text("Base URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("https://open.bigmodel.cn/api/coding/paas/v4", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
                    .onAppear { baseURL = plugin.currentBaseURL }
                    .onChange(of: baseURL) { _, newValue in
                        plugin.saveBaseURL(newValue)
                    }
                Text("常用地址:")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                + Text(" https://open.bigmodel.cn/api/coding/paas/v4 (Coding Plan)")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                + Text(" | ")
                    .font(.caption2)
                + Text("https://open.bigmodel.cn/api/paas/v4 (通用 API)")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }

            // API Key
            SecureField("API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .onAppear { apiKey = plugin.currentAPIKey ?? "" }

            // Test Connection Button (baseURL + API key only)
            HStack {
                Button("测试连接") {
                    testConnectionOnly()
                }
                .disabled(baseURL.isEmpty || apiKey.isEmpty || isTestingConnection)
                if isTestingConnection { ProgressView().controlSize(.small) }
                if let result = validationResult, case .valid = result {
                    Label("连接成功", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }

            // Validate & Save Button
            HStack {
                Button("验证并保存") { validateKey() }
                    .disabled(apiKey.isEmpty || isValidating)
                if isValidating { ProgressView().controlSize(.small) }
                if let result = validationResult {
                    switch result {
                    case .valid:
                        Label("API Key 有效", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    case .invalid(let msg):
                        Label(msg, systemImage: "xmark.circle.fill").foregroundStyle(.red).font(.caption)
                    }
                }
            }

            Divider()

            // Model Selection
            Toggle("自定义模型", isOn: $useCustomModel)
                .toggleStyle(.switch)

            if useCustomModel {
                TextField("输入模型 ID (如：glm-5-plus)", text: $customModelId)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: customModelId) { _, newValue in
                        if !newValue.isEmpty { plugin.selectModel(newValue) }
                    }
            } else {
                Picker("推荐模型", selection: $selectedModelId) {
                    ForEach(plugin.supportedModels, id: \.id) { model in
                        Text(model.displayName).tag(model.id as String?)
                    }
                }
                .onChange(of: selectedModelId) { _, newValue in
                    if let modelId = newValue { plugin.selectModel(modelId) }
                }
                .onAppear {
                    selectedModelId = plugin.selectedModelId
                    customModelId = plugin.selectedModelId ?? ""
                    useCustomModel = plugin.selectedModelId != nil && !plugin.supportedModels.contains { $0.id == plugin.selectedModelId }
                }
            }
        }
        .padding()
    }

    private func testConnectionOnly() {
        guard !baseURL.isEmpty, !apiKey.isEmpty else { return }
        isTestingConnection = true
        validationResult = nil
        Task {
            do {
                try plugin.saveAPIKey(apiKey)
                plugin.saveBaseURL(baseURL)
                try await plugin.testConnection()
                validationResult = .valid
            } catch {
                validationResult = .invalid(error.localizedDescription)
            }
            isTestingConnection = false
        }
    }

    private func validateKey() {
        guard !apiKey.isEmpty else { return }
        isValidating = true
        validationResult = nil
        Task {
            do {
                try plugin.saveAPIKey(apiKey)
                plugin.saveBaseURL(baseURL)
                let modelId = useCustomModel ? customModelId : selectedModelId
                let _ = try await plugin.process(systemPrompt: "你是 DavyWhisper 助手，请简短回复。", userText: "你好，请用一句话介绍你自己。", model: modelId)
                validationResult = .valid
            } catch {
                validationResult = .invalid(error.localizedDescription)
            }
            isValidating = false
        }
    }
}
