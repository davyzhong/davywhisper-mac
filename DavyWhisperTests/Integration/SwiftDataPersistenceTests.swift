import XCTest
@testable import DavyWhisper

/// Tests SwiftData persistence across HistoryService, ProfileService, DictionaryService, SnippetService.
/// Validates that records survive service restarts (different instances pointing to the same store).
@MainActor
final class SwiftDataPersistenceTests: XCTestCase {

    var tempDir: URL!
    var appDir: URL!

    private func makeAppDir() -> URL {
        tempDir.appendingPathComponent("AppSupport", isDirectory: true)
    }

    override func setUp() {
        super.setUp()
        tempDir = try! TestSupport.makeTemporaryDirectory()
        appDir = makeAppDir()
        try! FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        let original = AppConstants.testAppSupportDirectoryOverride
        AppConstants.testAppSupportDirectoryOverride = appDir
        AppConstants.testAppSupportDirectoryOverride = original
    }

    override func tearDown() {
        TestSupport.remove(tempDir)
        super.tearDown()
    }

    // MARK: - HistoryService Persistence

    func testHistoryRecord_persistsAcrossServiceRestart() throws {
        let original = AppConstants.testAppSupportDirectoryOverride
        AppConstants.testAppSupportDirectoryOverride = appDir

        // Write a record using first service instance
        let service1 = HistoryService(appSupportDirectory: appDir)
        service1.addRecord(
            rawText: "original text",
            finalText: "final text",
            appName: "TestApp",
            appBundleIdentifier: "com.test.app",
            durationSeconds: 1.5,
            engineUsed: "WhisperKit"
        )

        // Create new service instance pointing to same directory
        let service2 = HistoryService(appSupportDirectory: appDir)
        service2.loadRecords()

        XCTAssertEqual(service2.records.count, 1)
        XCTAssertEqual(service2.records.first?.rawText, "original text")
        XCTAssertEqual(service2.records.first?.finalText, "final text")

        AppConstants.testAppSupportDirectoryOverride = original
    }

    func testHistoryRecord_multipleRecords_persists() throws {
        let original = AppConstants.testAppSupportDirectoryOverride
        AppConstants.testAppSupportDirectoryOverride = appDir

        let service1 = HistoryService(appSupportDirectory: appDir)
        service1.addRecord(rawText: "r1", finalText: "R1", appBundleIdentifier: nil, durationSeconds: 1.0, engineUsed: "X")
        service1.addRecord(rawText: "r2", finalText: "R2", appBundleIdentifier: nil, durationSeconds: 2.0, engineUsed: "Y")

        let service2 = HistoryService(appSupportDirectory: appDir)
        service2.loadRecords()

        XCTAssertEqual(service2.records.count, 2)
        XCTAssertTrue(service2.records.contains { $0.rawText == "r1" })
        XCTAssertTrue(service2.records.contains { $0.rawText == "r2" })

        AppConstants.testAppSupportDirectoryOverride = original
    }

    // MARK: - ProfileService Persistence

    func testProfile_persistsAcrossServiceRestart() throws {
        let original = AppConstants.testAppSupportDirectoryOverride
        AppConstants.testAppSupportDirectoryOverride = appDir

        let service1 = ProfileService(appSupportDirectory: appDir)
        let profile = Profile(
            name: "TestProfile",
            bundleIdentifier: "com.test.app",
            isEnabled: true
        )
        service1.addProfile(profile)

        let service2 = ProfileService(appSupportDirectory: appDir)
        service2.loadProfiles()

        XCTAssertEqual(service2.profiles.count, 1)
        XCTAssertEqual(service2.profiles.first?.name, "TestProfile")

        AppConstants.testAppSupportDirectoryOverride = original
    }

    // MARK: - DictionaryService Persistence

    func testDictionaryEntry_persistsAcrossServiceRestart() throws {
        let original = AppConstants.testAppSupportDirectoryOverride
        AppConstants.testAppSupportDirectoryOverride = appDir

        let service1 = DictionaryService(appSupportDirectory: appDir)
        try service1.addEntry(type: .correction, original: "teh", replacement: "the")

        let service2 = DictionaryService(appSupportDirectory: appDir)
        service2.loadEntries()

        XCTAssertEqual(service2.dictionaryEntries.count, 1)
        XCTAssertEqual(service2.dictionaryEntries.first?.original, "teh")
        XCTAssertEqual(service2.dictionaryEntries.first?.replacement, "the")

        AppConstants.testAppSupportDirectoryOverride = original
    }

    // MARK: - SnippetService Persistence

    func testSnippet_persistsAcrossServiceRestart() throws {
        let original = AppConstants.testAppSupportDirectoryOverride
        AppConstants.testAppSupportDirectoryOverride = appDir

        let service1 = SnippetService(appSupportDirectory: appDir)
        try service1.addSnippet(trigger: "hello", replacement: "Hello, World!")

        let service2 = SnippetService(appSupportDirectory: appDir)
        service2.loadSnippets()

        XCTAssertEqual(service2.snippets.count, 1)
        XCTAssertEqual(service2.snippets.first?.trigger, "hello")
        XCTAssertEqual(service2.snippets.first?.replacement, "Hello, World!")

        AppConstants.testAppSupportDirectoryOverride = original
    }

    // MARK: - PromptActionService Persistence

    func testPromptAction_persistsAcrossServiceRestart() throws {
        let original = AppConstants.testAppSupportDirectoryOverride
        AppConstants.testAppSupportDirectoryOverride = appDir

        let service1 = PromptActionService(appSupportDirectory: appDir)
        service1.addAction(name: "Summarize", prompt: "Summarize this")

        let service2 = PromptActionService(appSupportDirectory: appDir)
        service2.loadActions()

        XCTAssertEqual(service2.promptActions.count, 1)
        XCTAssertEqual(service2.promptActions.first?.name, "Summarize")

        AppConstants.testAppSupportDirectoryOverride = original
    }

    // MARK: - Delete Across Restart

    func testDeleteRecord_persistsAcrossServiceRestart() throws {
        let original = AppConstants.testAppSupportDirectoryOverride
        AppConstants.testAppSupportDirectoryOverride = appDir

        let service1 = HistoryService(appSupportDirectory: appDir)
        service1.addRecord(rawText: "to delete", finalText: "deleted", appBundleIdentifier: nil, durationSeconds: 1.0, engineUsed: "X")

        let service2 = HistoryService(appSupportDirectory: appDir)
        service2.loadRecords()
        let recordToDelete = service2.records.first { $0.rawText == "to delete" }
        XCTAssertNotNil(recordToDelete)
        service2.deleteRecord(recordToDelete!)

        let service3 = HistoryService(appSupportDirectory: appDir)
        service3.loadRecords()
        XCTAssertEqual(service3.records.count, 0)

        AppConstants.testAppSupportDirectoryOverride = original
    }
}
