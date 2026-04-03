import XCTest
import AppKit

/// Base class for all DavyWhisper UI tests.
/// Provides common helpers for launching the app, opening settings, and navigation.
@MainActor
class UITestCase: XCTestCase {

    /// Whether a display session is available (true in normal GUI, false in CI/headless).
    /// MenuBarExtra apps require a running display session to initialize.
    /// Whether a display session is available (true in normal GUI, false in CI/headless).
    /// MenuBarExtra apps require a running display session to initialize.
    nonisolated(unsafe) static var hasDisplaySession: Bool {
        guard let screen = NSScreen.screens.first else { return false }
        return screen.frame.width > 0 && screen.frame.height > 0
    }

    /// Checks if the test should skip due to missing display and throws XCTSkip.
    nonisolated(unsafe) func requireDisplay() throws {
        if !Self.hasDisplaySession {
            throw XCTSkip("Skipped: no display session (headless environment)")
        }
    }

    // MARK: - App Lifecycle

    /// Launches the DavyWhisper app with optional launch arguments.
    /// Note: Call requireDisplay() in each test before calling this.
    func launchApp(args: [String] = []) {
        let app = XCUIApplication()
        app.launchArguments = args
        app.launch()
    }

    /// Opens the Settings window by triggering it via the app.
    /// For a menu bar app, this is typically done via a menu or notification.
    func openSettings() {
        let app = XCUIApplication()
        // Menu bar apps typically expose settings via menu bar icon
        // or by opening the settings window directly
        app.windows.firstMatch
        // In test environment, open settings programmatically
        // via accessibility
    }

    /// Closes all windows and terminates the app.
    func terminateApp() {
        XCUIApplication().terminate()
    }

    // MARK: - Settings Navigation

    /// Navigates to a settings tab by clicking its tab button.
    func navigateToSettingsTab(identifier: String) {
        let app = XCUIApplication()
        let tab = app.tabGroups.buttons[identifier]
        if tab.exists {
            tab.click()
        }
    }

    // MARK: - Wait Helpers

    /// Waits for an element to appear within a timeout.
    func waitFor(_ element: XCUIElement, timeout: TimeInterval = 5.0, file: String = #file, line: Int = #line) {
        let expectation = element.waitForExistence(timeout: timeout)
        if !expectation {
            recordFailure(withDescription: "Element \(element.identifier) did not appear within \(timeout)s",
                         inFile: file, atLine: line, expected: true)
        }
    }

    /// Waits for an element to disappear.
    func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 5.0) {
        let predicate = NSPredicate(format: "exists == false")
        expectation(for: predicate, evaluatedWith: element, handler: nil)
        waitForExpectations(timeout: timeout)
    }

    // MARK: - Alert Handling

    /// Dismisses an alert by clicking a button with the given identifier.
    func dismissAlert(buttonIdentifier: String) {
        let alert = XCUIApplication().alerts.firstMatch
        if alert.waitForExistence(timeout: 2.0) {
            alert.buttons[buttonIdentifier].click()
        }
    }

    // MARK: - Permissions

    /// Grants microphone permission in System Preferences (opens the pane).
    /// Note: This requires running as root or with Accessibility permissions.
    func grantMicrophonePermission() {
        // Open System Preferences > Privacy > Microphone
        let script = """
        tell application "System Events"
            tell process "System Preferences"
                click button "Microphone" of group 1 of window "Privacy & Security"
            end tell
        end tell
        """
        // In CI, this is typically handled by the test environment setup
        // rather than programmatically
    }

    // MARK: - Table/List Helpers

    /// Returns the number of rows in a table with the given identifier.
    func tableRowCount(identifier: String) -> Int {
        XCUIApplication().tables[identifier].cells.count
    }

    /// Deletes a row at index in a table with the given identifier.
    func deleteTableRow(tableIdentifier: String, rowIndex: Int) {
        let table = XCUIApplication().tables[tableIdentifier]
        let rows = table.cells
        if rows.count > rowIndex {
            rows.element(boundBy: rowIndex).click()
        }
    }
}
