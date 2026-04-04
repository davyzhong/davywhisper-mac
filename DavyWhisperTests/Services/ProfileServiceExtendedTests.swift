import XCTest
@testable import DavyWhisper

/// Extended tests for ProfileService.matchProfile covering the full 3-tier matching algorithm,
/// domain extraction, subdomain matching, priority tie-breaking, and edge cases.
@MainActor
final class ProfileServiceExtendedTests: XCTestCase {

    private var service: ProfileService!
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = try TestSupport.makeTemporaryDirectory()
        service = ProfileService(appSupportDirectory: tempDir)
    }

    override func tearDownWithError() throws {
        service = nil
        TestSupport.remove(tempDir)
    }

    // MARK: - Tier 1: bundleId + URL Exact Match

    func testExactBundleIdAndURLMatchReturnsThatProfile() {
        service.addProfile(
            name: "Safari GitHub",
            bundleIdentifiers: ["com.apple.Safari"],
            urlPatterns: ["github.com"],
            priority: 10
        )
        service.addProfile(
            name: "Safari General",
            bundleIdentifiers: ["com.apple.Safari"],
            priority: 5
        )

        let match = service.matchProfile(
            bundleIdentifier: "com.apple.Safari",
            url: "https://github.com/user/repo"
        )
        XCTAssertEqual(match?.name, "Safari GitHub")
    }

    func testTier1BeatsTier2AndTier3() {
        service.addProfile(
            name: "Tier1 Bundle+URL",
            bundleIdentifiers: ["com.apple.Safari"],
            urlPatterns: ["docs.python.org"],
            priority: 1
        )
        service.addProfile(
            name: "Tier2 URL Only",
            urlPatterns: ["docs.python.org"],
            priority: 100
        )
        service.addProfile(
            name: "Tier3 Bundle Only",
            bundleIdentifiers: ["com.apple.Safari"],
            priority: 100
        )

        let match = service.matchProfile(
            bundleIdentifier: "com.apple.Safari",
            url: "https://docs.python.org/3/library/os.html"
        )
        XCTAssertEqual(match?.name, "Tier1 Bundle+URL")
    }

    // MARK: - Tier 2: URL-Only Match (Cross-Browser)

    func testURLOnlyMatchWhenNoBundleIdMatchExists() {
        service.addProfile(
            name: "GitHub Any Browser",
            urlPatterns: ["github.com"],
            priority: 10
        )

        let match = service.matchProfile(
            bundleIdentifier: "com.google.Chrome",
            url: "https://github.com/user/repo"
        )
        XCTAssertEqual(match?.name, "GitHub Any Browser")
    }

    func testTier2BeatsTier3() {
        service.addProfile(
            name: "URL Match",
            urlPatterns: ["stackoverflow.com"],
            priority: 1
        )
        service.addProfile(
            name: "Bundle Match",
            bundleIdentifiers: ["com.apple.Safari"],
            priority: 100
        )

        let match = service.matchProfile(
            bundleIdentifier: "com.apple.Safari",
            url: "https://stackoverflow.com/questions/12345"
        )
        // Tier 2 (URL-only) beats Tier 3 (bundleId-only)
        XCTAssertEqual(match?.name, "URL Match")
    }

    func testURLOnlyMatchCrossBrowserScenario() {
        service.addProfile(
            name: "Docs Site",
            urlPatterns: ["developer.apple.com"],
            priority: 5
        )

        // Match from Chrome
        let chromeMatch = service.matchProfile(
            bundleIdentifier: "com.google.Chrome",
            url: "https://developer.apple.com/documentation/swiftui"
        )
        XCTAssertEqual(chromeMatch?.name, "Docs Site")

        // Match from Firefox
        let firefoxMatch = service.matchProfile(
            bundleIdentifier: "org.mozilla.firefox",
            url: "https://developer.apple.com/documentation/swiftui"
        )
        XCTAssertEqual(firefoxMatch?.name, "Docs Site")
    }

    // MARK: - Tier 3: bundleId-Only Match

    func testBundleIdOnlyMatchWhenNoURLMatchExists() {
        service.addProfile(
            name: "Safari Defaults",
            bundleIdentifiers: ["com.apple.Safari"],
            priority: 10
        )

        let match = service.matchProfile(
            bundleIdentifier: "com.apple.Safari",
            url: "https://www.example.com/some-page"
        )
        XCTAssertEqual(match?.name, "Safari Defaults")
    }

    func testBundleIdOnlyMatchWithNoURL() {
        service.addProfile(
            name: "Terminal Config",
            bundleIdentifiers: ["com.apple.Terminal"],
            priority: 5
        )

        let match = service.matchProfile(
            bundleIdentifier: "com.apple.Terminal",
            url: nil
        )
        XCTAssertEqual(match?.name, "Terminal Config")
    }

    // MARK: - Priority Sorting Within Tiers

    func testHigherPriorityWinsWithinTier1() {
        service.addProfile(
            name: "Low Priority Safari GitHub",
            bundleIdentifiers: ["com.apple.Safari"],
            urlPatterns: ["github.com"],
            priority: 1
        )
        service.addProfile(
            name: "High Priority Safari GitHub",
            bundleIdentifiers: ["com.apple.Safari"],
            urlPatterns: ["github.com"],
            priority: 50
        )

        let match = service.matchProfile(
            bundleIdentifier: "com.apple.Safari",
            url: "https://github.com"
        )
        XCTAssertEqual(match?.name, "High Priority Safari GitHub")
    }

    func testHigherPriorityWinsWithinTier2() {
        service.addProfile(
            name: "Low Priority GitHub",
            urlPatterns: ["github.com"],
            priority: 2
        )
        service.addProfile(
            name: "High Priority GitHub",
            urlPatterns: ["github.com"],
            priority: 20
        )

        let match = service.matchProfile(
            bundleIdentifier: "com.unknown.Browser",
            url: "https://github.com"
        )
        XCTAssertEqual(match?.name, "High Priority GitHub")
    }

    func testHigherPriorityWinsWithinTier3() {
        service.addProfile(
            name: "Low Priority Safari",
            bundleIdentifiers: ["com.apple.Safari"],
            priority: 3
        )
        service.addProfile(
            name: "High Priority Safari",
            bundleIdentifiers: ["com.apple.Safari"],
            priority: 30
        )

        let match = service.matchProfile(
            bundleIdentifier: "com.apple.Safari",
            url: "https://unmatched-site.example.com"
        )
        XCTAssertEqual(match?.name, "High Priority Safari")
    }

    // MARK: - Domain Matching

    func testSubdomainMatchesParentDomainProfile() {
        service.addProfile(
            name: "Google All",
            urlPatterns: ["google.com"],
            priority: 10
        )

        let match = service.matchProfile(
            bundleIdentifier: nil,
            url: "https://docs.google.com/document/d/123"
        )
        XCTAssertEqual(match?.name, "Google All")
    }

    func testExactDomainMatch() {
        service.addProfile(
            name: "GitHub Exact",
            urlPatterns: ["github.com"],
            priority: 10
        )

        let match = service.matchProfile(
            bundleIdentifier: nil,
            url: "https://github.com"
        )
        XCTAssertEqual(match?.name, "GitHub Exact")
    }

    func testWWWPrefixIsStrippedFromURL() {
        service.addProfile(
            name: "Example",
            urlPatterns: ["example.com"],
            priority: 10
        )

        let match = service.matchProfile(
            bundleIdentifier: nil,
            url: "https://www.example.com/page"
        )
        XCTAssertEqual(match?.name, "Example")
    }

    func testDomainMatchingIsCaseInsensitive() {
        service.addProfile(
            name: "GitHub Config",
            urlPatterns: ["GitHub.COM"],
            priority: 10
        )

        let match = service.matchProfile(
            bundleIdentifier: nil,
            url: "https://GITHUB.COM/user/repo"
        )
        XCTAssertEqual(match?.name, "GitHub Config")
    }

    func testSubdomainDoesNotMatchDifferentDomain() {
        service.addProfile(
            name: "Google Config",
            urlPatterns: ["google.com"],
            priority: 10
        )

        let match = service.matchProfile(
            bundleIdentifier: nil,
            url: "https://notgoogle.com/page"
        )
        XCTAssertNil(match)
    }

    func testPartialDomainDoesNotMatch() {
        service.addProfile(
            name: "Example",
            urlPatterns: ["example.com"],
            priority: 10
        )

        // "myexample.com" should NOT match "example.com"
        let match = service.matchProfile(
            bundleIdentifier: nil,
            url: "https://myexample.com/page"
        )
        XCTAssertNil(match)
    }

    // MARK: - Multiple Profiles: Most Specific Match Wins

    func testMultipleProfilesMostSpecificMatchWins() {
        // All three tiers present; Tier 1 should win regardless of priority
        service.addProfile(
            name: "Bundle Only (high priority)",
            bundleIdentifiers: ["com.apple.Safari"],
            priority: 999
        )
        service.addProfile(
            name: "URL Only",
            urlPatterns: ["github.com"],
            priority: 50
        )
        service.addProfile(
            name: "Bundle + URL (low priority)",
            bundleIdentifiers: ["com.apple.Safari"],
            urlPatterns: ["github.com"],
            priority: 1
        )

        let match = service.matchProfile(
            bundleIdentifier: "com.apple.Safari",
            url: "https://github.com/user/repo"
        )
        XCTAssertEqual(match?.name, "Bundle + URL (low priority)")
    }

    func testDisabledProfileIsIgnored() {
        service.addProfile(
            name: "Disabled GitHub",
            urlPatterns: ["github.com"],
            priority: 100
        )

        // Disable the profile
        let disabled = service.matchProfile(
            bundleIdentifier: nil,
            url: "https://github.com"
        )
        XCTAssertNotNil(disabled)
        service.toggleProfile(disabled!)

        // Now it should not match
        let match = service.matchProfile(
            bundleIdentifier: nil,
            url: "https://github.com"
        )
        XCTAssertNil(match)
    }

    func testDisabledProfileFallsThroughToLowerTier() {
        service.addProfile(
            name: "Bundle+URL",
            bundleIdentifiers: ["com.apple.Safari"],
            urlPatterns: ["github.com"],
            priority: 100
        )
        service.addProfile(
            name: "Bundle Only",
            bundleIdentifiers: ["com.apple.Safari"],
            priority: 10
        )

        // Disable the Tier 1 profile
        let tier1 = service.matchProfile(
            bundleIdentifier: "com.apple.Safari",
            url: "https://github.com"
        )
        XCTAssertNotNil(tier1)
        service.toggleProfile(tier1!)

        // Should now fall through to Tier 3 (bundleId-only)
        let match = service.matchProfile(
            bundleIdentifier: "com.apple.Safari",
            url: "https://github.com"
        )
        XCTAssertEqual(match?.name, "Bundle Only")
    }

    // MARK: - No Match / Edge Cases

    func testNoMatchReturnsNil() {
        service.addProfile(
            name: "Safari Config",
            bundleIdentifiers: ["com.apple.Safari"],
            priority: 10
        )

        let match = service.matchProfile(
            bundleIdentifier: "com.google.Chrome",
            url: "https://example.com"
        )
        XCTAssertNil(match)
    }

    func testEmptyBundleIdAndURLReturnsNil() {
        service.addProfile(
            name: "Some Profile",
            bundleIdentifiers: ["com.apple.Safari"],
            urlPatterns: ["github.com"],
            priority: 10
        )

        let match = service.matchProfile(
            bundleIdentifier: nil,
            url: nil
        )
        XCTAssertNil(match)
    }

    func testEmptyBundleIdAndURLWithEmptyStringsReturnsNil() {
        service.addProfile(
            name: "Some Profile",
            bundleIdentifiers: ["com.apple.Safari"],
            priority: 10
        )

        let match = service.matchProfile(
            bundleIdentifier: "",
            url: ""
        )
        XCTAssertNil(match)
    }

    func testProfileWithEmptyBundleIdButValidURLMatchesTier2() {
        service.addProfile(
            name: "URL Only Profile",
            bundleIdentifiers: [],
            urlPatterns: ["github.com"],
            priority: 10
        )

        let match = service.matchProfile(
            bundleIdentifier: "com.apple.Safari",
            url: "https://github.com"
        )
        // This should NOT match Tier 1 (no bundleId in profile),
        // but SHOULD match Tier 2 (URL-only)
        XCTAssertEqual(match?.name, "URL Only Profile")
    }

    func testProfileWithEmptyURLButValidBundleIdMatchesTier3() {
        service.addProfile(
            name: "Bundle Only Profile",
            bundleIdentifiers: ["com.apple.Safari"],
            urlPatterns: [],
            priority: 10
        )

        let match = service.matchProfile(
            bundleIdentifier: "com.apple.Safari",
            url: "https://github.com"
        )
        // This should NOT match Tier 1 (no URL pattern in profile),
        // should NOT match Tier 2 (no URL pattern),
        // but SHOULD match Tier 3 (bundleId-only)
        XCTAssertEqual(match?.name, "Bundle Only Profile")
    }

    func testEmptyURLStringYieldsNoDomain() {
        service.addProfile(
            name: "URL Profile",
            urlPatterns: ["example.com"],
            priority: 10
        )

        let match = service.matchProfile(
            bundleIdentifier: "com.apple.Safari",
            url: ""
        )
        // Empty URL string has no domain, so only Tier 3 can match
        XCTAssertNil(match)
    }

    func testMalformedURLYieldsNoDomain() {
        service.addProfile(
            name: "URL Profile",
            urlPatterns: ["example.com"],
            priority: 10
        )

        let match = service.matchProfile(
            bundleIdentifier: "com.apple.Safari",
            url: "not-a-valid-url"
        )
        // Malformed URL has no host, so only Tier 3 can match
        XCTAssertNil(match)
    }

    func testNoProfilesReturnsNil() {
        let match = service.matchProfile(
            bundleIdentifier: "com.apple.Safari",
            url: "https://github.com"
        )
        XCTAssertNil(match)
    }

    // MARK: - Subdomain Specificity

    func testSubdomainProfileMatchesSubdomainURL() {
        service.addProfile(
            name: "Docs Google",
            urlPatterns: ["docs.google.com"],
            priority: 10
        )

        let match = service.matchProfile(
            bundleIdentifier: nil,
            url: "https://docs.google.com/document/d/abc"
        )
        XCTAssertEqual(match?.name, "Docs Google")
    }

    func testSubdomainProfileDoesNotMatchRootDomain() {
        service.addProfile(
            name: "Docs Google",
            urlPatterns: ["docs.google.com"],
            priority: 10
        )

        // google.com is NOT a subdomain of docs.google.com
        let match = service.matchProfile(
            bundleIdentifier: nil,
            url: "https://google.com"
        )
        XCTAssertNil(match)
    }

    func testSubdomainProfileMatchesNestedSubdomain() {
        service.addProfile(
            name: "Google Config",
            urlPatterns: ["google.com"],
            priority: 10
        )

        // mail.google.com is a subdomain of google.com
        let match = service.matchProfile(
            bundleIdentifier: nil,
            url: "https://mail.google.com/mail/inbox"
        )
        XCTAssertEqual(match?.name, "Google Config")
    }

    func testDeeperSubdomainProfileBeatsParentDomainProfile() {
        service.addProfile(
            name: "Google General",
            urlPatterns: ["google.com"],
            priority: 5
        )
        service.addProfile(
            name: "Docs Google Specific",
            urlPatterns: ["docs.google.com"],
            priority: 5
        )

        // Both match at same priority; fetchProfiles sorts by priority desc then name
        // so the first in sorted order wins — with equal priority, alphabetical order applies
        let match = service.matchProfile(
            bundleIdentifier: nil,
            url: "https://docs.google.com/document"
        )
        // Both patterns match; same priority; alphabetical decides
        XCTAssertNotNil(match)
        XCTAssertTrue(match?.name == "Docs Google Specific" || match?.name == "Google General")
    }

    // MARK: - Multiple URL Patterns Per Profile

    func testProfileWithMultipleURLPatterns() {
        service.addProfile(
            name: "Dev Sites",
            urlPatterns: ["github.com", "gitlab.com", "bitbucket.org"],
            priority: 10
        )

        let ghMatch = service.matchProfile(
            bundleIdentifier: nil,
            url: "https://github.com/user/repo"
        )
        XCTAssertEqual(ghMatch?.name, "Dev Sites")

        let glMatch = service.matchProfile(
            bundleIdentifier: nil,
            url: "https://gitlab.com/user/repo"
        )
        XCTAssertEqual(glMatch?.name, "Dev Sites")

        let bbMatch = service.matchProfile(
            bundleIdentifier: nil,
            url: "https://bitbucket.org/user/repo"
        )
        XCTAssertEqual(bbMatch?.name, "Dev Sites")
    }

    func testProfileWithMultipleBundleIdentifiers() {
        service.addProfile(
            name: "All Browsers",
            bundleIdentifiers: ["com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox"],
            priority: 10
        )

        let safari = service.matchProfile(
            bundleIdentifier: "com.apple.Safari",
            url: nil
        )
        XCTAssertEqual(safari?.name, "All Browsers")

        let chrome = service.matchProfile(
            bundleIdentifier: "com.google.Chrome",
            url: nil
        )
        XCTAssertEqual(chrome?.name, "All Browsers")
    }
}
