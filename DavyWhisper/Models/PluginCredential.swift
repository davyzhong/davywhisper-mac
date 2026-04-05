import Foundation
import SwiftData

/// Stores API credentials for plugins (LLM providers, transcription engines, etc.)
/// Replaces Keychain storage for easier user experience - no system password prompts.
@Model
final class PluginCredential {
    var id: UUID
    var pluginId: String
    var apiKey: String
    var baseURL: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        pluginId: String,
        apiKey: String,
        baseURL: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.pluginId = pluginId
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
