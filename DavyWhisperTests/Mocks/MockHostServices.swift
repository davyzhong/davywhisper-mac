import Foundation
import DavyWhisperPluginSDK

/// Mock HostServices for testing plugin resolution logic.
/// Provides a configurable pluginDataDirectory pointing to a temp directory.
final class MockHostServices: HostServices, @unchecked Sendable {
    let pluginDataDirectory: URL
    var activeAppBundleId: String? = nil
    var activeAppName: String? = nil
    var availableProfileNames: [String] = []

    private var secrets: [String: String] = [:]
    private var defaults: [String: Any] = [:]

    let eventBus: EventBusProtocol = MockEventBus()

    var capabilitiesChangedCount = 0

    init(pluginDataDirectory: URL) {
        self.pluginDataDirectory = pluginDataDirectory
    }

    func storeSecret(key: String, value: String) throws { secrets[key] = value }
    func loadSecret(key: String) -> String? { secrets[key] }
    func userDefault(forKey: String) -> Any? { defaults[forKey] }
    func setUserDefault(_ value: Any?, forKey: String) { defaults[forKey] = value }
    func notifyCapabilitiesChanged() { capabilitiesChangedCount += 1 }
}

/// Minimal EventBus mock for HostServices compliance.
final class MockEventBus: EventBusProtocol, @unchecked Sendable {
    func subscribe(handler: @escaping @Sendable (DavyWhisperEvent) async -> Void) -> UUID {
        return UUID()
    }
    func unsubscribe(id: UUID) {}
}
