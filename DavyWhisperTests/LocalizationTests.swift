import XCTest
@testable import DavyWhisper

final class LocalizationTests: XCTestCase {

    // MARK: - Main app xcstrings has zh-Hans (spec 4.1)

    func testMainAppHasZhHans() {
        let projectRoot = TestSupport.repoRoot
        let xcstrings = projectRoot.appendingPathComponent("DavyWhisper/Resources/Localizable.xcstrings")
        guard let data = try? Data(contentsOf: xcstrings),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: Any] else {
            XCTFail("Failed to parse Localizable.xcstrings")
            return
        }

        var zhHansCount = 0
        for (_, value) in strings {
            guard let translation = value as? [String: Any],
                  let localizations = translation["localizations"] as? [String: Any],
                  localizations["zh-Hans"] != nil else { continue }
            zhHansCount += 1
        }

        XCTAssertGreaterThan(zhHansCount, 0,
                             "Main app Localizable.xcstrings should have zh-Hans translations")
    }

    // MARK: - Main app xcstrings has NO de (spec 4.10)

    func testMainAppHasNoDe() {
        let projectRoot = TestSupport.repoRoot
        let xcstrings = projectRoot.appendingPathComponent("DavyWhisper/Resources/Localizable.xcstrings")
        let content = try! String(contentsOf: xcstrings)

        // "de" as a top-level language key (not substring of other words)
        // In xcstrings, locale keys appear as: "de" : { ... }
        XCTAssertFalse(content.contains("\"de\" :"),
                       "Main app Localizable.xcstrings should NOT have German (de) localization")
        XCTAssertFalse(content.contains("\"de\":"),
                       "Main app Localizable.xcstrings should NOT have German (de) localization")
    }

    // MARK: - Plugin xcstrings have zh-Hans (spec 4.3-4.9)

    func testPluginLocalizationsAreZhHans() {
        let projectRoot = TestSupport.repoRoot
        let plugins = [
            "WhisperKitPlugin", "DeepgramPlugin",
            "LiveTranscriptPlugin", "Qwen3Plugin",
        ]
        for plugin in plugins {
            let xcstrings = projectRoot.appendingPathComponent("Plugins/\(plugin)/Localizable.xcstrings")
            guard let data = try? Data(contentsOf: xcstrings) else {
                continue // some plugins may not have xcstrings
            }
            let content = String(data: data, encoding: .utf8) ?? ""

            XCTAssertFalse(content.contains("\"de\" :") || content.contains("\"de\":"),
                           "\(plugin) Localizable.xcstrings should NOT have 'de'")
            XCTAssertTrue(content.contains("zh-Hans"),
                          "\(plugin) Localizable.xcstrings should have zh-Hans")
        }
    }

    // MARK: - New LLM plugins have zh-Hans (spec 4.9)

    func testNewLLMPluginsHaveZhHans() {
        let projectRoot = TestSupport.repoRoot
        let newPlugins = ["GLMPlugin", "KimiPlugin", "MiniMaxPlugin", "QwenLLMPlugin"]
        for plugin in newPlugins {
            let xcstrings = projectRoot.appendingPathComponent("Plugins/\(plugin)/Localizable.xcstrings")
            guard let data = try? Data(contentsOf: xcstrings) else {
                continue
            }
            let content = String(data: data, encoding: .utf8) ?? ""
            XCTAssertTrue(content.contains("zh-Hans"),
                          "\(plugin) should have zh-Hans localization")
        }
    }

    // MARK: - Info.plist CFBundleLocalizations (spec 4.10)

    func testInfoPlistLocalizationsHasZhHans() {
        let projectRoot = TestSupport.repoRoot
        let infoURL = projectRoot.appendingPathComponent("DavyWhisper/Resources/Info.plist")
        let content = try! String(contentsOf: infoURL)

        XCTAssertTrue(content.contains("zh-Hans"),
                      "CFBundleLocalizations should include zh-Hans")
    }

    // MARK: - Language selector includes zh-Hans (spec 4.2)

    func testSetupWizardHasChineseOption() {
        let projectRoot = TestSupport.repoRoot
        let settingsView = projectRoot.appendingPathComponent("DavyWhisper/Views/GeneralSettingsView.swift")
        let content = try! String(contentsOf: settingsView)

        XCTAssertTrue(content.contains("zh-Hans"),
                      "GeneralSettingsView should reference zh-Hans")
        XCTAssertTrue(content.contains("简体中文") || content.contains("Chinese"),
                      "GeneralSettingsView should have Chinese language option")
    }
}
