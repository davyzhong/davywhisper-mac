import AppKit
import Foundation
import DavyWhisperPluginSDK
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DavyWhisper", category: "PluginManager")

// MARK: - Loaded Plugin

struct LoadedPlugin: Identifiable {
    let manifest: PluginManifest
    let instance: DavyWhisperPlugin
    let bundle: Bundle
    let sourceURL: URL
    var isEnabled: Bool

    var id: String { manifest.id }

    var isBundled: Bool {
        // Compiled-in plugins are always bundled
        if bundle == Bundle.main { return true }
        let builtInPrefix = Bundle.main.builtInPlugInsURL?.path
        let resourcePrefix = Bundle.main.resourceURL?.path
        return (builtInPrefix.map { sourceURL.path.hasPrefix($0) } ?? false)
            || (resourcePrefix.map { sourceURL.path.hasPrefix($0) } ?? false)
    }
}

// MARK: - Plugin Manager

@MainActor
final class PluginManager: ObservableObject {
    nonisolated(unsafe) static var shared: PluginManager!

    @Published var loadedPlugins: [LoadedPlugin] = []

    let pluginsDirectory: URL
    private var profileNamesProvider: () -> [String] = { [] }

    var postProcessors: [PostProcessorPlugin] {
        loadedPlugins
            .filter { $0.isEnabled }
            .compactMap { $0.instance as? PostProcessorPlugin }
            .sorted { $0.priority < $1.priority }
    }

    var llmProviders: [LLMProviderPlugin] {
        loadedPlugins
            .filter { $0.isEnabled }
            .compactMap { $0.instance as? LLMProviderPlugin }
    }

    var transcriptionEngines: [TranscriptionEnginePlugin] {
        loadedPlugins
            .filter { $0.isEnabled }
            .compactMap { $0.instance as? TranscriptionEnginePlugin }
    }

    var actionPlugins: [ActionPlugin] {
        loadedPlugins
            .filter { $0.isEnabled }
            .compactMap { $0.instance as? ActionPlugin }
    }

    var memoryStoragePlugins: [MemoryStoragePlugin] {
        loadedPlugins
            .filter { $0.isEnabled }
            .compactMap { $0.instance as? MemoryStoragePlugin }
    }

    func transcriptionEngine(for providerId: String) -> TranscriptionEnginePlugin? {
        transcriptionEngines.first { $0.providerId == providerId }
    }

    func actionPlugin(for actionId: String) -> ActionPlugin? {
        actionPlugins.first { $0.actionId == actionId }
    }

    func llmProvider(for providerName: String) -> LLMProviderPlugin? {
        llmProviders.first { $0.providerName.caseInsensitiveCompare(providerName) == .orderedSame }
    }

    init(appSupportDirectory: URL = AppConstants.appSupportDirectory) {
        self.pluginsDirectory = appSupportDirectory
            .appendingPathComponent("Plugins", isDirectory: true)

        try? FileManager.default.createDirectory(at: pluginsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Plugin Loading

    func scanAndLoadPlugins() {
        // 1. Load compiled-in plugins (Swift code compiled into main app, manifest.json in Resources)
        loadCompiledPlugins()

        // 2. Load dynamic plugins from user's Plugins directory
        let fm = FileManager.default
        if let contents = try? fm.contentsOfDirectory(at: pluginsDirectory, includingPropertiesForKeys: nil) {
            let bundles = contents.filter { $0.pathExtension == "bundle" }
            logger.info("Found \(bundles.count) user plugin bundle(s)")
            for bundleURL in bundles {
                loadPlugin(at: bundleURL)
            }
        }

        // 3. Load dynamic plugins from PlugIns/ directory
        if let builtInURL = Bundle.main.builtInPlugInsURL,
           let builtIn = try? fm.contentsOfDirectory(at: builtInURL, includingPropertiesForKeys: nil) {
            let builtInBundles = builtIn.filter { $0.pathExtension == "bundle" }
            if !builtInBundles.isEmpty {
                logger.info("Found \(builtInBundles.count) PlugIns/ bundle(s)")
                for bundleURL in builtInBundles {
                    loadPlugin(at: bundleURL)
                }
            }
        }
    }

    /// Load plugins whose Swift code is compiled directly into the main app binary.
    /// Scans for manifest.json files in the app's Resources to discover compiled-in plugins.
    private func loadCompiledPlugins() {
        guard let resourceURL = Bundle.main.resourceURL else { return }

        let pluginNames = ["WhisperKitPlugin", "DeepgramPlugin",
                          "ElevenLabsPlugin", "LiveTranscriptPlugin",
                          "GLMPlugin", "KimiPlugin", "MiniMaxPlugin", "QwenLLMPlugin",
                          "ParaformerPlugin"]

        for name in pluginNames {
            // Compiled-in plugins have manifest_<PluginName>.json in Resources/
            let manifestURL = resourceURL.appendingPathComponent("manifest_\(name).json")
            guard let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? JSONDecoder().decode(PluginManifest.self, from: data) else {
                continue
            }
            loadCompiledPlugin(manifest: manifest, manifestURL: manifestURL)
        }
    }

    private func loadCompiledPlugin(manifest: PluginManifest, manifestURL: URL) {
        guard !loadedPlugins.contains(where: { $0.manifest.id == manifest.id }) else {
            logger.warning("Plugin \(manifest.id) already loaded, skipping")
            return
        }

        // Try bare @objc name first (plugins use @objc(ClassName)), then module-prefixed
        let pluginClass = NSClassFromString(manifest.principalClass) as? DavyWhisperPlugin.Type
            ?? NSClassFromString("DavyWhisper.\(manifest.principalClass)") as? DavyWhisperPlugin.Type

        guard let pluginClass else {
            logger.error("Failed to find class \(manifest.principalClass) for compiled plugin \(manifest.name)")
            return
        }

        let instance = pluginClass.init()

        // Auto-enable compiled-in plugins
        let enabledKey = "plugin.\(manifest.id).enabled"
        let isEnabled = (UserDefaults.standard.object(forKey: enabledKey) as? Bool) ?? true
        if UserDefaults.standard.object(forKey: enabledKey) == nil {
            UserDefaults.standard.set(true, forKey: enabledKey)
        }

        let loaded = LoadedPlugin(
            manifest: manifest,
            instance: instance,
            bundle: Bundle.main,
            sourceURL: manifestURL,
            isEnabled: isEnabled
        )
        loadedPlugins.append(loaded)

        if isEnabled {
            activatePlugin(loaded)
        }

        logger.info("Loaded compiled plugin: \(manifest.name) v\(manifest.version)")
    }

    func loadPlugin(at url: URL) {
        let manifestURL = url.appendingPathComponent("Contents/Resources/manifest.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(PluginManifest.self, from: data) else {
            logger.error("Failed to read manifest from \(url.lastPathComponent)")
            return
        }

        guard !loadedPlugins.contains(where: { $0.manifest.id == manifest.id }) else {
            logger.warning("Plugin \(manifest.id) already loaded, skipping")
            return
        }

        guard let bundle = Bundle(url: url) else {
            logger.error("Failed to create Bundle for \(url.lastPathComponent)")
            return
        }

        do {
            try bundle.loadAndReturnError()
        } catch {
            logger.error("Failed to load bundle \(url.lastPathComponent): \(error.localizedDescription)")
            return
        }

        guard let pluginClass = NSClassFromString(manifest.principalClass) as? DavyWhisperPlugin.Type else {
            logger.error("Failed to find class \(manifest.principalClass) in \(url.lastPathComponent)")
            return
        }

        let instance = pluginClass.init()

        let enabledKey = "plugin.\(manifest.id).enabled"
        let isEnabled: Bool
        if let stored = UserDefaults.standard.object(forKey: enabledKey) as? Bool {
            isEnabled = stored
        } else {
            let builtInPrefix = Bundle.main.builtInPlugInsURL?.path
            let resourcePrefix = Bundle.main.resourceURL?.path
            let isBundled = (builtInPrefix.map { url.path.hasPrefix($0) } ?? false)
                || (resourcePrefix.map { url.path.hasPrefix($0) } ?? false)
            isEnabled = isBundled
            if isBundled {
                UserDefaults.standard.set(true, forKey: enabledKey)
            }
        }

        let loaded = LoadedPlugin(
            manifest: manifest, instance: instance, bundle: bundle, sourceURL: url, isEnabled: isEnabled
        )
        loadedPlugins.append(loaded)

        if isEnabled {
            activatePlugin(loaded)
        }

        logger.info("Loaded plugin: \(manifest.name) v\(manifest.version)")
    }

    func setProfileNamesProvider(_ provider: @escaping () -> [String]) {
        self.profileNamesProvider = provider
    }

    private func activatePlugin(_ plugin: LoadedPlugin) {
        let host = HostServicesImpl(pluginId: plugin.manifest.id, eventBus: EventBus.shared, profileNamesProvider: profileNamesProvider)
        plugin.instance.activate(host: host)
        logger.info("Activated plugin: \(plugin.manifest.id)")
    }

    func setPluginEnabled(_ pluginId: String, enabled: Bool) {
        guard let index = loadedPlugins.firstIndex(where: { $0.manifest.id == pluginId }) else { return }

        loadedPlugins[index].isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "plugin.\(pluginId).enabled")

        if enabled {
            activatePlugin(loadedPlugins[index])
        } else {
            if let engine = loadedPlugins[index].instance as? TranscriptionEnginePlugin {
                let selectedProvider = UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedEngine)
                if selectedProvider == engine.providerId {
                    let fallback = transcriptionEngines.first(where: { $0.providerId != engine.providerId && $0.isConfigured })
                    if let fallback {
                        ServiceContainer.shared.modelManagerService.selectProvider(fallback.providerId)
                    }
                }
            }
            loadedPlugins[index].instance.deactivate()
            logger.info("Deactivated plugin: \(pluginId)")
        }
    }

    func openPluginsFolder() {
        NSWorkspace.shared.open(pluginsDirectory)
    }

    /// Notify observers that plugin state changed (e.g. a model was loaded/unloaded)
    func notifyPluginStateChanged() {
        objectWillChange.send()
    }

    // MARK: - Dynamic Plugin Management

    func unloadPlugin(_ pluginId: String) {
        guard let index = loadedPlugins.firstIndex(where: { $0.manifest.id == pluginId }) else { return }
        let plugin = loadedPlugins[index]
        if plugin.isEnabled {
            plugin.instance.deactivate()
        }
        // Only unload bundle for dynamic plugins (not compiled-in)
        if plugin.bundle != Bundle.main {
            plugin.bundle.unload()
        }
        loadedPlugins.remove(at: index)
        logger.info("Unloaded plugin: \(pluginId)")
    }

    func bundleURL(for pluginId: String) -> URL? {
        loadedPlugins.first { $0.manifest.id == pluginId }?.sourceURL
    }
}
