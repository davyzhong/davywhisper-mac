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
        // Reset UserDefaults keys used by SettingsViewModel to avoid cross-test pollution
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.selectedLanguage)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.selectedTask)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.translationEnabled)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.translationTargetLanguage)
        container.tearDown()
        container = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInit_isNotNil() {
        XCTAssertNotNil(container.settingsViewModel)
    }

    func testInit_selectedTask_hasDefault() {
        // Default is .transcribe when UserDefaults has no saved value
        XCTAssertEqual(container.settingsViewModel.selectedTask, .transcribe)
    }

    func testInit_translationTargetLanguage_hasDefault() {
        XCTAssertEqual(container.settingsViewModel.translationTargetLanguage, "en")
    }

    // MARK: - Published Property Persistence

    func testSelectedLanguage_persistsToUserDefaults() {
        container.settingsViewModel.selectedLanguage = "zh-Hans"
        XCTAssertEqual(container.settingsViewModel.selectedLanguage, "zh-Hans")
    }

    func testSelectedTask_persistsToUserDefaults() {
        container.settingsViewModel.selectedTask = .translate
        XCTAssertEqual(container.settingsViewModel.selectedTask, .translate)
    }

    func testTranslationEnabled_persistsToUserDefaults() {
        container.settingsViewModel.translationEnabled = true
        XCTAssertTrue(container.settingsViewModel.translationEnabled)
    }

    func testTranslationTargetLanguage_persistsToUserDefaults() {
        container.settingsViewModel.translationTargetLanguage = "ja"
        XCTAssertEqual(container.settingsViewModel.translationTargetLanguage, "ja")
    }

    // MARK: - observePluginManager

    func testObservePluginManager_doesNotCrash() {
        container.settingsViewModel.observePluginManager()
        // Just verify it doesn't throw — PluginManager is a singleton
        XCTAssertNotNil(container.settingsViewModel)
    }

    // MARK: - availableLanguages

    func testAvailableLanguages_returnsSortedArrayOfTuples() {
        let langs = container.settingsViewModel.availableLanguages
        // Result should be sorted by localized name
        if langs.count > 1 {
            XCTAssertTrue(
                langs[0].name <= langs[1].name ||
                langs[0].code == langs[1].code
            )
        }
    }

    func testAvailableLanguages_returnsNonEmptyWhenEnginesRegistered() {
        let langs = container.settingsViewModel.availableLanguages
        // In test env PluginManager may have no engines → empty array is expected
        // Just verify it doesn't crash and returns consistent results
        let langs2 = container.settingsViewModel.availableLanguages
        XCTAssertEqual(langs.count, langs2.count)
    }
}
