import Foundation
import SwiftUI
import DavyWhisperPluginSDK

// MARK: - Plugin Entry Point

@objc(QwenLLMPlugin)
final class QwenLLMPlugin: NSObject, LLMProviderPlugin, @unchecked Sendable {
    static let pluginId = "com.davywhisper.qwen"
    static let pluginName = "Qwen"

    fileprivate var host: HostServices?
    fileprivate var _apiKey: String?
    fileprivate var _selectedModelId: String?

    private let chatHelper = PluginOpenAIChatHelper(
        baseURL: "https://dashscope.aliyuncs.com/compatible-mode",
        chatEndpoint: "/v1/chat/completions"
    )

    private static let availableModels: [PluginModelInfo] = [
        PluginModelInfo(id: "qwen-plus", displayName: "Qwen Plus"),
        PluginModelInfo(id: "qwen-plus-latest", displayName: "Qwen Plus Latest"),
        PluginModelInfo(id: "qwen-max", displayName: "Qwen Max"),
        PluginModelInfo(id: "qwen-max-latest", displayName: "Qwen Max Latest"),
        PluginModelInfo(id: "qwen-flash", displayName: "Qwen Flash"),
    ]

    required override init() {
        super.init()
    }

    func activate(host: HostServices) {
        self.host = host
        _apiKey = host.loadSecret(key: "api-key")
        _selectedModelId = host.userDefault(forKey: "selectedModel") as? String
            ?? Self.availableModels.first?.id
    }

    func deactivate() {
        host = nil
    }

    // MARK: - LLMProviderPlugin

    var providerName: String { "Qwen" }

    var isAvailable: Bool { isConfigured }

    var isConfigured: Bool {
        guard let key = _apiKey else { return false }
        return !key.isEmpty
    }

    var supportedModels: [PluginModelInfo] { Self.availableModels }

    func process(systemPrompt: String, userText: String, model: String?) async throws -> String {
        guard let apiKey = _apiKey, !apiKey.isEmpty else {
            throw PluginChatError.notConfigured
        }

        let modelId = model ?? _selectedModelId ?? Self.availableModels.first?.id ?? "qwen-plus"

        return try await chatHelper.process(
            apiKey: apiKey,
            model: modelId,
            systemPrompt: systemPrompt,
            userText: userText
        )
    }

    // MARK: - API Key Management

    fileprivate func validateApiKey(_ key: String) async -> Bool {
        guard !key.isEmpty else { return false }
        guard let url = URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/models") else { return false }

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

    fileprivate func setApiKey(_ key: String) {
        _apiKey = key
        if let host {
            do {
                try host.storeSecret(key: "api-key", value: key)
            } catch {
                print("[QwenLLMPlugin] Failed to store API key: \(error)")
            }
            host.notifyCapabilitiesChanged()
        }
    }

    fileprivate func removeApiKey() {
        _apiKey = nil
        if let host {
            do {
                try host.storeSecret(key: "api-key", value: "")
            } catch {
                print("[QwenLLMPlugin] Failed to delete API key: \(error)")
            }
            host.notifyCapabilitiesChanged()
        }
    }

    fileprivate func selectModel(_ modelId: String) {
        _selectedModelId = modelId
        host?.setUserDefault(modelId, forKey: "selectedModel")
    }

    // MARK: - Settings View

    var settingsView: AnyView? {
        AnyView(QwenSettingsView(plugin: self))
    }
}

// MARK: - Settings View

private struct QwenSettingsView: View {
    let plugin: QwenLLMPlugin
    @State private var apiKeyInput = ""
    @State private var isValidating = false
    @State private var validationResult: Bool?
    @State private var showApiKey = false
    @State private var selectedModel = ""
    private let bundle = Bundle(for: QwenLLMPlugin.self)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key", bundle: bundle)
                    .font(.headline)

                HStack(spacing: 8) {
                    if showApiKey {
                        TextField(String(localized: "Enter your Qwen API key", bundle: bundle), text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField(String(localized: "Enter your Qwen API key", bundle: bundle), text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        showApiKey.toggle()
                    } label: {
                        Image(systemName: showApiKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)

                    if plugin.isConfigured {
                        Button(String(localized: "Remove", bundle: bundle)) {
                            apiKeyInput = ""
                            validationResult = nil
                            plugin.removeApiKey()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundStyle(.red)
                    } else {
                        Button(String(localized: "Save", bundle: bundle)) {
                            saveApiKey()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if isValidating {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.small)
                        Text(String(localized: "Validating...", bundle: bundle))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let result = validationResult {
                    HStack(spacing: 4) {
                        Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result ? .green : .red)
                        Text(
                            result
                                ? String(localized: "Valid", bundle: bundle)
                                : String(localized: "Invalid", bundle: bundle)
                        )
                        .font(.caption)
                        .foregroundStyle(result ? .green : .red)
                    }
                }
            }

            if plugin.isConfigured {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Model", bundle: bundle)
                        .font(.headline)

                    Picker("Model", selection: $selectedModel) {
                        ForEach(plugin.supportedModels, id: \.id) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: selectedModel) {
                        plugin.selectModel(selectedModel)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            if let key = plugin._apiKey, !key.isEmpty {
                apiKeyInput = key
            }
            selectedModel = plugin._selectedModelId ?? plugin.supportedModels.first?.id ?? ""
        }
    }

    private func saveApiKey() {
        let trimmedKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }

        plugin.setApiKey(trimmedKey)

        isValidating = true
        validationResult = nil

        Task {
            let isValid = await plugin.validateApiKey(trimmedKey)
            await MainActor.run {
                isValidating = false
                validationResult = isValid
            }
        }
    }
}
