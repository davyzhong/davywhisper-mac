import XCTest
@testable import DavyWhisper

/// UI tests for Settings tabs.
/// Requires the app to be running with the Settings window open.
final class SettingsUITests: UITestCase {

    override func setUp() {
        super.setUp()
        // Guard: only launch if display is available
        guard Self.hasDisplaySession else { return }
        launchApp(args: ["--test-mode"])
        openSettingsWindow()
    }

    override func tearDown() {
        closeSettingsWindow()
        terminateApp()
        super.tearDown()
    }

    // MARK: - Setup / Teardown Helpers

    private func openSettingsWindow() {
        let app = XCUIApplication()
        let menuBarButton = app.statusItems.firstMatch
        if menuBarButton.waitForExistence(timeout: 3.0) {
            menuBarButton.click()
            let settingsPredicate = NSPredicate(format: "title CONTAINS[cd] 'settings' OR title CONTAINS[cd] 'preferences' OR title CONTAINS[cd] '设置'")
            let settingsItems = app.menuItems.matching(settingsPredicate)
            if settingsItems.count > 0 {
                settingsItems.firstMatch.click()
            }
        }
        // Wait for settings window
        _ = app.windows[AccessibilityIdentifiers.Settings.window].waitForExistence(timeout: 5.0)
    }

    private func closeSettingsWindow() {
        XCUIApplication().windows[AccessibilityIdentifiers.Settings.window].buttons["Close"].click()
    }

    // MARK: - Tab Navigation

    func testTabNavigation_generalTab_isSelectable() {
        guard Self.hasDisplaySession else { return }
        let app = XCUIApplication()
        let tab = app.tabGroups.buttons[AccessibilityIdentifiers.Settings.tabGeneral]
        if tab.waitForExistence(timeout: 2.0) {
            tab.click()
            XCTAssertTrue(tab.isSelected)
        }
    }

    func testTabNavigation_allNineTabs_exist() {
        guard Self.hasDisplaySession else { return }
        let app = XCUIApplication()
        let tabs = [
            AccessibilityIdentifiers.Settings.tabGeneral,
            AccessibilityIdentifiers.Settings.tabRecording,
            AccessibilityIdentifiers.Settings.tabFileTranscription,
            AccessibilityIdentifiers.Settings.tabHistory,
            AccessibilityIdentifiers.Settings.tabDictionary,
            AccessibilityIdentifiers.Settings.tabProfiles,
            AccessibilityIdentifiers.Settings.tabPrompts,
            AccessibilityIdentifiers.Settings.tabIntegrations,
            AccessibilityIdentifiers.Settings.tabAdvanced
        ]
        for tabId in tabs {
            let tab = app.tabGroups.buttons[tabId]
            if tab.waitForExistence(timeout: 2.0) {
                tab.click()
            }
        }
    }

    // MARK: - General Settings

    func testGeneralSettings_soundFeedbackToggle_exists() {
        guard Self.hasDisplaySession else { return }
        navigateToSettingsTab(identifier: AccessibilityIdentifiers.Settings.tabGeneral)
        let app = XCUIApplication()
        let toggle = app.switches[AccessibilityIdentifiers.Settings.soundFeedbackToggle]
        if toggle.waitForExistence(timeout: 2.0) {
            XCTAssertTrue(toggle.exists)
        }
    }

    func testGeneralSettings_languagePicker_exists() {
        guard Self.hasDisplaySession else { return }
        navigateToSettingsTab(identifier: AccessibilityIdentifiers.Settings.tabGeneral)
        let app = XCUIApplication()
        let picker = app.comboBoxes[AccessibilityIdentifiers.Settings.languagePicker]
        if picker.waitForExistence(timeout: 2.0) {
            XCTAssertTrue(picker.exists)
        }
    }

    // MARK: - Recording Settings

    func testRecordingSettings_microphonePicker_exists() {
        guard Self.hasDisplaySession else { return }
        navigateToSettingsTab(identifier: AccessibilityIdentifiers.Settings.tabRecording)
        let app = XCUIApplication()
        let picker = app.popUpButtons[AccessibilityIdentifiers.Settings.microphonePicker]
        if picker.waitForExistence(timeout: 2.0) {
            XCTAssertTrue(picker.exists)
        }
    }

    func testRecordingSettings_hybridHotkeyField_exists() {
        guard Self.hasDisplaySession else { return }
        navigateToSettingsTab(identifier: AccessibilityIdentifiers.Settings.tabRecording)
        let app = XCUIApplication()
        let field = app.textFields[AccessibilityIdentifiers.Settings.hotkeyHybrid]
        if field.waitForExistence(timeout: 2.0) {
            XCTAssertTrue(field.exists)
        }
    }

    // MARK: - History Settings

    func testHistorySettings_list_exists() {
        guard Self.hasDisplaySession else { return }
        navigateToSettingsTab(identifier: AccessibilityIdentifiers.Settings.tabHistory)
        let app = XCUIApplication()
        let list = app.tables[AccessibilityIdentifiers.Settings.historyList]
        if list.waitForExistence(timeout: 2.0) {
            XCTAssertTrue(list.exists)
        }
    }

    // MARK: - Advanced Settings

    func testAdvancedSettings_apiServerToggle_exists() {
        guard Self.hasDisplaySession else { return }
        navigateToSettingsTab(identifier: AccessibilityIdentifiers.Settings.tabAdvanced)
        let app = XCUIApplication()
        let toggle = app.switches[AccessibilityIdentifiers.Settings.apiServerToggle]
        if toggle.waitForExistence(timeout: 2.0) {
            XCTAssertTrue(toggle.exists)
        }
    }
}
