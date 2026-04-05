import XCTest
@testable import DavyWhisper

final class ProfileServiceTests: XCTestCase {
    @MainActor
    func testProfileMatchingPrefersBundleAndURLSpecificity() throws {
        let appSupportDirectory = try TestSupport.makeTemporaryDirectory()
        defer { TestSupport.remove(appSupportDirectory) }

        let service = ProfileService(appSupportDirectory: appSupportDirectory)

        service.addProfile(
            name: "Bundle Only",
            bundleIdentifiers: ["com.apple.Safari"]
        )
        service.addProfile(
            name: "URL Only",
            urlPatterns: ["docs.github.com"]
        )
        service.addProfile(
            name: "Bundle + URL",
            bundleIdentifiers: ["com.apple.Safari"],
            urlPatterns: ["github.com"]
        )

        let firstMatch = service.matchProfile(
            bundleIdentifier: "com.apple.Safari",
            url: "https://docs.github.com/en/get-started"
        )
        XCTAssertEqual(firstMatch?.name, "Bundle + URL")

        service.toggleProfile(try XCTUnwrap(firstMatch))

        let fallbackMatch = service.matchProfile(
            bundleIdentifier: "com.apple.Safari",
            url: "https://docs.github.com/en/get-started"
        )
        XCTAssertEqual(fallbackMatch?.name, "URL Only")
    }
}
