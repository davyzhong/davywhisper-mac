import XCTest
@testable import DavyWhisper

@MainActor
final class ModelManagerDefaultEngineTests: XCTestCase {

    private var defaults: MockUserDefaults!

    override func setUp() {
        super.setUp()
        defaults = MockUserDefaults()
    }

    override func tearDown() {
        defaults = nil
        super.tearDown()
    }

    // MARK: - 默认引擎兜底

    func testDefaultEngine_nil_fallsBackToParaformer() {
        // 不设置 selectedEngine → string(forKey:) 返回 nil
        let service = ModelManagerService(userDefaults: defaults)
        XCTAssertEqual(service.selectedProviderId, "paraformer")
    }

    func testDefaultEngine_persistsToUserDefaults() {
        let _ = ModelManagerService(userDefaults: defaults)
        XCTAssertEqual(defaults.string(forKey: "selectedEngine"), "paraformer")
    }

    func testDefaultEngine_existingUser_notOverridden() {
        defaults.set("whisper", forKey: "selectedEngine")
        let service = ModelManagerService(userDefaults: defaults)
        XCTAssertEqual(service.selectedProviderId, "whisper")
    }

    func testDefaultEngineConstant_isParaformer() {
        XCTAssertEqual(ModelManagerService.defaultProviderId, "paraformer")
    }
}
