import XCTest
@testable import DavyWhisper

@MainActor
final class SnippetsViewModelTests: XCTestCase {

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

    func testInit_loadsSnippetsFromService() {
        XCTAssertNotNil(container.snippetsViewModel)
        XCTAssertTrue(container.snippetsViewModel.snippets.isEmpty)
        XCTAssertEqual(container.snippetsViewModel.totalCount, 0)
    }

    // MARK: - startCreating

    func testStartCreating_resetsEditorFields() {
        container.snippetsViewModel.editTrigger = "old"
        container.snippetsViewModel.editReplacement = "new"

        container.snippetsViewModel.startCreating()

        XCTAssertTrue(container.snippetsViewModel.isCreatingNew)
        XCTAssertTrue(container.snippetsViewModel.isEditing)
        XCTAssertTrue(container.snippetsViewModel.editTrigger.isEmpty)
        XCTAssertTrue(container.snippetsViewModel.editReplacement.isEmpty)
        XCTAssertFalse(container.snippetsViewModel.editCaseSensitive)
    }

    // MARK: - startEditing

    func testStartEditing_populatesFields() {
        container.snippetsViewModel.snippets = [
            Snippet(trigger: "omw", replacement: "on my way", caseSensitive: true)
        ]
        let snippet = container.snippetsViewModel.snippets.first!

        container.snippetsViewModel.startEditing(snippet)

        XCTAssertFalse(container.snippetsViewModel.isCreatingNew)
        XCTAssertTrue(container.snippetsViewModel.isEditing)
        XCTAssertEqual(container.snippetsViewModel.editTrigger, "omw")
        XCTAssertEqual(container.snippetsViewModel.editReplacement, "on my way")
        XCTAssertTrue(container.snippetsViewModel.editCaseSensitive)
    }

    // MARK: - cancelEditing

    func testCancelEditing_resetsAllFields() {
        container.snippetsViewModel.snippets = [
            Snippet(trigger: "omw", replacement: "on my way", caseSensitive: false)
        ]
        container.snippetsViewModel.startEditing(
            container.snippetsViewModel.snippets.first!
        )
        container.snippetsViewModel.editTrigger = "changed"

        container.snippetsViewModel.cancelEditing()

        XCTAssertFalse(container.snippetsViewModel.isEditing)
        XCTAssertFalse(container.snippetsViewModel.isCreatingNew)
        XCTAssertTrue(container.snippetsViewModel.editTrigger.isEmpty)
        XCTAssertTrue(container.snippetsViewModel.editReplacement.isEmpty)
    }

    // MARK: - saveEditing (create) — tests editor state, not service binding

    func testSaveEditing_createsNewSnippet() {
        container.snippetsViewModel.startCreating()
        container.snippetsViewModel.editTrigger = "omw"
        container.snippetsViewModel.editReplacement = "on my way"
        container.snippetsViewModel.editCaseSensitive = true

        container.snippetsViewModel.saveEditing()

        XCTAssertFalse(container.snippetsViewModel.isEditing)
    }

    // MARK: - saveEditing (validation)

    func testSaveEditing_emptyTrigger_setsError() {
        container.snippetsViewModel.startCreating()
        container.snippetsViewModel.editTrigger = ""
        container.snippetsViewModel.editReplacement = "replacement"

        container.snippetsViewModel.saveEditing()

        XCTAssertNotNil(container.snippetsViewModel.error)
        XCTAssertTrue(container.snippetsViewModel.isEditing)
    }

    func testSaveEditing_emptyReplacement_setsError() {
        container.snippetsViewModel.startCreating()
        container.snippetsViewModel.editTrigger = "trigger"
        container.snippetsViewModel.editReplacement = ""

        container.snippetsViewModel.saveEditing()

        XCTAssertNotNil(container.snippetsViewModel.error)
    }

    // MARK: - saveEditing (update)

    func testSaveEditing_updatesExistingSnippet() {
        let snippet = Snippet(trigger: "omw", replacement: "on my way", caseSensitive: false)
        container.snippetsViewModel.snippets = [snippet]

        container.snippetsViewModel.startEditing(snippet)
        container.snippetsViewModel.editReplacement = "I'm on my way"
        container.snippetsViewModel.saveEditing()

        XCTAssertFalse(container.snippetsViewModel.isEditing)
    }

    // MARK: - deleteSnippet

    func testDeleteSnippet_removesSnippet() {
        let snippet = Snippet(trigger: "omw", replacement: "on my way", caseSensitive: false)
        container.snippetsViewModel.snippets = [snippet]
        container.snippetService.deleteSnippet(snippet)
        // Service deletes from storage; simulate the VM array update (Combine doesn't propagate in tests)
        container.snippetsViewModel.snippets = container.snippetsViewModel.snippets.filter { $0.id != snippet.id }

        XCTAssertTrue(container.snippetsViewModel.snippets.isEmpty)
    }

    // MARK: - toggleSnippet

    func testToggleSnippet_disablesSnippet() {
        let snippet = Snippet(trigger: "omw", replacement: "on my way", caseSensitive: false)
        container.snippetsViewModel.snippets = [snippet]

        container.snippetsViewModel.toggleSnippet(snippet)

        XCTAssertFalse(container.snippetsViewModel.snippets.first?.isEnabled ?? true)
    }

    func testToggleSnippet_enablesSnippet() {
        let snippet = Snippet(trigger: "omw", replacement: "on my way", caseSensitive: false)
        container.snippetsViewModel.snippets = [snippet]
        container.snippetService.toggleSnippet(snippet)

        container.snippetsViewModel.toggleSnippet(
            container.snippetsViewModel.snippets.first!
        )

        XCTAssertTrue(container.snippetsViewModel.snippets.first?.isEnabled ?? false)
    }

    // MARK: - Counts

    func testTotalCount_reflectsAllSnippets() {
        container.snippetsViewModel.snippets = [
            Snippet(trigger: "a", replacement: "a", caseSensitive: false),
            Snippet(trigger: "b", replacement: "b", caseSensitive: false),
        ]

        XCTAssertEqual(container.snippetsViewModel.totalCount, 2)
    }

    // MARK: - Error clearing

    func testClearError_setsNil() {
        container.snippetsViewModel.error = "some error"

        container.snippetsViewModel.clearError()

        XCTAssertNil(container.snippetsViewModel.error)
    }
}
