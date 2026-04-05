import AppKit
import Foundation
import DavyWhisperPluginSDK

final class HostServicesImpl: HostServices, @unchecked Sendable {
    let pluginId: String
    let pluginDataDirectory: URL
    let eventBus: EventBusProtocol
    private let profileNamesProvider: () -> [String]
    private let credentialService: PluginCredentialService

    // Thread-safe cached values (avoid main actor hops for common accesses)
    private var _cachedApiKey: String?
    private var _cachedBaseURL: String?

    init(pluginId: String, eventBus: EventBusProtocol, profileNamesProvider: @escaping () -> [String], credentialService: PluginCredentialService) {
        self.pluginId = pluginId
        self.eventBus = eventBus
        self.profileNamesProvider = profileNamesProvider
        self.credentialService = credentialService

        self.pluginDataDirectory = AppConstants.appSupportDirectory
            .appendingPathComponent("PluginData", isDirectory: true)
            .appendingPathComponent(pluginId, isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: pluginDataDirectory, withIntermediateDirectories: true)

        // Load initial cache on main actor (after all members are initialized)
        Task { @MainActor in
            self._cachedApiKey = credentialService.getAPIKey(for: pluginId)
            self._cachedBaseURL = credentialService.getBaseURL(for: pluginId)
        }
    }

    // MARK: - Database-backed Credential Storage (replaces Keychain)

    func storeSecret(key: String, value: String) throws {
        // Store API key in database
        if key.hasSuffix("api-key") {
            Task { @MainActor in
                let baseURL = credentialService.getBaseURL(for: pluginId)
                credentialService.saveCredential(pluginId: pluginId, apiKey: value, baseURL: baseURL)
                self._cachedApiKey = value
                self._cachedBaseURL = baseURL
            }
            return
        }
        // For other keys, store in database with key suffix
        Task { @MainActor in
            let existingBaseURL = credentialService.getBaseURL(for: pluginId)
            credentialService.saveCredential(pluginId: pluginId, apiKey: "\(key)=\(value)", baseURL: existingBaseURL)
        }
    }

    func loadSecret(key: String) -> String? {
        // Load API key from database (using cached value)
        if key.hasSuffix("api-key") {
            return _cachedApiKey
        }
        // For other keys, parse from stored value
        guard let stored = _cachedApiKey,
              stored.hasPrefix("\(key)=") else { return nil }
        return String(stored.dropFirst(key.count + 1))
    }

    // MARK: - Database-backed BaseURL Storage

    func storeBaseURL(_ url: String) throws {
        Task { @MainActor in
            let existingKey = credentialService.getAPIKey(for: pluginId) ?? ""
            credentialService.saveCredential(pluginId: pluginId, apiKey: existingKey, baseURL: url)
            self._cachedBaseURL = url
        }
    }

    func loadBaseURL() -> String? {
        return _cachedBaseURL
    }

    // MARK: - UserDefaults (plugin-scoped)

    func userDefault(forKey key: String) -> Any? {
        UserDefaults.standard.object(forKey: "plugin.\(pluginId).\(key)")
    }

    func setUserDefault(_ value: Any?, forKey key: String) {
        UserDefaults.standard.set(value, forKey: "plugin.\(pluginId).\(key)")
    }

    // MARK: - App Context

    var activeAppBundleId: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    var activeAppName: String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }

    // MARK: - Profiles

    var availableProfileNames: [String] {
        profileNamesProvider()
    }

    // MARK: - Capabilities

    func notifyCapabilitiesChanged() {
        DispatchQueue.main.async {
            PluginManager.shared?.notifyPluginStateChanged()
        }
    }
}
