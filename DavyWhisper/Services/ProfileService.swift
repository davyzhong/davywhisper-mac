import Foundation
import SwiftData
import Combine
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DavyWhisper", category: "ProfileService")

@MainActor
final class ProfileService: ObservableObject {
    @Published var profiles: [Profile] = []

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(appSupportDirectory: URL = AppConstants.appSupportDirectory) {
        let schema = Schema([Profile.self])
        let storeDir = appSupportDirectory
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)

        let storeURL = storeDir.appendingPathComponent("profiles.store")
        let config = ModelConfiguration(url: storeURL)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Incompatible schema — delete old store and retry
            for suffix in ["", "-wal", "-shm"] {
                let url = storeDir.appendingPathComponent("profiles.store\(suffix)")
                try? FileManager.default.removeItem(at: url)
            }
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to create profiles ModelContainer after reset: \(error)")
            }
        }
        modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = true

        fetchProfiles()
    }

    func addProfile(
        name: String,
        bundleIdentifiers: [String] = [],
        urlPatterns: [String] = [],
        inputLanguage: String? = nil,
        translationTargetLanguage: String? = nil,
        selectedTask: String? = nil,
        engineOverride: String? = nil,
        cloudModelOverride: String? = nil,
        promptActionId: String? = nil,
        memoryEnabled: Bool = false,
        outputFormat: String? = nil,
        hotkeyData: Data? = nil,
        inlineCommandsEnabled: Bool = false,
    ) {
        let profile = Profile(
            name: name,
            bundleIdentifiers: bundleIdentifiers,
            urlPatterns: urlPatterns,
            inputLanguage: inputLanguage,
            translationTargetLanguage: translationTargetLanguage,
            selectedTask: selectedTask,
            engineOverride: engineOverride,
            cloudModelOverride: cloudModelOverride,
            promptActionId: promptActionId,
            memoryEnabled: memoryEnabled,
            outputFormat: outputFormat,
            hotkeyData: hotkeyData,
            inlineCommandsEnabled: inlineCommandsEnabled
        )
        modelContext.insert(profile)
        save()
        fetchProfiles()
    }

    func updateProfile(_ profile: Profile) {
        profile.updatedAt = Date()
        save()
        fetchProfiles()
    }

    func deleteProfile(_ profile: Profile) {
        modelContext.delete(profile)
        save()
        fetchProfiles()
    }

    func toggleProfile(_ profile: Profile) {
        profile.isEnabled.toggle()
        profile.updatedAt = Date()
        save()
        fetchProfiles()
    }

    // MARK: - Migration

    /// Migrate profiles with WhisperKit engine override to Paraformer.
    /// Called once on first launch after upgrade. Guarded by UserDefaults flag.
    func migrateDefaultEngine(userDefaults: any UserDefaultsProviding) {
        let flagKey = "didMigrateDefaultEngine_v1"
        guard !userDefaults.bool(forKey: flagKey) else { return }

        let oldEngine = "whisper"
        let newEngine = "paraformer"
        var migrated = false

        for profile in self.profiles {
            if profile.engineOverride == oldEngine {
                profile.engineOverride = newEngine
                migrated = true
            }
        }

        if migrated {
            save()
            fetchProfiles()
            logger.info("Migrated profiles from whisper to paraformer")
        }

        userDefaults.set(true, forKey: flagKey)
    }

    func matchProfile(bundleIdentifier: String?, url: String? = nil) -> Profile? {
        let bundleId = bundleIdentifier ?? ""
        let domain = extractDomain(from: url)
        let enabled = profiles.filter { $0.isEnabled }

        // Tier 1: bundleId + URL match (highest specificity)
        if !bundleId.isEmpty, let domain {
            let matches = enabled.filter { profile in
                profile.bundleIdentifiers.contains(bundleId) &&
                profile.urlPatterns.contains { domainMatches(domain, pattern: $0) }
            }
            if let best = matches.first {
                return best
            }
        }

        // Tier 2: URL-only match (cross-browser)
        if let domain {
            let matches = enabled.filter { profile in
                !profile.urlPatterns.isEmpty &&
                profile.urlPatterns.contains { domainMatches(domain, pattern: $0) }
            }
            if let best = matches.first {
                return best
            }
        }

        // Tier 3: bundleId-only match
        if !bundleId.isEmpty {
            let matches = enabled.filter { $0.bundleIdentifiers.contains(bundleId) }
            if let best = matches.first {
                return best
            }
        }

        return nil
    }

    /// Extracts a clean domain from a URL string, stripping "www." prefix.
    /// - Tag: extractDomain
    func extractDomain(from urlString: String?) -> String? {
        guard let urlString, !urlString.isEmpty,
              let url = URL(string: urlString),
              let host = url.host() else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Checks if a domain matches a pattern. Supports exact match and subdomain match.
    /// e.g. pattern "google.com" matches "google.com" and "docs.google.com"
    /// - Tag: domainMatches
    func domainMatches(_ domain: String, pattern: String) -> Bool {
        let d = domain.lowercased()
        let p = pattern.lowercased()
        return d == p || d.hasSuffix("." + p)
    }

    private func fetchProfiles() {
        let descriptor = FetchDescriptor<Profile>(
            sortBy: [SortDescriptor(\.name)]
        )
        do {
            profiles = try modelContext.fetch(descriptor)
        } catch {
            profiles = []
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
