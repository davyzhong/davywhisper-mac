import XCTest
import SwiftData
@testable import DavyWhisper

/// Tests for PluginCredentialService — SwiftData-backed credential storage.
///
/// Regression context: directly inserting rows into the SQLite store with
/// NULL ZID (UUID) caused swift_dynamicCastFailure on fetch.
/// All tests verify proper SwiftData round-trip, UUID integrity, and CRUD operations.
@MainActor
final class PluginCredentialServiceTests: XCTestCase {
    private var tempDir: URL!
    private var service: PluginCredentialService!

    override func setUp() {
        super.setUp()
        tempDir = try! TestSupport.makeTemporaryDirectory()
        service = PluginCredentialService(appSupportDirectory: tempDir)
    }

    override func tearDown() {
        service = nil
        TestSupport.remove(tempDir)
        super.tearDown()
    }

    // MARK: - CRUD Round-trip

    func testSaveAndRetrieveCredential() {
        service.saveCredential(
            pluginId: "com.test.plugin",
            apiKey: "sk-test-key-123",
            baseURL: "https://api.example.com/v1"
        )

        let apiKey = service.getAPIKey(for: "com.test.plugin")
        XCTAssertEqual(apiKey, "sk-test-key-123")

        let baseURL = service.getBaseURL(for: "com.test.plugin")
        XCTAssertEqual(baseURL, "https://api.example.com/v1")
    }

    func testSaveCredentialWithoutBaseURL() {
        service.saveCredential(
            pluginId: "com.test.no-url",
            apiKey: "key-only"
        )

        let apiKey = service.getAPIKey(for: "com.test.no-url")
        XCTAssertEqual(apiKey, "key-only")

        let baseURL = service.getBaseURL(for: "com.test.no-url")
        XCTAssertNil(baseURL)
    }

    func testUpdateExistingCredential() {
        service.saveCredential(
            pluginId: "com.test.update",
            apiKey: "old-key",
            baseURL: "https://old.example.com"
        )

        service.saveCredential(
            pluginId: "com.test.update",
            apiKey: "new-key",
            baseURL: "https://new.example.com"
        )

        XCTAssertEqual(service.getAPIKey(for: "com.test.update"), "new-key")
        XCTAssertEqual(service.getBaseURL(for: "com.test.update"), "https://new.example.com")
    }

    func testDeleteCredential() {
        service.saveCredential(
            pluginId: "com.test.delete",
            apiKey: "to-be-deleted"
        )
        XCTAssertTrue(service.hasCredential(pluginId: "com.test.delete"))

        service.deleteCredential(pluginId: "com.test.delete")
        XCTAssertFalse(service.hasCredential(pluginId: "com.test.delete"))
        XCTAssertNil(service.getAPIKey(for: "com.test.delete"))
    }

    func testDeleteNonexistentCredentialDoesNotCrash() {
        // Should be a no-op, not a crash
        service.deleteCredential(pluginId: "com.test.nonexistent")
    }

    // MARK: - UUID Integrity (regression: NULL ZID caused crash)

    func testCredentialHasValidUUID() {
        service.saveCredential(
            pluginId: "com.test.uuid",
            apiKey: "key"
        )

        let cred = service.getCredential(for: "com.test.uuid")
        XCTAssertNotNil(cred)
        XCTAssertNotNil(cred?.id)
        // UUID should be a valid 16-byte identifier
        XCTAssertEqual(cred?.id.uuidString.count, 36) // 8-4-4-4-12 format
    }

    func testMultipleCredentialsHaveUniqueUUIDs() {
        service.saveCredential(pluginId: "com.test.a", apiKey: "key-a")
        service.saveCredential(pluginId: "com.test.b", apiKey: "key-b")
        service.saveCredential(pluginId: "com.test.c", apiKey: "key-c")

        let ids = service.credentials.compactMap { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(uniqueIds.count, 3, "Each credential must have a unique UUID")
    }

    // MARK: - Isolation

    func testCredentialsAreIsolatedByPluginId() {
        service.saveCredential(pluginId: "plugin.alpha", apiKey: "alpha-key", baseURL: "https://alpha.com")
        service.saveCredential(pluginId: "plugin.beta", apiKey: "beta-key", baseURL: "https://beta.com")

        XCTAssertEqual(service.getAPIKey(for: "plugin.alpha"), "alpha-key")
        XCTAssertEqual(service.getAPIKey(for: "plugin.beta"), "beta-key")
        XCTAssertEqual(service.getBaseURL(for: "plugin.alpha"), "https://alpha.com")
        XCTAssertEqual(service.getBaseURL(for: "plugin.beta"), "https://beta.com")
    }

    func testEmptyServiceReturnsNil() {
        XCTAssertNil(service.getAPIKey(for: "nonexistent"))
        XCTAssertNil(service.getBaseURL(for: "nonexistent"))
        XCTAssertNil(service.getCredential(for: "nonexistent"))
        XCTAssertFalse(service.hasCredential(pluginId: "nonexistent"))
    }

    // MARK: - Timestamps

    func testCredentialTimestamps() {
        let beforeSave = Date()

        service.saveCredential(
            pluginId: "com.test.timestamps",
            apiKey: "key"
        )

        let cred = service.getCredential(for: "com.test.timestamps")
        XCTAssertNotNil(cred)
        XCTAssertGreaterThanOrEqual(cred!.createdAt.timeIntervalSince1970, beforeSave.timeIntervalSince1970 - 1)
        XCTAssertGreaterThanOrEqual(cred!.updatedAt.timeIntervalSince1970, beforeSave.timeIntervalSince1970 - 1)
    }

    func testUpdateRefreshesTimestamp() throws {
        service.saveCredential(pluginId: "com.test.ts-update", apiKey: "v1")
        let firstUpdate = service.getCredential(for: "com.test.ts-update")!.updatedAt

        // Small delay to ensure different timestamp
        sleep(1)

        service.saveCredential(pluginId: "com.test.ts-update", apiKey: "v2")
        let secondUpdate = service.getCredential(for: "com.test.ts-update")!.updatedAt

        XCTAssertGreaterThan(secondUpdate.timeIntervalSince1970, firstUpdate.timeIntervalSince1970)
    }

    // MARK: - Special Characters in API Key

    func testAPIKeyWithSpecialCharacters() {
        let complexKey = "sk-cp-irraUWZ84ETjyxnjefqNEyApEgJcXG0mllYHYWPZGz0OzJhNJXUZF55ZOdO09lY_aH1QxDOMucmI9Hk8G_iq8fIXVzxTYf7fSq5GPfGC3P4cR5W7hSlKEu4"
        service.saveCredential(pluginId: "com.test.special", apiKey: complexKey)

        XCTAssertEqual(service.getAPIKey(for: "com.test.special"), complexKey)
    }

    func testBaseURLWithUnicodePath() {
        let url = "https://api.example.com/v1/路径/测试"
        service.saveCredential(pluginId: "com.test.unicode", apiKey: "key", baseURL: url)

        XCTAssertEqual(service.getBaseURL(for: "com.test.unicode"), url)
    }
}
