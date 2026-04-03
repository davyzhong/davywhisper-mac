import Foundation
@testable import DavyWhisper

/// In-memory UserDefaults replacement for tests.
/// Thread-safe via serial dispatch queue.
final class MockUserDefaults: UserDefaultsProviding {
    private var storage: [String: Any] = [:]
    private let queue = DispatchQueue(label: "MockUserDefaults", attributes: .concurrent)

    // MARK: - UserDefaultsProviding

    func object(forKey key: String) -> Any? {
        queue.sync { storage[key] }
    }

    func set(_ value: Any?, forKey key: String) {
        queue.sync(flags: .barrier) { storage[key] = value }
    }

    func string(forKey key: String) -> String? {
        queue.sync { storage[key] as? String }
    }

    func bool(forKey key: String) -> Bool {
        queue.sync { storage[key] as? Bool ?? false }
    }

    func integer(forKey key: String) -> Int {
        queue.sync { storage[key] as? Int ?? 0 }
    }

    func double(forKey key: String) -> Double {
        queue.sync { storage[key] as? Double ?? 0.0 }
    }

    func data(forKey key: String) -> Data? {
        queue.sync { storage[key] as? Data }
    }

    func removeObject(forKey key: String) {
        queue.sync(flags: .barrier) { storage.removeValue(forKey: key) }
    }

    // MARK: - Convenience helpers

    /// Sets values matching the app's UserDefaultsKeys defaults.
    func setDefaults() {
        set(true, forKey: "soundFeedbackEnabled")
        set(false, forKey: "preserveClipboard")
        set("notch", forKey: "indicatorStyle")
    }

    /// Removes all stored values.
    func reset() {
        queue.sync(flags: .barrier) { storage.removeAll() }
    }
}
