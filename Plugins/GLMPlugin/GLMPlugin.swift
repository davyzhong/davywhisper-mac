import Foundation
import SwiftUI
import DavyWhisperPluginSDK

@objc(GLMPlugin)
final class GLMPlugin: NSObject, LLMProviderPlugin, @unchecked Sendable {
    static let pluginId = "com.davywhisper.glm"
    static let pluginName = "GLM"

    private var host: HostServices?
    private var _selectedModelId: String?

    // MARK: - Provider Config
    private let baseURL = "https://open.bigmodel.cn/api/paas/v4"
    private let apiKeyKeychainKey = "glm-api-key"
    private let modelKey = "glm-selected-model"

    private let models: [PluginModelInfo] = [
        PluginModelInfo(id: "glm-4-flash", displayName: "GLM-4 Flash", sizeDescription: "Fast", languageCount: 1),
        PluginModelInfo(id: "glm-4-air", displayName: "GLM-4 Air", sizeDescription: "Balanced", languageCount: 1),
        PluginModelInfo(id: "glm-4-plus", displayName: "GLM-4 Plus", sizeDescription: "Advanced", languageCount: 1),
        PluginModelInfo(id: "glm-4-long", displayName: "GLM-4 Long", sizeDescription: "Long context", languageCount: 1)
    ]

    required override init() { super.init() }

    func activate(host: HostServices) {
        self.host = host
        _selectedModelId = host.userDefault(forKey: modelKey) as? String ?? models.first?.id
    }

    func deactivate() { host = nil }

    // MARK: - LLMProviderPlugin

    var providerName: String { "GLM (Zhipu AI)" }

    var isAvailable: Bool { currentAPIKey != nil }

    var supportedModels: [PluginModelInfo] { models }

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
        let helper = PluginOpenAIChatHelper(baseURL: baseURL)
        let modelId = model ?? _selectedModelId ?? models.first?.id ?? "glm-4-flash"
        return try await helper.process(apiKey: apiKey, model: modelId, systemPrompt: systemPrompt, userText: userText)
    }

    // MARK: - Keychain

    var currentAPIKey: String? { host?.loadSecret(key: apiKeyKeychainKey) }

    func saveAPIKey(_ key: String) throws {
        try host?.storeSecret(key: apiKeyKeychainKey, value: key)
    }
}

// MARK: - Settings View

private struct GLMSettingsView: View {
    let plugin: GLMPlugin
    @State private var apiKey: String = ""
    @State private var selectedModelId: String?
    @State private var isValidating = false
    @State private var validationResult: ValidationResult?

    private enum ValidationResult {
        case valid, invalid(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GLM (智谱清言)")
                .font(.headline)

            Text("智谱 AI 大语言模型。支持 GLM-4 系列模型，中文能力强。")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            // API Key
            SecureField("API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .onAppear { apiKey = plugin.currentAPIKey ?? "" }

            HStack {
                Button("验证") {
                    validateKey()
                }
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

            // Model Selection
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
