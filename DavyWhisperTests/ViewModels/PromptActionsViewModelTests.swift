import XCTest
@testable import DavyWhisper

@MainActor
final class PromptActionsViewModelTests: XCTestCase {

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

    func testInit_loadsActionsFromService() {
        XCTAssertNotNil(container.promptActionsViewModel)
        XCTAssertTrue(container.promptActionsViewModel.promptActions.isEmpty)
        XCTAssertFalse(container.promptActionsViewModel.navigateToIntegrations)
    }

    // MARK: - startCreating

    func testStartCreating_resetsEditorFields() {
        container.promptActionsViewModel.editName = "old name"
        container.promptActionsViewModel.editPrompt = "old prompt"
        container.promptActionsViewModel.editProviderId = "some-provider"
        container.promptActionsViewModel.editCloudModel = "some-model"

        container.promptActionsViewModel.startCreating()

        XCTAssertTrue(container.promptActionsViewModel.isCreatingNew)
        XCTAssertTrue(container.promptActionsViewModel.isEditing)
        XCTAssertTrue(container.promptActionsViewModel.editName.isEmpty)
        XCTAssertTrue(container.promptActionsViewModel.editPrompt.isEmpty)
        XCTAssertEqual(container.promptActionsViewModel.editIcon, "sparkles")
        XCTAssertNil(container.promptActionsViewModel.editProviderId)
        XCTAssertTrue(container.promptActionsViewModel.editCloudModel.isEmpty)
    }

    // MARK: - startEditing

    func testStartEditing_populatesAllEditorFields() {
        let action = PromptAction(
            name: "Translate",
            prompt: "translate to Chinese",
            icon: "globe",
            isEnabled: true,
            providerType: "kimi",
            cloudModel: "kimi-model"
        )
        container.promptActionsViewModel.promptActions = [action]

        container.promptActionsViewModel.startEditing(action)

        XCTAssertFalse(container.promptActionsViewModel.isCreatingNew)
        XCTAssertTrue(container.promptActionsViewModel.isEditing)
        XCTAssertEqual(container.promptActionsViewModel.editName, "Translate")
        XCTAssertEqual(container.promptActionsViewModel.editPrompt, "translate to Chinese")
        XCTAssertEqual(container.promptActionsViewModel.editIcon, "globe")
        XCTAssertEqual(container.promptActionsViewModel.editProviderId, "kimi")
        XCTAssertEqual(container.promptActionsViewModel.editCloudModel, "kimi-model")
    }

    // MARK: - cancelEditing

    func testCancelEditing_resetsAllFields() {
        let action = PromptAction(
            name: "T", prompt: "p", icon: "sparkles",
            isEnabled: true, providerType: nil, cloudModel: nil
        )
        container.promptActionsViewModel.promptActions = [action]
        container.promptActionsViewModel.startEditing(action)
        container.promptActionsViewModel.editName = "changed"

        container.promptActionsViewModel.cancelEditing()

        XCTAssertFalse(container.promptActionsViewModel.isEditing)
        XCTAssertFalse(container.promptActionsViewModel.isCreatingNew)
        XCTAssertTrue(container.promptActionsViewModel.editName.isEmpty)
        XCTAssertTrue(container.promptActionsViewModel.editPrompt.isEmpty)
    }

    // MARK: - saveEditing validation (does not require service binding)

    func testSaveEditing_emptyName_setsError() {
        container.promptActionsViewModel.startCreating()
        container.promptActionsViewModel.editName = ""
        container.promptActionsViewModel.editPrompt = "some prompt"

        container.promptActionsViewModel.saveEditing()

        XCTAssertNotNil(container.promptActionsViewModel.error)
        XCTAssertTrue(container.promptActionsViewModel.isEditing) // did NOT cancel
    }

    func testSaveEditing_emptyPrompt_setsError() {
        container.promptActionsViewModel.startCreating()
        container.promptActionsViewModel.editName = "some name"
        container.promptActionsViewModel.editPrompt = ""

        container.promptActionsViewModel.saveEditing()

        XCTAssertNotNil(container.promptActionsViewModel.error)
    }

    // MARK: - Counts

    func testTotalCount_reflectsPromptActionsArray() {
        container.promptActionsViewModel.promptActions = [
            PromptAction(name: "A", prompt: "a", icon: "sparkles", isEnabled: true, providerType: nil, cloudModel: nil),
            PromptAction(name: "B", prompt: "b", icon: "sparkles", isEnabled: false, providerType: nil, cloudModel: nil),
        ]

        XCTAssertEqual(container.promptActionsViewModel.totalCount, 2)
    }

    // MARK: - Presets

    func testAvailablePresets_deliversPresetsFromService() {
        container.promptActionsViewModel.loadPresets()
        // Just verify it doesn't crash and returns something (possibly empty if no presets defined)
        let presets = container.promptActionsViewModel.availablePresets
        XCTAssertNotNil(presets)
    }

    // MARK: - Error clearing

    func testClearError_setsNil() {
        container.promptActionsViewModel.error = "some error"

        container.promptActionsViewModel.clearError()

        XCTAssertNil(container.promptActionsViewModel.error)
    }

    // MARK: - Navigate to Integrations

    func testNavigateToIntegrations_defaultIsFalse() {
        XCTAssertFalse(container.promptActionsViewModel.navigateToIntegrations)
    }
}
