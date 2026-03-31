import Foundation
import SwiftUI
import DavyWhisperPluginSDK

// MARK: - GLM Plugin

@objc(GLMPlugin)
final class GLMPlugin: NSObject, LLMProviderPlugin, @unchecked Sendable {

    static let pluginId = "com.davywhisper.glm"
    static let pluginName = "GLM"

    private static let apiBaseURL = "https://open.bigmodel.cn/api/paas/v4"
    private static let chatEndpoint = "/chat/completions"
    private static let keychainKey = "com.davywhisper.glm.api-key"

    private var host: HostServices?
    private var _selectedModelId: String = "glm-4-flash"

    private let bundle = Bundle(for: GLMPlugin.self)

    override init() {
        super.init()
    }

    func activate(host: HostServices) {
        self.host = host
        _selectedModelId = host.userDefault(forKey: "selectedModel") as? String ?? Self.availableModels.first?.id ?? "glm-4-flash"
    }

    func deactivate() {
        host = nil
    }

    // MARK: - LLMProviderPlugin

    var providerName: String { "GLM (Zhipu AI)" }

    var isAvailable: Bool {
        guard let key = host?.loadSecret(key: Self.keychainKey), !key.isEmpty else { return false }
        return true
    }

    var supportedModels: [PluginModelInfo] {
        Self.availableModels
    }

    func process(systemPrompt: String, userText: String, model: String?) async throws -> String {
        guard let apiKey = host?.loadSecret(key: Self.keychainKey), !apiKey.isEmpty else {
            throw PluginChatError.notConfigured
        }

        let modelId = model ?? _selectedModelId
        let endpoint = "\(Self.apiBaseURL)\(Self.chatEndpoint)"
        guard let url = URL(string: endpoint) else {
            throw PluginChatError.apiError("Invalid URL: \(endpoint)")
        }

        let requestBody: [String: Any] = [
            "model": modelId,
            "tokens_to_generate": 1024,
            "temperature": 0.3,
            "messages": [
                ["sender_type": "SYSTEM", "text": systemPrompt],
                ["sender_type": "USER", "text": userText]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await PluginHTTPClient.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PluginChatError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw PluginChatError.invalidApiKey
        case 429:
            throw PluginChatError.rateLimited
        default:
            var displayMessage = "HTTP \(httpResponse.statusCode)"
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                displayMessage = message
            }
            throw PluginChatError.apiError(displayMessage)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let text = first["text"] as? String else {
            throw PluginChatError.apiError("Failed to parse GLM response")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Settings View

    var settingsView: AnyView? {
        AnyView(GLMSettingsView(plugin: self))
    }

    // MARK: - Available Models

    static let availableModels: [PluginModelInfo] = [
        PluginModelInfo(id: "glm-4-flash", displayName: "GLM-4 Flash", sizeDescription: "Fast & affordable"),
        PluginModelInfo(id: "glm-4", displayName: "GLM-4", sizeDescription: "Balanced performance"),
        PluginModelInfo(id: "glm-4-plus", displayName: "GLM-4 Plus", sizeDescription: "Highest quality"),
    ]

    // MARK: - API Key Management

    var selectedModelId: String {
        get { _selectedModelId }
        set {
            _selectedModelId = newValue
            host?.setUserDefault(newValue, forKey: "selectedModel")
        }
    }

    func setApiKey(_ key: String) {
        do {
            try host?.storeSecret(key: Self.keychainKey, value: key)
        } catch {
            // Silently fail; error is not critical for settings UI
        }
    }

    func removeApiKey() {
        // Keychain removal is not exposed in HostServices, so we store an empty sentinel
        host?.setUserDefault("", forKey: Self.keychainKey)
    }

    func validateApiKey(_ key: String) async -> Bool {
        guard !key.isEmpty else { return false }
        let endpoint = "\(Self.apiBaseURL)/v1/models"
        guard let url = URL(string: endpoint) else { return false }

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
}

// MARK: - Settings View

private struct GLMSettingsView: View {
    let plugin: GLMPlugin
    private let bundle = Bundle(for: GLMPlugin.self)

    @State private var apiKeyInput: String = ""
    @State private var selectedModel: String = "glm-4-flash"
    @State private var validationState: ValidationState = .idle

    @State private var isSaving = false

    enum ValidationState: Equatable {
        case idle
        case validating
        case valid
        case invalid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GLM (Zhipu AI)")
                .font(.headline)

            Text("LLM provider via Zhipu AI (GLM) API. Requires API key.", bundle: bundle)
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            // API Key Section
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key", bundle: bundle)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    SecureField(String(localized: "Enter your GLM API key", bundle: bundle), text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: apiKeyInput) { _, _ in
                            if validationState != .idle {
                                validationState = .idle
                            }
                        }

                    Button(String(localized: "Validate", bundle: bundle)) {
                        Task { await validateKey() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(apiKeyInput.isEmpty || validationState == .validating)
                }

                HStack(spacing: 8) {
                    switch validationState {
                    case .idle:
                        EmptyView()
                    case .validating:
                        ProgressView()
                            .controlSize(.small)
                        Text(String(localized: "Validating...", bundle: bundle))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .valid:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(String(localized: "Valid", bundle: bundle))
                            .font(.caption)
                            .foregroundStyle(.green)
                    case .invalid:
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(String(localized: "Invalid", bundle: bundle))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Spacer()

                    Button(String(localized: "Save", bundle: bundle)) {
                        saveApiKey()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(apiKeyInput.isEmpty || isSaving)

                    Button(String(localized: "Remove", bundle: bundle)) {
                        removeApiKey()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(apiKeyInput.isEmpty || isSaving)
                }
            }

            Divider()

            // Model Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Model", bundle: bundle)
                    .font(.subheadline)
                    .fontWeight(.medium)

                ForEach(GLMPlugin.availableModels, id: \.id) { modelInfo in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(modelInfo.displayName)
                                .font(.body)
                            if !modelInfo.sizeDescription.isEmpty {
                                Text(modelInfo.sizeDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if selectedModel == modelInfo.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedModel = modelInfo.id
                        plugin.selectedModelId = modelInfo.id
                    }
                    .padding(.vertical, 4)
                }
            }

            Spacer()
        }
        .padding()
        .frame(width: 320, height: 420)
        .onAppear {
            selectedModel = plugin.selectedModelId
        }
    }

    private func validateKey() {
        validationState = .validating
        Task {
            let ok = await plugin.validateApiKey(apiKeyInput)
            await MainActor.run {
                validationState = ok ? .valid : .invalid
            }
        }
    }

    private func saveApiKey() {
        guard !apiKeyInput.isEmpty else { return }
        isSaving = true
        plugin.setApiKey(apiKeyInput)
        isSaving = false
    }

    private func removeApiKey() {
        plugin.removeApiKey()
        apiKeyInput = ""
        validationState = .idle
    }
}
