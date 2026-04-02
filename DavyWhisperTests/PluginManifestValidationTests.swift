import XCTest
import DavyWhisperPluginSDK
@testable import DavyWhisper

final class PluginManifestValidationTests: XCTestCase {
    func testAllPluginManifestsDecodeAndDeclareCompatibility() throws {
        let projectRoot = TestSupport.repoRoot
        let pluginsDir = projectRoot.appendingPathComponent("Plugins")

        // Find all manifest_*.json files (compiled-in plugins use renamed manifests)
        let pluginDirs = try FileManager.default.contentsOfDirectory(
            at: pluginsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { $0.hasDirectoryPath }

        var manifestURLs: [URL] = []
        for dir in pluginDirs {
            let contents = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            for file in contents where file.lastPathComponent.hasPrefix("manifest_") && file.pathExtension == "json" {
                manifestURLs.append(file)
            }
        }

        XCTAssertFalse(manifestURLs.isEmpty, "Should find at least one manifest_*.json")

        let versionPattern = try NSRegularExpression(pattern: #"^\d+\.\d+(\.\d+)?$"#)

        for manifestURL in manifestURLs {
            let data = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)

            XCTAssertFalse(manifest.id.isEmpty, manifestURL.lastPathComponent)
            XCTAssertFalse(manifest.name.isEmpty, manifestURL.lastPathComponent)
            XCTAssertFalse(manifest.principalClass.isEmpty, manifestURL.lastPathComponent)
            XCTAssertNotNil(manifest.minHostVersion, manifestURL.lastPathComponent)

            let range = NSRange(location: 0, length: manifest.version.utf16.count)
            XCTAssertEqual(versionPattern.firstMatch(in: manifest.version, range: range)?.range, range, manifest.version)
        }
    }
}
