import XCTest
@testable import DavyWhisper

@MainActor
final class HistoryViewModelTests: XCTestCase {

    var container: TestServiceContainer!

    override func setUp() {
        super.setUp()
        container = try! TestServiceContainer()
    }

    override func tearDown() {
        container.tearDown()
        container = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInit_recordsAreEmpty() {
        XCTAssertNotNil(container.historyViewModel)
        XCTAssertTrue(container.historyViewModel.records.isEmpty)
    }

    func testInit_selectedRecordIDs_isEmpty() {
        XCTAssertTrue(container.historyViewModel.selectedRecordIDs.isEmpty)
    }

    func testInit_searchQuery_isEmpty() {
        XCTAssertEqual(container.historyViewModel.searchQuery, "")
    }

    func testInit_isEditing_isFalse() {
        XCTAssertFalse(container.historyViewModel.isEditing)
    }

    func testInit_detailViewMode_isProcessed() {
        XCTAssertEqual(container.historyViewModel.detailViewMode, .processed)
    }

    func testInit_hasActiveFilters_isFalse() {
        XCTAssertFalse(container.historyViewModel.hasActiveFilters)
    }

    func testInit_visibleRecordCount_isZero() {
        XCTAssertEqual(container.historyViewModel.visibleRecordCount, 0)
    }

    // MARK: - Static Helpers

    func testApplyFilters_timeRangeFiltersByDate() {
        let oldDate = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let recentDate = Date()

        let records = [
            makeRecord(timestamp: oldDate),
            makeRecord(timestamp: recentDate),
        ]

        let filtered = HistoryViewModel.applyFilters(
            records: records,
            query: "",
            appFilter: nil,
            timeRange: .thirtyDays
        )

        XCTAssertEqual(filtered.count, 1)
    }

    func testApplyFilters_appFilterFiltersByBundleId() {
        let record1 = makeRecord(appBundleIdentifier: "com.example.app1")
        let record2 = makeRecord(appBundleIdentifier: "com.example.app2")

        let filtered = HistoryViewModel.applyFilters(
            records: [record1, record2],
            query: "",
            appFilter: "com.example.app1",
            timeRange: .all
        )

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.appBundleIdentifier, "com.example.app1")
    }

    func testApplyFilters_queryFiltersByText() {
        let record1 = makeRecord(finalText: "Hello world")
        let record2 = makeRecord(finalText: "Goodbye world")

        let filtered = HistoryViewModel.applyFilters(
            records: [record1, record2],
            query: "hello",
            appFilter: nil,
            timeRange: .all
        )

        XCTAssertEqual(filtered.count, 1)
        XCTAssertTrue(filtered.first?.finalText.lowercased().contains("hello") ?? false)
    }

    func testApplyFilters_queryIsCaseInsensitive() {
        let record = makeRecord(finalText: "Hello WORLD")
        let filtered = HistoryViewModel.applyFilters(
            records: [record],
            query: "HELLO",
            appFilter: nil,
            timeRange: .all
        )
        XCTAssertEqual(filtered.count, 1)
    }

    func testApplyFilters_queryFiltersByAppName() {
        let record1 = makeRecord(finalText: "Some text", appName: "Slack")
        let record2 = makeRecord(finalText: "Some text", appName: "Chrome")

        let filtered = HistoryViewModel.applyFilters(
            records: [record1, record2],
            query: "slack",
            appFilter: nil,
            timeRange: .all
        )

        XCTAssertEqual(filtered.count, 1)
    }

    // MARK: - HistoryDateGroup

    func testHistoryDateGroup_displayName_allCases() {
        for group in HistoryDateGroup.allCases {
            XCTAssertFalse(group.displayName.isEmpty)
        }
    }

    // MARK: - HistoryTimeRange

    func testHistoryTimeRange_sevenDays_hasCutoffDate() {
        let range = HistoryTimeRange.sevenDays
        XCTAssertNotNil(range.cutoffDate)
    }

    func testHistoryTimeRange_all_hasNilCutoff() {
        XCTAssertNil(HistoryTimeRange.all.cutoffDate)
    }

    // MARK: - clearAllFilters

    func testClearAllFilters_resetsAllFilterState() {
        container.historyViewModel.selectedAppFilter = "com.example"
        container.historyViewModel.selectedTimeRange = .sevenDays
        container.historyViewModel.searchQuery = "test"

        container.historyViewModel.clearAllFilters()

        XCTAssertNil(container.historyViewModel.selectedAppFilter)
        XCTAssertEqual(container.historyViewModel.selectedTimeRange, .all)
        XCTAssertEqual(container.historyViewModel.searchQuery, "")
        XCTAssertFalse(container.historyViewModel.hasActiveFilters)
    }

    // MARK: - cancelEditing

    func testCancelEditing_resetsEditingState() {
        container.historyViewModel.isEditing = true
        container.historyViewModel.editedText = "changed"

        container.historyViewModel.cancelEditing()

        XCTAssertFalse(container.historyViewModel.isEditing)
        XCTAssertTrue(container.historyViewModel.editedText.isEmpty)
    }

    // MARK: - dismissCorrectionBanner

    func testDismissCorrectionBanner_clearsBannerState() {
        container.historyViewModel.showCorrectionBanner = true
        container.historyViewModel.correctionSuggestions = [
            CorrectionSuggestion(original: "teh", replacement: "the")
        ]

        container.historyViewModel.dismissCorrectionBanner()

        XCTAssertFalse(container.historyViewModel.showCorrectionBanner)
        XCTAssertTrue(container.historyViewModel.correctionSuggestions.isEmpty)
    }

    // MARK: - copyToClipboard (verifies no crash — pasteboard writes in test env)

    func testCopyToClipboard_doesNotCrash() {
        container.historyViewModel.copyToClipboard("hello")
        // NSPasteboard.general.setString() works even in test env
    }

    // MARK: - Helpers

    private func makeRecord(
        id: UUID = UUID(),
        finalText: String = "test text",
        rawText: String? = nil,
        timestamp: Date = Date(),
        appBundleIdentifier: String? = "com.example.app",
        appName: String? = "Example",
        durationSeconds: Double = 1.0,
        engineUsed: String = "whisper"
    ) -> TranscriptionRecord {
        TranscriptionRecord(
            id: id,
            timestamp: timestamp,
            rawText: rawText ?? finalText,
            finalText: finalText,
            appName: appName,
            appBundleIdentifier: appBundleIdentifier,
            durationSeconds: durationSeconds,
            engineUsed: engineUsed
        )
    }
}
