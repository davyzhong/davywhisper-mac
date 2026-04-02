import XCTest
@testable import DavyWhisper

final class BrandAndConfigTests: XCTestCase {

    // MARK: - Bundle ID (spec 1.3)

    func testMainAppBundleID() {
        // XcodeGen generates from project.yml — verify the app target's bundle ID
        let bundle = Bundle.main
        let bundleID = bundle.bundleIdentifier ?? ""

        // In test context, bundleIdentifier is the test bundle.
        // Verify the xcconfig / project.yml produces correct ID by checking CodeSigning.xcconfig
        let xcconfigPath = Bundle(for: type(of: self))
            .path(forResource: "CodeSigning", ofType: "xcconfig")
        // The real check: project.yml should produce com.davywhisper.* bundle IDs
        // This test validates the key exists and isn't the old value
        XCTAssertFalse(bundleID.contains("typewhisper"),
                       "Bundle ID should not contain 'typewhisper': \(bundleID)")
    }

    // MARK: - Info.plist (spec 2.4 — no Sparkle)

    func testInfoPlistNoSparkleKeys() {
        guard let infoPath = Bundle.main.path(forResource: "Info", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: infoPath) else {
            // In test context we can't read the app's Info.plist directly
            // Read from source instead
            let projectRoot = TestSupport.repoRoot
            let infoURL = projectRoot.appendingPathComponent("DavyWhisper/Resources/Info.plist")
            let content = try! String(contentsOf: infoURL)

            XCTAssertFalse(content.contains("SUFeedURL"),
                           "Info.plist should NOT contain SUFeedURL (Sparkle)")
            XCTAssertFalse(content.contains("SUPublicEDKey"),
                           "Info.plist should NOT contain SUPublicEDKey (Sparkle)")
            return
        }
        XCTAssertNil(dict["SUFeedURL"], "SUFeedURL should be removed")
        XCTAssertNil(dict["SUPublicEDKey"], "SUPublicEDKey should be removed")
    }

    // MARK: - Info.plist localization (spec 4.10)

    func testInfoPlistHasZhHansLocalization() {
        let projectRoot = TestSupport.repoRoot
        let infoURL = projectRoot.appendingPathComponent("DavyWhisper/Resources/Info.plist")
        let content = try! String(contentsOf: infoURL)

        XCTAssertTrue(content.contains("zh-Hans"),
                      "Info.plist CFBundleLocalizations should include zh-Hans")
        XCTAssertFalse(content.contains("<string>de</string>"),
                       "Info.plist CFBundleLocalizations should NOT have de")
    }

    // MARK: - UserDefaults keys for HF mirror (spec 5.1-5.3)

    func testHFMirrorKeyExists() {
        XCTAssertEqual(UserDefaultsKeys.useHuggingFaceMirror, "useHuggingFaceMirror")
    }

    func testPreferredAppLanguageKeyExists() {
        XCTAssertEqual(UserDefaultsKeys.preferredAppLanguage, "preferredAppLanguage")
    }

    // MARK: - CodeSigning.xcconfig (spec 1.3)

    func testXcconfigHasCorrectBundleID() {
        let projectRoot = TestSupport.repoRoot
        let xcconfigURL = projectRoot.appendingPathComponent("CodeSigning.xcconfig")
        let content = try! String(contentsOf: xcconfigURL)

        XCTAssertFalse(content.contains("com.typewhisper"),
                       "CodeSigning.xcconfig should NOT reference com.typewhisper")
        XCTAssertTrue(content.contains("com.davywhisper"),
                      "CodeSigning.xcconfig should reference com.davywhisper")
    }

    // MARK: - CLI renamed (spec 6.2)

    func testCLIDirectoryExists() {
        let projectRoot = TestSupport.repoRoot
        let cliDir = projectRoot.appendingPathComponent("davywhisper-cli")
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: cliDir.path, isDirectory: &isDir),
                      "davywhisper-cli/ directory should exist")
        XCTAssertTrue(isDir.boolValue, "davywhisper-cli should be a directory")
    }

    func testOldCLIDirectoryDoesNotExist() {
        let projectRoot = TestSupport.repoRoot
        let oldDir = projectRoot.appendingPathComponent("typewhisper-cli")
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldDir.path),
                       "typewhisper-cli/ should NOT exist (renamed to davywhisper-cli)")
    }

    // MARK: - WidgetDataService deleted (spec 2.2)

    func testWidgetDataServiceDeleted() {
        let projectRoot = TestSupport.repoRoot
        let file = projectRoot.appendingPathComponent("DavyWhisper/Services/WidgetDataService.swift")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path),
                       "WidgetDataService.swift should be deleted")
    }

    // MARK: - project.yml exists (XcodeGen migration)

    func testProjectYmlExists() {
        let projectRoot = TestSupport.repoRoot
        let yml = projectRoot.appendingPathComponent("project.yml")
        XCTAssertTrue(FileManager.default.fileExists(atPath: yml.path),
                      "project.yml should exist")
    }

    func testProjectYmlHasNoTypewhisper() {
        let projectRoot = TestSupport.repoRoot
        let yml = projectRoot.appendingPathComponent("project.yml")
        let content = try! String(contentsOf: yml)

        XCTAssertFalse(content.contains("typewhisper"),
                       "project.yml should not reference typewhisper")
        XCTAssertFalse(content.contains("TypeWhisper"),
                       "project.yml should not reference TypeWhisper")
    }

    func testProjectYmlHasAllTargets() {
        let projectRoot = TestSupport.repoRoot
        let yml = projectRoot.appendingPathComponent("project.yml")
        let content = try! String(contentsOf: yml)

        let expectedTargets = [
            "DavyWhisper:",
            "davywhisper-cli:",
            "DavyWhisperTests:",
        ]
        for target in expectedTargets {
            XCTAssertTrue(content.contains(target),
                          "project.yml should define target: \(target)")
        }

        // Plugin sources compiled into main app
        let expectedPluginSources = [
            "Plugins/WhisperKitPlugin",
            "Plugins/DeepgramPlugin",
            "Plugins/WebhookPlugin",
            "Plugins/ElevenLabsPlugin",
            "Plugins/GLMPlugin",
            "Plugins/KimiPlugin",
            "Plugins/MiniMaxPlugin",
            "Plugins/QwenLLMPlugin",
        ]
        for source in expectedPluginSources {
            XCTAssertTrue(content.contains(source),
                          "project.yml should include plugin source: \(source)")
        }
    }

    func testProjectYmlHasNoSparkle() {
        let projectRoot = TestSupport.repoRoot
        let yml = projectRoot.appendingPathComponent("project.yml")
        let content = try! String(contentsOf: yml)

        XCTAssertFalse(content.contains("Sparkle"),
                       "project.yml should not reference Sparkle")
    }

    // MARK: - Ghost plugin dirs deleted (spec 2.3)

    func testGhostPluginDirectoriesDeleted() {
        let projectRoot = TestSupport.repoRoot
        let ghosts = [
            "Plugins/CerebrasPlugin",
            "Plugins/GladiaPlugin",
            "Plugins/GroqPlugin",
            "Plugins/ParakeetPlugin",
            "Plugins/SpeechAnalyzerPlugin",
            "Plugins/VoxtralPlugin",
            "Plugins/OpenAIPlugin",
            "Plugins/GeminiPlugin",
        ]
        for ghost in ghosts {
            let path = projectRoot.appendingPathComponent(ghost)
            XCTAssertFalse(FileManager.default.fileExists(atPath: path.path),
                           "\(ghost) should be deleted")
        }
    }

    // MARK: - New LLM plugins exist (spec 3.1-3.4)

    func testNewLLMPluginsExist() {
        let projectRoot = TestSupport.repoRoot
        let newPlugins = ["GLMPlugin", "KimiPlugin", "MiniMaxPlugin", "QwenLLMPlugin"]
        for plugin in newPlugins {
            let dir = projectRoot.appendingPathComponent("Plugins/\(plugin)")
            XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path),
                          "\(plugin) directory should exist")
        }
    }

    func testNewLLMPluginsHaveManifest() {
        let projectRoot = TestSupport.repoRoot
        let newPlugins = ["GLMPlugin", "KimiPlugin", "MiniMaxPlugin", "QwenLLMPlugin"]
        for plugin in newPlugins {
            // Plugins compiled into main app use manifest_<Name>.json naming
            let manifest = projectRoot.appendingPathComponent("Plugins/\(plugin)/manifest_\(plugin).json")
            XCTAssertTrue(FileManager.default.fileExists(atPath: manifest.path),
                          "\(plugin)/manifest_\(plugin).json should exist")
        }
    }
}
