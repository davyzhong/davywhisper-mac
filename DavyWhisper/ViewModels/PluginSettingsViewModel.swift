import Foundation
import DavyWhisperPluginSDK

/// Manages plugin settings state: grouping, filtering, and install/uninstall orchestration.
/// Extracted from PluginSettingsView to enable unit testing.
@MainActor
final class PluginSettingsViewModel: ObservableObject {

    // MARK: - Dependencies

    private let pluginManager: PluginManager
    private let registryService: PluginRegistryService

    // MARK: - Init

    init(
        pluginManager: PluginManager = PluginManager.shared,
        registryService: PluginRegistryService = PluginRegistryService.shared
    ) {
        self.pluginManager = pluginManager
        self.registryService = registryService
    }

    // MARK: - Plugin Categorization

    func categoryForPlugin(_ plugin: LoadedPlugin) -> PluginCategory {
        if let regPlugin = registryService.registry.first(where: { $0.id == plugin.id }) {
            return PluginCategory(rawValue: regPlugin.category) ?? .utility
        }
        if plugin.instance is TranscriptionEnginePlugin { return .transcription }
        if plugin.instance is LLMProviderPlugin { return .llm }
        return .utility
    }

    // MARK: - Grouped Installed Plugins

    var groupedInstalledPlugins: [(category: PluginCategory, plugins: [LoadedPlugin])] {
        let grouped = Dictionary(grouping: pluginManager.loadedPlugins) { categoryForPlugin($0) }
        return grouped
            .sorted { $0.key.sortOrder < $1.key.sortOrder }
            .map { (category: $0.key, plugins: $0.value.sorted { $0.manifest.name.localizedCompare($1.manifest.name) == .orderedAscending }) }
    }

    // MARK: - Available Plugin Filtering

    func filteredAvailablePlugins(hostingFilter: Int) -> [RegistryPlugin] {
        let available = registryService.registry.filter { registryPlugin in
            let info = registryService.installInfo(for: registryPlugin.id)
            if case .notInstalled = info { return true }
            return false
        }
        switch hostingFilter {
        case 1: return available.filter { $0.requiresAPIKey != true }
        case 2: return available.filter { $0.requiresAPIKey == true }
        default: return available
        }
    }

    func groupedAvailablePlugins(hostingFilter: Int) -> [(category: PluginCategory, plugins: [RegistryPlugin])] {
        let filtered = filteredAvailablePlugins(hostingFilter: hostingFilter)
        let grouped = Dictionary(grouping: filtered) { plugin in
            PluginCategory(rawValue: plugin.category) ?? .utility
        }
        return grouped
            .sorted { $0.key.sortOrder < $1.key.sortOrder }
            .map { (category: $0.key, plugins: $0.value.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }) }
    }

    // MARK: - Install / Uninstall

    func installPlugin(_ registryPlugin: RegistryPlugin) async {
        await registryService.downloadAndInstall(registryPlugin)
        pluginManager.setPluginEnabled(registryPlugin.id, enabled: true)
    }

    func uninstallPlugin(_ pluginId: String) {
        registryService.uninstallPlugin(pluginId, deleteData: true)
    }

    func installFromFile(_ url: URL) async throws {
        try await registryService.installFromFile(url)
    }

    func updatePlugin(_ pluginId: String) async {
        guard let registryPlugin = registryService.registry.first(where: { $0.id == pluginId }) else { return }
        await registryService.downloadAndInstall(registryPlugin)
    }

    // MARK: - Toggle

    func setPluginEnabled(_ pluginId: String, enabled: Bool) {
        pluginManager.setPluginEnabled(pluginId, enabled: enabled)
    }

    // MARK: - Registry

    func fetchRegistry() async {
        await registryService.fetchRegistry()
    }

    func installInfo(for pluginId: String) -> PluginInstallInfo {
        registryService.installInfo(for: pluginId)
    }

    func installState(for pluginId: String) -> PluginRegistryService.InstallState? {
        registryService.installStates[pluginId]
    }

    func registryPlugin(for pluginId: String) -> RegistryPlugin? {
        registryService.registry.first(where: { $0.id == pluginId })
    }

    // MARK: - Helpers

    func openPluginsFolder() {
        pluginManager.openPluginsFolder()
    }
}
