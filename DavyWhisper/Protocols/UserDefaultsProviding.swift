import Foundation

/// Abstracts UserDefaults access for testability.
/// Production code uses `UserDefaults.standard`; tests inject `MockUserDefaults`.
protocol UserDefaultsProviding: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    func string(forKey key: String) -> String?
    func bool(forKey key: String) -> Bool
    func integer(forKey key: String) -> Int
    func double(forKey key: String) -> Double
    func data(forKey key: String) -> Data?
    func removeObject(forKey key: String)
}

/// Production UserDefaults conformance — no changes needed in existing code.
extension UserDefaults: UserDefaultsProviding {}
