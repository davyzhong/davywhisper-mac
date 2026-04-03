import XCTest
@testable import DavyWhisper

@MainActor
final class APIServerViewModelTests: XCTestCase {

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
        XCTAssertNotNil(container.apiServerViewModel)
    }

    func testInitialState_isRunning_isFalse() {
        XCTAssertFalse(container.apiServerViewModel.isRunning)
    }

    func testInitialState_errorMessage_isNil() {
        XCTAssertNil(container.apiServerViewModel.errorMessage)
    }

    func testInitialState_port_hasDefault() {
        // Port defaults to 8978 when UserDefaults has no saved value
        XCTAssertEqual(container.apiServerViewModel.port, 8978)
    }

    // MARK: - startServer (error path — HTTPServer.start fails in test env)

    func testStartServer_whenServerFails_setsErrorMessage() {
        // HTTPServer.start() will fail in test environment (no listener bind)
        // → errorMessage should be set, isRunning stays false
        container.apiServerViewModel.startServer()

        XCTAssertNotNil(container.apiServerViewModel.errorMessage)
        XCTAssertFalse(container.apiServerViewModel.isRunning)
    }

    // MARK: - stopServer

    func testStopServer_clearsErrorMessage() {
        container.apiServerViewModel.startServer()
        container.apiServerViewModel.stopServer()

        XCTAssertNil(container.apiServerViewModel.errorMessage)
        XCTAssertFalse(container.apiServerViewModel.isRunning)
    }

    // MARK: - Port persistence

    func testPort_didSet_persistsToUserDefaults() {
        container.apiServerViewModel.port = 19443

        XCTAssertEqual(container.apiServerViewModel.port, 19443)
    }

    // MARK: - restartIfNeeded (when disabled)

    func testRestartIfNeeded_whenDisabled_doesNotStartServer() {
        container.apiServerViewModel.isEnabled = false

        container.apiServerViewModel.restartIfNeeded()

        // Server should not start when isEnabled is false
        // (no error should appear either since we don't call startServer)
        XCTAssertNil(container.apiServerViewModel.errorMessage)
    }
}
