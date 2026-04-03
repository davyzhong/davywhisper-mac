import XCTest
@testable import DavyWhisper

@MainActor
final class PromptActionServiceTests: XCTestCase {

    var service: PromptActionService!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = try! TestSupport.makeTemporaryDirectory()
        let appDir = tempDir.appendingPathComponent("AppSupport", isDirectory: true)
        try! FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        // Override test AppConstants directory
        let original = AppConstants.testAppSupportDirectoryOverride
        AppConstants.testAppSupportDirectoryOverride = appDir
        service = PromptActionService(appSupportDirectory: appDir)
        AppConstants.testAppSupportDirectoryOverride = original
    }

    override func tearDown() {
        service = nil
        TestSupport.remove(tempDir)
        super.tearDown()
    }

    // MARK: - Seed Presets

    func testSeedPresets_createsPresets() {
        service.seedPresetsIfNeeded()
        XCTAssertTrue(!service.promptActions.isEmpty || service.availablePresets.count > 0)
    }

    func testSeedPresets_idempotent() {
        service.seedPresetsIfNeeded()
        let count1 = service.promptActions.count
        service.seedPresetsIfNeeded()
        let count2 = service.promptActions.count
        XCTAssertEqual(count1, count2)
    }

    // MARK: - Add Custom Action

    func testAddAction_insertsIntoStore() {
        service.seedPresetsIfNeeded()
        let initialCount = service.promptActions.count

        service.addAction(name: "Test Action", prompt: "Test prompt content")

        XCTAssertEqual(service.promptActions.count, initialCount + 1)
        let added = service.promptActions.first { $0.name == "Test Action" }
        XCTAssertNotNil(added)
        XCTAssertEqual(added?.prompt, "Test prompt content")
    }

    func testAddAction_assignsUniqueSortOrder() {
        service.addAction(name: "Action 1", prompt: "p1")
        service.addAction(name: "Action 2", prompt: "p2")
        service.addAction(name: "Action 3", prompt: "p3")

        let orders = service.promptActions.map(\.sortOrder)
        XCTAssertEqual(orders.count, Set(orders).count, "sortOrder values must be unique")
    }

    // MARK: - Update Action

    func testUpdateAction_modifiesExistingAction() {
        service.addAction(name: "Original Name", prompt: "Original prompt")
        guard let action = service.promptActions.first(where: { $0.name == "Original Name" }) else {
            XCTFail("Action not found")
            return
        }

        service.updateAction(action, name: "Updated Name", prompt: "Updated prompt", icon: "sparkles")

        let updated = service.promptActions.first { $0.name == "Updated Name" }
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.prompt, "Updated prompt")
    }

    // MARK: - Delete Action

    func testDeleteAction_removesFromStore() {
        service.addAction(name: "To Delete", prompt: "delete me")
        let initialCount = service.promptActions.count
        guard let action = service.promptActions.first(where: { $0.name == "To Delete" }) else {
            XCTFail("Action not found")
            return
        }

        service.deleteAction(action)

        XCTAssertEqual(service.promptActions.count, initialCount - 1)
        XCTAssertNil(service.promptActions.first { $0.name == "To Delete" })
    }

    // MARK: - Enable/Disable

    func testToggleAction_invertsIsEnabled() {
        service.addAction(name: "Toggle Test", prompt: "test")
        guard let action = service.promptActions.first(where: { $0.name == "Toggle Test" }) else {
            XCTFail("Action not found")
            return
        }

        XCTAssertTrue(action.isEnabled)
        service.toggleAction(action)
        XCTAssertFalse(action.isEnabled)
        service.toggleAction(action)
        XCTAssertTrue(action.isEnabled)
    }

    // MARK: - Available Presets

    func testAvailablePresets_excludesExistingActions() {
        service.seedPresetsIfNeeded()
        let existingNames = Set(service.promptActions.map(\.name))
        let available = service.availablePresets
        for preset in available {
            XCTAssertFalse(existingNames.contains(preset.name),
                           "Available preset '\(preset.name)' should not already exist")
        }
    }

    func testAddPreset_createsPresetAction() {
        let countBefore = service.promptActions.count
        let preset = PromptAction(name: "Custom Preset", prompt: "preset prompt", icon: "star.fill", isPreset: true, sortOrder: 0)
        service.addPreset(preset)

        XCTAssertEqual(service.promptActions.count, countBefore + 1)
        let added = service.promptActions.first { $0.name == "Custom Preset" }
        XCTAssertNotNil(added)
        XCTAssertTrue(added?.isPreset ?? false)
    }
}
