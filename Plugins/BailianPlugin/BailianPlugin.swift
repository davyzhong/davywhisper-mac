import Foundation
import SwiftUI
import DavyWhisperPluginSDK

@objc(BailianPlugin)
final class BailianPlugin: NSObject, LLMProviderPlugin, @unchecked Sendable {
    static let pluginId = "com.davywhisper.bailian"
    static let pluginName = "Bailian"

    private var host: HostServices?
    private var _selectedModelId: String?

    // MARK: - Provider Config
    // 阿里云百炼 DashScope OpenAI 兼容接口
    private let baseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    private let apiKeyKeychainKey = "bailian-api-key"
    private let modelKey = "bailian-selected-model"

    private let models: [PluginModelInfo] = [
        PluginModelInfo(id: "qwen-plus", displayName: "Qwen Plus", sizeDescription: "Balanced", languageCount: 1),
        PluginModelInfo(id: "qwen-turbo", displayName: "Qwen Turbo", sizeDescription: "Fast", languageCount: 1),
        PluginModelInfo(id: "qwen-max", displayName: "Qwen Max", sizeDescription: "Advanced", languageCount: 1),
        PluginModelInfo(id: "qwen-long", displayName: "Qwen Long", sizeDescription: "Long context", languageCount: 1)
    ]

    required override init() { super.init() }

    func activate(host: HostServices) {
        self.host = host
        _selectedModelId = host.userDefault(forKey: modelKey) as? String ?? models.first?.id
    }

    func deactivate() { host = nil }

    // MARK: - LLMProviderPlugin

    var providerName: String { "Bailian (Aliyun DashScope)" }

    var isAvailable: Bool { currentAPIKey != nil }

    var supportedModels: [PluginModelInfo] { models }

    var selectedModelId: String? { _selectedModelId }

    var settingsView: AnyView? { AnyView(BailianSettingsView(plugin: self)) }

    func selectModel(_ modelId: String) {
        _selectedModelId = modelId
        host?.setUserDefault(modelId, forKey: modelKey)
    }

    func process(systemPrompt: String, userText: String, model: String?) async throws -> String {
        guard let apiKey = currentAPIKey else {
            throw PluginChatError.notConfigured
        }
        let helper = PluginOpenAIChatHelper(baseURL: baseURL)
        let modelId = model ?? _selectedModelId ?? models.first?.id ?? "qwen-plus"
        return try await helper.process(apiKey: apiKey, model: modelId, systemPrompt: systemPrompt, userText: userText)
    }

    // MARK: - Keychain

    var currentAPIKey: String? { host?.loadSecret(key: apiKeyKeychainKey) }

    func saveAPIKey(_ key: String) throws {
        try host?.storeSecret(key: apiKeyKeychainKey, value: key)
    }
}

// MARK: - Settings View

private struct BailianSettingsView: View {
    let plugin: BailianPlugin
    @State private var apiKey: String = ""
    @State private var selectedModelId: String?
    @State private var isValidating = false
    @State private var validationResult: ValidationResult?

    private enum ValidationResult {
        case valid, invalid(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("百炼 (阿里云 DashScope)")
                .font(.headline)

            Text("阿里云百炼平台大语言模型。支持通义千问 Qwen 系列，OpenAI 兼容接口。")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            SecureField("API Key (DashScope)", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .onAppear { apiKey = plugin.currentAPIKey ?? "" }

            HStack {
                Button("验证") { validateKey() }
                    .disabled(apiKey.isEmpty || isValidating)
                if isValidating { ProgressView().controlSize(.small) }
                if let result = validationResult {
                    switch result {
                    case .valid:
                        Label("有效", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    case .invalid(let msg):
                        Label(msg, systemImage: "xmark.circle.fill").foregroundStyle(.red).font(.caption)
                    }
                }
            }

            Picker("模型", selection: $selectedModelId) {
                ForEach(plugin.supportedModels, id: \.id) { model in
                    Text(model.displayName).tag(model.id as String?)
                }
            }
            .onAppear { selectedModelId = plugin.selectedModelId }
            .onChange(of: selectedModelId) { _, newValue in
                if let modelId = newValue { plugin.selectModel(modelId) }
            }
        }
        .padding()
    }

    private func validateKey() {
        guard !apiKey.isEmpty else { return }
        isValidating = true
        validationResult = nil
        Task {
            do {
                try plugin.saveAPIKey(apiKey)
                let _ = try await plugin.process(systemPrompt: "Hi", userText: "test", model: plugin.supportedModels.first?.id)
                validationResult = .valid
            } catch {
                validationResult = .invalid(error.localizedDescription)
            }
            isValidating = false
        }
    }
}
