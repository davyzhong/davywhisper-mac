import Foundation
import SwiftData
import Combine
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DavyWhisper", category: "PluginCredentialService")

@MainActor
final class PluginCredentialService: ObservableObject {
    @Published var credentials: [PluginCredential] = []

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(appSupportDirectory: URL = AppConstants.appSupportDirectory) {
        let schema = Schema([PluginCredential.self])
        let storeDir = appSupportDirectory
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)

        let storeURL = storeDir.appendingPathComponent("credentials.store")
        let config = ModelConfiguration(url: storeURL)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Incompatible schema — delete old store and retry
            for suffix in ["", "-wal", "-shm"] {
                let url = storeDir.appendingPathComponent("credentials.store\(suffix)")
                try? FileManager.default.removeItem(at: url)
            }
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to create credentials ModelContainer after reset: \(error)")
            }
        }
        modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = true

        fetchCredentials()
    }

    // MARK: - Public API

    /// Get credential for a plugin
    func getCredential(for pluginId: String) -> PluginCredential? {
        credentials.first { $0.pluginId == pluginId }
    }

    /// Get API key for a plugin
    func getAPIKey(for pluginId: String) -> String? {
        getCredential(for: pluginId)?.apiKey
    }

    /// Get base URL for a plugin
    func getBaseURL(for pluginId: String) -> String? {
        getCredential(for: pluginId)?.baseURL
    }

    /// Save or update credential for a plugin
    func saveCredential(pluginId: String, apiKey: String, baseURL: String? = nil) {
        if let existing = getCredential(for: pluginId) {
            // Update existing
            existing.apiKey = apiKey
            existing.baseURL = baseURL
            existing.updatedAt = Date()
        } else {
            // Create new
            let credential = PluginCredential(
                pluginId: pluginId,
                apiKey: apiKey,
                baseURL: baseURL
            )
            modelContext.insert(credential)
        }
        save()
        fetchCredentials()
    }

    /// Delete credential for a plugin
    func deleteCredential(pluginId: String) {
        guard let credential = getCredential(for: pluginId) else { return }
        modelContext.delete(credential)
        save()
        fetchCredentials()
    }

    /// Check if a plugin has credentials configured
    func hasCredential(pluginId: String) -> Bool {
        getCredential(for: pluginId) != nil
    }

    // MARK: - Private

    private func fetchCredentials() {
        let descriptor = FetchDescriptor<PluginCredential>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        do {
            credentials = try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch credentials: \(error.localizedDescription)")
            credentials = []
        }
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            logger.error("Save failed: \(error.localizedDescription)")
        }
    }
}
