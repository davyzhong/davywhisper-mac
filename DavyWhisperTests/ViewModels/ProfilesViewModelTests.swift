import XCTest
@testable import DavyWhisper

@MainActor
final class ProfilesViewModelTests: XCTestCase {

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

    func testInitialState_hasEmptyProfiles() {
        XCTAssertNotNil(container.profilesViewModel)
        XCTAssertTrue(container.profilesViewModel.profiles.isEmpty)
    }
}
