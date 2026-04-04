import XCTest
@testable import DavyWhisper

/// Tests for ErrorLogService: addEntry, sorting, cap at 200, clearAll,
/// JSON persistence round-trip, and loading from existing file on init.
@MainActor
final class ErrorLogServiceTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = try TestSupport.makeTemporaryDirectory()
    }

    override func tearDownWithError() throws {
        TestSupport.remove(tempDir)
    }

    private func makeService() -> ErrorLogService {
        ErrorLogService(appSupportDirectory: tempDir)
    }

    private func errorLogURL() -> URL {
        tempDir.appendingPathComponent("error-log.json")
    }

    // MARK: - addEntry

    func testAddEntryAddsToEntriesArray() {
        let service = makeService()

        XCTAssertEqual(service.entries.count, 0)

        service.addEntry(message: "Something went wrong", category: "transcription")

        XCTAssertEqual(service.entries.count, 1)
        XCTAssertEqual(service.entries[0].message, "Something went wrong")
        XCTAssertEqual(service.entries[0].category, "transcription")
    }

    func testAddEntryDefaultCategoryIsGeneral() {
        let service = makeService()

        service.addEntry(message: "An error")

        XCTAssertEqual(service.entries[0].category, "general")
    }

    func testAddMultipleEntries() {
        let service = makeService()

        service.addEntry(message: "Error 1", category: "transcription")
        service.addEntry(message: "Error 2", category: "recording")
        service.addEntry(message: "Error 3", category: "plugin")

        XCTAssertEqual(service.entries.count, 3)
    }

    // MARK: - Sorting (Newest First)

    func testEntriesAreSortedNewestFirst() {
        let service = makeService()

        service.addEntry(message: "First error")
        service.addEntry(message: "Second error")
        service.addEntry(message: "Third error")

        // Since insert(at: 0) is used, newest is first
        XCTAssertEqual(service.entries.count, 3)
        XCTAssertEqual(service.entries[0].message, "Third error")
        XCTAssertEqual(service.entries[1].message, "Second error")
        XCTAssertEqual(service.entries[2].message, "First error")
    }

    func testEntryTimestampsAreOrderedNewestFirst() {
        let service = makeService()

        service.addEntry(message: "Earlier")
        // Small sleep to ensure different timestamps
        Thread.sleep(forTimeInterval: 0.05)
        service.addEntry(message: "Later")

        XCTAssertEqual(service.entries.count, 2)
        let first = service.entries[0]
        let second = service.entries[1]
        // First entry should be newer (higher timestamp)
        XCTAssertGreaterThanOrEqual(first.timestamp, second.timestamp)
    }

    // MARK: - Max Cap at 200

    func testMaxCapAt200Entries() {
        let service = makeService()

        // Add 201 entries
        for i in 0..<201 {
            service.addEntry(message: "Error \(i)", category: "general")
        }

        // Should cap at exactly 200
        XCTAssertEqual(service.entries.count, 200)
    }

    func testOldestEntryRemovedWhenCapExceeded() {
        let service = makeService()

        // Add 200 entries
        for i in 0..<200 {
            service.addEntry(message: "Error \(i)", category: "general")
        }
        // The most recent is "Error 199", oldest is "Error 0"
        XCTAssertEqual(service.entries.first?.message, "Error 199")

        // Add one more — should remove oldest
        service.addEntry(message: "Error 200", category: "general")

        XCTAssertEqual(service.entries.count, 200)
        // Newest should be "Error 200"
        XCTAssertEqual(service.entries.first?.message, "Error 200")
        // Oldest should now be "Error 1" (the original "Error 0" was dropped)
        XCTAssertEqual(service.entries.last?.message, "Error 1")
    }

    func testAddingWellBelowCapDoesNotLoseEntries() {
        let service = makeService()

        for i in 0..<50 {
            service.addEntry(message: "Error \(i)", category: "general")
        }

        XCTAssertEqual(service.entries.count, 50)
    }

    // MARK: - clearAll

    func testClearAllRemovesAllEntries() {
        let service = makeService()

        service.addEntry(message: "Error 1")
        service.addEntry(message: "Error 2")
        XCTAssertEqual(service.entries.count, 2)

        service.clearAll()

        XCTAssertEqual(service.entries.count, 0)
    }

    func testClearAllPersistsEmptyState() {
        let service = makeService()

        service.addEntry(message: "Error 1")
        service.clearAll()

        // Create a new service loading from the same directory
        let service2 = makeService()
        XCTAssertEqual(service2.entries.count, 0)
    }

    func testClearAllOnEmptyServiceIsNoOp() {
        let service = makeService()

        // Should not crash
        service.clearAll()

        XCTAssertEqual(service.entries.count, 0)
    }

    // MARK: - Persistence Round-Trip

    func testPersistenceWritesAndReadsBack() {
        let service = makeService()

        service.addEntry(message: "Persistent error", category: "recording")
        service.addEntry(message: "Another error", category: "plugin")

        // Verify file was written
        let fileExists = FileManager.default.fileExists(atPath: errorLogURL().path)
        XCTAssertTrue(fileExists, "error-log.json should exist after addEntry")

        // Create a new service instance reading from the same file
        let service2 = makeService()
        XCTAssertEqual(service2.entries.count, 2)
        XCTAssertEqual(service2.entries[0].message, "Another error")
        XCTAssertEqual(service2.entries[0].category, "plugin")
        XCTAssertEqual(service2.entries[1].message, "Persistent error")
        XCTAssertEqual(service2.entries[1].category, "recording")
    }

    func testPersistencePreservesEntryProperties() throws {
        let service = makeService()

        service.addEntry(message: "Test message", category: "transcription")

        let original = service.entries[0]

        // Create new service to reload
        let service2 = makeService()
        let reloaded = try XCTUnwrap(service2.entries.first)

        XCTAssertEqual(reloaded.message, original.message)
        XCTAssertEqual(reloaded.category, original.category)
        XCTAssertEqual(reloaded.id, original.id)
        // Timestamp should be close (within 1 second for JSON serialization round-trip)
        let diff = abs(reloaded.timeInterval - original.timeInterval)
        XCTAssertLessThan(diff, 1.0)
    }

    func testPersistenceWith200Entries() {
        let service = makeService()

        for i in 0..<200 {
            service.addEntry(message: "Error \(i)", category: "general")
        }

        // Reload from file
        let service2 = makeService()
        XCTAssertEqual(service2.entries.count, 200)
        XCTAssertEqual(service2.entries.first?.message, "Error 199")
        XCTAssertEqual(service2.entries.last?.message, "Error 0")
    }

    // MARK: - Loading from Existing File on Init

    func testInitLoadsFromExistingFile() {
        // Write entries using one service instance
        let service1 = makeService()
        service1.addEntry(message: "Existing entry 1", category: "transcription")
        service1.addEntry(message: "Existing entry 2", category: "prompt")

        // Create a fresh service — should load the file
        let service2 = makeService()
        XCTAssertEqual(service2.entries.count, 2)
    }

    func testInitWithNoFileStartsEmpty() {
        let service = makeService()

        // No file existed, should start empty
        XCTAssertTrue(service.entries.isEmpty)
    }

    func testInitWithCorruptedFileStartsEmpty() {
        // Write garbage data to the error log file
        let garbage = "this is not valid json".data(using: .utf8)!
        try? garbage.write(to: errorLogURL(), options: .atomic)

        let service = makeService()
        // Should gracefully handle corrupted data
        XCTAssertTrue(service.entries.isEmpty)
    }

    // MARK: - addEntry Persists Immediately

    func testAddEntryPersistsImmediately() {
        let service = makeService()

        service.addEntry(message: "Immediate persist")

        // File should exist and contain the entry
        let data = try? Data(contentsOf: errorLogURL())
        XCTAssertNotNil(data, "Persistence file should exist after addEntry")

        let decoded = try? JSONDecoder().decode([ErrorLogEntry].self, from: data!)
        XCTAssertEqual(decoded?.count, 1)
        XCTAssertEqual(decoded?.first?.message, "Immediate persist")
    }

    // MARK: - Entry ID Uniqueness

    func testEachEntryHasUniqueID() {
        let service = makeService()

        service.addEntry(message: "Error 1")
        service.addEntry(message: "Error 2")
        service.addEntry(message: "Error 3")

        let ids = service.entries.map(\.id)
        let uniqueIDs = Set(ids)
        XCTAssertEqual(ids.count, uniqueIDs.count, "All entry IDs should be unique")
    }
}

// MARK: - Helper Extension

extension ErrorLogEntry {
    /// Time interval since 1970 for timestamp comparison in tests.
    var timeInterval: TimeInterval {
        timestamp.timeIntervalSince1970
    }
}
