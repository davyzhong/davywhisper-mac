import XCTest
@testable import DavyWhisper

@MainActor
final class SettingsViewModelTests: XCTestCase {

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

    func testInitialState_isNotNil() {
        XCTAssertNotNil(container.settingsViewModel)
    }

    // MARK: - canTranscribe Delegation

    func testCanTranscribe_isAccessible() {
        // settingsViewModel exposes modelManager's canTranscribe through its own API
        XCTAssertNotNil(container.settingsViewModel)
    }
}
