import XCTest
@testable import DavyWhisperPluginSDK

final class PluginManifestTests: XCTestCase {
    func testPluginManifestDecodesOptionalCompatibilityFields() throws {
        let data = Data(
            """
            {
              "id": "com.davywhisper.mock",
              "name": "Mock Plugin",
              "version": "1.2.3",
              "minHostVersion": "1.0.0",
              "minOSVersion": "14.0",
              "author": "DavyWhisper",
              "principalClass": "MockPlugin"
            }
            """.utf8
        )

        let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)

        XCTAssertEqual(
            manifest,
            PluginManifest(
                id: "com.davywhisper.mock",
                name: "Mock Plugin",
                version: "1.2.3",
                minHostVersion: "1.0.0",
                minOSVersion: "14.0",
                author: "DavyWhisper",
                principalClass: "MockPlugin"
            )
        )
    }
}
