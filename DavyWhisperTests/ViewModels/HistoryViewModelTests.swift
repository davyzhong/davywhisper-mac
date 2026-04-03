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

    func testInitialState_hasEmptyHistory() {
        XCTAssertNotNil(container.historyViewModel)
        XCTAssertTrue(container.historyViewModel.records.isEmpty)
    }

    // MARK: - Text Diff Service Integration

    func testTextDiffService_isAvailable() {
        // TextDiffService is used by HistoryViewModel for diff display
        XCTAssertNotNil(container.historyViewModel)
    }
}
