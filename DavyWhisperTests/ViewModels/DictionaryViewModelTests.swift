import XCTest
@testable import DavyWhisper

@MainActor
final class DictionaryViewModelTests: XCTestCase {

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

    func testInit_entriesLoadedFromService() {
        XCTAssertNotNil(container.dictionaryViewModel)
        XCTAssertEqual(container.dictionaryViewModel.termsCount, 0)
        XCTAssertEqual(container.dictionaryViewModel.correctionsCount, 0)
        XCTAssertEqual(container.dictionaryViewModel.filterTab, .all)
    }

    // MARK: - filteredEntries (tests the filtering logic directly)

    func testFilteredEntries_all_returnsAllEntries() {
        // Pre-populate via service then sync VM.entries directly (binding timing varies in tests)
        let entry1 = DictionaryEntry(type: .term, original: "Kubernetes", replacement: nil, caseSensitive: false)
        let entry2 = DictionaryEntry(type: .correction, original: "teh", replacement: "the", caseSensitive: false)
        container.dictionaryViewModel.entries = [entry1, entry2]

        XCTAssertEqual(container.dictionaryViewModel.filteredEntries.count, 2)
    }

    func testFilteredEntries_terms_onlyReturnsTerms() {
        container.dictionaryViewModel.entries = [
            DictionaryEntry(type: .term, original: "K8s", replacement: nil, caseSensitive: false),
            DictionaryEntry(type: .correction, original: "teh", replacement: "the", caseSensitive: false),
        ]
        container.dictionaryViewModel.filterTab = .terms

        XCTAssertEqual(container.dictionaryViewModel.filteredEntries.count, 1)
        XCTAssertEqual(container.dictionaryViewModel.filteredEntries.first?.type, .term)
    }

    func testFilteredEntries_corrections_onlyReturnsCorrections() {
        container.dictionaryViewModel.entries = [
            DictionaryEntry(type: .term, original: "K8s", replacement: nil, caseSensitive: false),
            DictionaryEntry(type: .correction, original: "teh", replacement: "the", caseSensitive: false),
        ]
        container.dictionaryViewModel.filterTab = .corrections

        XCTAssertEqual(container.dictionaryViewModel.filteredEntries.count, 1)
        XCTAssertEqual(container.dictionaryViewModel.filteredEntries.first?.type, .correction)
    }

    func testFilteredEntries_termPacks_alwaysEmpty() {
        container.dictionaryViewModel.entries = [
            DictionaryEntry(type: .term, original: "K8s", replacement: nil, caseSensitive: false),
        ]
        container.dictionaryViewModel.filterTab = .termPacks

        XCTAssertTrue(container.dictionaryViewModel.filteredEntries.isEmpty)
    }

    // MARK: - startCreating

    func testStartCreating_setsCorrectState() {
        container.dictionaryViewModel.startCreating(type: .correction)

        XCTAssertTrue(container.dictionaryViewModel.isCreatingNew)
        XCTAssertTrue(container.dictionaryViewModel.isEditing)
        XCTAssertEqual(container.dictionaryViewModel.editType, .correction)
        XCTAssertTrue(container.dictionaryViewModel.editOriginal.isEmpty)
        XCTAssertTrue(container.dictionaryViewModel.editReplacement.isEmpty)
        XCTAssertFalse(container.dictionaryViewModel.editCaseSensitive)
    }

    func testStartCreating_defaultsToTerm() {
        container.dictionaryViewModel.startCreating()

        XCTAssertEqual(container.dictionaryViewModel.editType, .term)
    }

    // MARK: - startEditing

    func testStartEditing_populatesEditorFields() {
        let entry = DictionaryEntry(
            type: .correction,
            original: "teh",
            replacement: "the",
            caseSensitive: true
        )
        container.dictionaryViewModel.entries = [entry]

        container.dictionaryViewModel.startEditing(entry)

        XCTAssertFalse(container.dictionaryViewModel.isCreatingNew)
        XCTAssertTrue(container.dictionaryViewModel.isEditing)
        XCTAssertEqual(container.dictionaryViewModel.editOriginal, "teh")
        XCTAssertEqual(container.dictionaryViewModel.editReplacement, "the")
        XCTAssertTrue(container.dictionaryViewModel.editCaseSensitive)
    }

    // MARK: - cancelEditing

    func testCancelEditing_resetsAllFields() {
        container.dictionaryViewModel.startCreating(type: .correction)
        container.dictionaryViewModel.editOriginal = "teh"
        container.dictionaryViewModel.editReplacement = "the"
        container.dictionaryViewModel.editCaseSensitive = true

        container.dictionaryViewModel.cancelEditing()

        XCTAssertFalse(container.dictionaryViewModel.isEditing)
        XCTAssertFalse(container.dictionaryViewModel.isCreatingNew)
        XCTAssertTrue(container.dictionaryViewModel.editOriginal.isEmpty)
        XCTAssertTrue(container.dictionaryViewModel.editReplacement.isEmpty)
        XCTAssertEqual(container.dictionaryViewModel.editType, .term)
        XCTAssertFalse(container.dictionaryViewModel.editCaseSensitive)
    }

    // MARK: - saveEditing validation (does not require service binding)

    func testSaveEditing_emptyOriginal_setsError() {
        container.dictionaryViewModel.startCreating(type: .term)
        container.dictionaryViewModel.editOriginal = ""

        container.dictionaryViewModel.saveEditing()

        XCTAssertNotNil(container.dictionaryViewModel.error)
        XCTAssertTrue(container.dictionaryViewModel.isEditing)
    }

    func testSaveEditing_correctionWithoutReplacement_setsError() {
        container.dictionaryViewModel.startCreating(type: .correction)
        container.dictionaryViewModel.editOriginal = "teh"
        container.dictionaryViewModel.editReplacement = ""

        container.dictionaryViewModel.saveEditing()

        XCTAssertNotNil(container.dictionaryViewModel.error)
        XCTAssertTrue(container.dictionaryViewModel.isEditing)
    }

    // MARK: - Error / Message clearing

    func testClearError_setsNil() {
        container.dictionaryViewModel.error = "some error"

        container.dictionaryViewModel.clearError()

        XCTAssertNil(container.dictionaryViewModel.error)
    }

    func testClearImportMessage_setsNil() {
        container.dictionaryViewModel.importMessage = "imported"

        container.dictionaryViewModel.clearImportMessage()

        XCTAssertNil(container.dictionaryViewModel.importMessage)
    }

    // MARK: - Counts via service proxy

    func testTermsCount_reflectsService() {
        container.dictionaryService.addEntry(type: .term, original: "A", replacement: nil, caseSensitive: false)
        container.dictionaryService.addEntry(type: .term, original: "B", replacement: nil, caseSensitive: false)
        container.dictionaryService.addEntry(type: .correction, original: "C", replacement: "c", caseSensitive: false)

        XCTAssertEqual(container.dictionaryViewModel.termsCount, 2)
        XCTAssertEqual(container.dictionaryViewModel.correctionsCount, 1)
    }
}
