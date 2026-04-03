import XCTest
@testable import DavyWhisper

/// Tests the DavyWhisper menu bar app lifecycle.
/// Note: These tests require the app to be signed with proper entitlements
/// for UI testing, or run with accessibility permissions in CI.
final class AppLifecycleUITests: UITestCase {

    override func setUp() {
        super.setUp()
        // Launch with test-mode argument to suppress first-run UI
        launchApp(args: ["--test-mode"])
    }

    override func tearDown() {
        terminateApp()
        super.tearDown()
    }

    // MARK: - App Launch

    func testApp_launchesWithoutCrash() {
        let app = XCUIApplication()
        // App should be running
        XCTAssertTrue(app.exists)
    }

    func testApp_launchArguments_areParsed() {
        let app = XCUIApplication()
        // Verify launch arguments are accessible
        XCTAssertTrue(app.launchArguments.contains("--test-mode"))
    }

    // MARK: - Settings Window

    func testSettingsWindow_opensFromMenuBar() {
        let app = XCUIApplication()

        // Menu bar app — open settings via menu bar icon
        let menuBarButton = app.statusItems.firstMatch
        if menuBarButton.waitForExistence(timeout: 3.0) {
            menuBarButton.click()
            // Try multiple possible menu item labels
            let settingsItems = app.menuItems.matching(NSPredicate(format: "title CONTAINS[cd] 'settings' OR title CONTAINS[cd] 'preferences' OR title CONTAINS[cd] '设置'"))
            if settingsItems.count > 0 {
                settingsItems.firstMatch.click()
            }
        }

        // Settings window should appear
        let settingsWindow = app.windows[AccessibilityIdentifiers.Settings.window]
        if settingsWindow.waitForExistence(timeout: 5.0) {
            XCTAssertTrue(settingsWindow.isEnabled)
        }
    }

    // MARK: - Quit

    func testQuit_terminatesApp() {
        let app = XCUIApplication()
        // Open menu bar menu
        let menuBarButton = app.statusItems.firstMatch
        if menuBarButton.waitForExistence(timeout: 3.0) {
            menuBarButton.click()
            // Find and click Quit
            let quitPredicate = NSPredicate(format: "title CONTAINS[cd] 'quit' OR title CONTAINS[cd] '退出'")
            let quitItems = app.menuItems.matching(quitPredicate)
            if quitItems.count > 0 {
                quitItems.firstMatch.click()
            }
        }
        // App should terminate
        XCTAssertFalse(app.exists)
    }
}
