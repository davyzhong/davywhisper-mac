import XCTest
@testable import DavyWhisper

@MainActor
final class ProfileEngineMigrationTests: XCTestCase {

    private var defaults: MockUserDefaults!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        defaults = MockUserDefaults()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProfileMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        defaults = nil
        super.tearDown()
    }

    // MARK: - F1-2: Profile 引擎迁移

    func testMigrate_whisperOverride_becomesParaformer() {
        let service = ProfileService(appSupportDirectory: tempDir)
        service.addProfile(name: "Test", engineOverride: "whisper")

        service.migrateDefaultEngine(userDefaults: defaults)

        let migrated = service.profiles.first { $0.name == "Test" }
        XCTAssertEqual(migrated?.engineOverride, "paraformer")
    }

    func testMigrate_onlyRunsOnce() {
        let service = ProfileService(appSupportDirectory: tempDir)
        service.addProfile(name: "Test", engineOverride: "whisper")

        service.migrateDefaultEngine(userDefaults: defaults)
        // Manually set back
        service.profiles.first { $0.name == "Test" }?.engineOverride = "whisper"

        service.migrateDefaultEngine(userDefaults: defaults)

        // Second run should not re-migrate
        let profile = service.profiles.first { $0.name == "Test" }
        XCTAssertEqual(profile?.engineOverride, "whisper")
    }

    func testMigrate_noOverride_noAction() {
        let service = ProfileService(appSupportDirectory: tempDir)
        service.addProfile(name: "NoOverride", engineOverride: nil)

        service.migrateDefaultEngine(userDefaults: defaults)

        let profile = service.profiles.first { $0.name == "NoOverride" }
        XCTAssertNil(profile?.engineOverride)
    }

    func testMigrate_nonWhisperOverride_preserved() {
        let service = ProfileService(appSupportDirectory: tempDir)
        service.addProfile(name: "Deepgram", engineOverride: "deepgram")

        service.migrateDefaultEngine(userDefaults: defaults)

        let profile = service.profiles.first { $0.name == "Deepgram" }
        XCTAssertEqual(profile?.engineOverride, "deepgram")
    }

    func testMigrate_setsUserDefaultsFlag() {
        let service = ProfileService(appSupportDirectory: tempDir)
        service.addProfile(name: "Test", engineOverride: "whisper")

        service.migrateDefaultEngine(userDefaults: defaults)

        XCTAssertTrue(defaults.bool(forKey: "didMigrateDefaultEngine_v1"))
    }
}
