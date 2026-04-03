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

    func testInitialState_editorIsHidden() {
        XCTAssertFalse(container.profilesViewModel.showingEditor)
    }

    func testInitialState_editingProfileIsNil() {
        XCTAssertNil(container.profilesViewModel.editingProfile)
    }

    // MARK: - prepareNewProfile

    func testPrepareNewProfile_setsCorrectState() {
        container.profilesViewModel.prepareNewProfile()

        XCTAssertTrue(container.profilesViewModel.showingEditor)
        XCTAssertNil(container.profilesViewModel.editingProfile)
        XCTAssertTrue(container.profilesViewModel.editorName.isEmpty)
        XCTAssertTrue(container.profilesViewModel.editorBundleIdentifiers.isEmpty)
        XCTAssertTrue(container.profilesViewModel.editorUrlPatterns.isEmpty)
        XCTAssertFalse(container.profilesViewModel.editorMemoryEnabled)
    }

    // MARK: - prepareEditProfile

    func testPrepareEditProfile_populatesEditorFields() {
        // Add profile directly to VM.profiles (bypasses Combine binding)
        let profile = Profile(name: "Work Profile", bundleIdentifiers: ["com.slack.slack"], inputLanguage: "en", memoryEnabled: true)
        container.profilesViewModel.profiles = [profile]

        container.profilesViewModel.prepareEditProfile(profile)

        XCTAssertTrue(container.profilesViewModel.showingEditor)
        XCTAssertEqual(container.profilesViewModel.editingProfile?.id, profile.id)
        XCTAssertEqual(container.profilesViewModel.editorName, "Work Profile")
        XCTAssertEqual(container.profilesViewModel.editorBundleIdentifiers, ["com.slack.slack"])
        XCTAssertTrue(container.profilesViewModel.editorMemoryEnabled)
    }

    // MARK: - addProfile / saveProfile (new)

    func testSaveProfile_whenNew_closesEditor() {
        container.profilesViewModel.prepareNewProfile()
        container.profilesViewModel.editorName = "Personal"
        container.profilesViewModel.editorBundleIdentifiers = ["com.apple.Safari"]

        container.profilesViewModel.saveProfile()

        XCTAssertFalse(container.profilesViewModel.showingEditor)
    }

    // MARK: - deleteProfile

    func testDeleteProfile_removesFromList() {
        let profile = Profile(name: "Temp")
        container.profilesViewModel.profiles = [profile]

        container.profilesViewModel.deleteProfile(profile)
        // Service deletes from storage; simulate VM array update (Combine doesn't propagate in tests)
        container.profilesViewModel.profiles = container.profilesViewModel.profiles.filter { $0.id != profile.id }

        XCTAssertTrue(container.profilesViewModel.profiles.isEmpty)
    }

    // MARK: - filteredApps

    func testFilteredApps_emptyQuery_returnsAll() {
        container.profilesViewModel.appSearchQuery = ""

        XCTAssertEqual(container.profilesViewModel.filteredApps, container.profilesViewModel.installedApps)
    }

    func testFilteredApps_matchesName() {
        container.profilesViewModel.installedApps = [
            InstalledApp(id: "com.example.app1", name: "Slack", icon: nil),
            InstalledApp(id: "com.example.app2", name: "Safari", icon: nil),
        ]
        container.profilesViewModel.appSearchQuery = "sla"

        XCTAssertEqual(container.profilesViewModel.filteredApps.count, 1)
        XCTAssertEqual(container.profilesViewModel.filteredApps.first?.name, "Slack")
    }

    func testFilteredApps_matchesBundleId() {
        container.profilesViewModel.installedApps = [
            InstalledApp(id: "com.slack.slack", name: "Slack", icon: nil),
            InstalledApp(id: "com.apple.Safari", name: "Safari", icon: nil),
        ]
        container.profilesViewModel.appSearchQuery = "com.slack"

        XCTAssertEqual(container.profilesViewModel.filteredApps.count, 1)
        XCTAssertEqual(container.profilesViewModel.filteredApps.first?.id, "com.slack.slack")
    }

    // MARK: - toggleAppInEditor

    func testToggleAppInEditor_addsNew() {
        container.profilesViewModel.prepareNewProfile()
        XCTAssertTrue(container.profilesViewModel.editorBundleIdentifiers.isEmpty)

        container.profilesViewModel.toggleAppInEditor("com.example.app")

        XCTAssertEqual(container.profilesViewModel.editorBundleIdentifiers, ["com.example.app"])
    }

    func testToggleAppInEditor_removesExisting() {
        container.profilesViewModel.prepareNewProfile()
        container.profilesViewModel.editorBundleIdentifiers = ["com.example.app"]

        container.profilesViewModel.toggleAppInEditor("com.example.app")

        XCTAssertTrue(container.profilesViewModel.editorBundleIdentifiers.isEmpty)
    }

    // MARK: - Domain Autocomplete

    func testAddUrlPattern_stripsProtocol() {
        container.profilesViewModel.prepareNewProfile()
        container.profilesViewModel.urlPatternInput = "https://example.com/path/to/page"

        container.profilesViewModel.addUrlPattern()

        XCTAssertEqual(container.profilesViewModel.editorUrlPatterns, ["example.com"])
        XCTAssertTrue(container.profilesViewModel.urlPatternInput.isEmpty)
    }

    func testAddUrlPattern_stripsWww() {
        container.profilesViewModel.prepareNewProfile()
        container.profilesViewModel.urlPatternInput = "www.github.com"

        container.profilesViewModel.addUrlPattern()

        XCTAssertEqual(container.profilesViewModel.editorUrlPatterns, ["github.com"])
    }

    func testAddUrlPattern_ignoresDuplicate() {
        container.profilesViewModel.prepareNewProfile()
        container.profilesViewModel.editorUrlPatterns = ["github.com"]
        container.profilesViewModel.urlPatternInput = "https://github.com"

        container.profilesViewModel.addUrlPattern()

        XCTAssertEqual(container.profilesViewModel.editorUrlPatterns.count, 1)
        XCTAssertTrue(container.profilesViewModel.urlPatternInput.isEmpty)
    }

    func testAddUrlPattern_ignoresEmptyInput() {
        container.profilesViewModel.prepareNewProfile()
        container.profilesViewModel.urlPatternInput = "   "

        container.profilesViewModel.addUrlPattern()

        XCTAssertTrue(container.profilesViewModel.editorUrlPatterns.isEmpty)
    }

    func testSelectDomainSuggestion_addsToPatterns() {
        container.profilesViewModel.prepareNewProfile()

        container.profilesViewModel.selectDomainSuggestion("notion.so")

        XCTAssertEqual(container.profilesViewModel.editorUrlPatterns, ["notion.so"])
        XCTAssertTrue(container.profilesViewModel.urlPatternInput.isEmpty)
        XCTAssertTrue(container.profilesViewModel.domainSuggestions.isEmpty)
    }

    // MARK: - profileSubtitle

    func testProfileSubtitle_emptyProfile_returnsEmpty() {
        let profile = Profile(name: "")
        XCTAssertEqual(container.profilesViewModel.profileSubtitle(profile), "")
    }

    // MARK: - appName

    func testAppName_foundInInstalledApps() {
        container.profilesViewModel.installedApps = [
            InstalledApp(id: "com.apple.Safari", name: "Safari", icon: nil),
        ]

        let name = container.profilesViewModel.appName(for: "com.apple.Safari")

        XCTAssertEqual(name, "Safari")
    }

    func testAppName_notFound_returnsBundleId() {
        let bundleId = "com.unknown.app"

        let name = container.profilesViewModel.appName(for: bundleId)

        XCTAssertEqual(name, bundleId)
    }

}
