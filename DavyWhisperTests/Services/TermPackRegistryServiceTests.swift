import XCTest
@testable import DavyWhisper

@MainActor
final class TermPackRegistryServiceTests: XCTestCase {

    // MARK: - Test Helpers

    private var testURL: URL!

    override func setUp() {
        super.setUp()
        testURL = URL(string: "https://example.test/termpacks.json")!
    }

    override func tearDown() {
        testURL = nil
        super.tearDown()
    }

    /// Creates a service with a mocked fetchData closure that returns the provided JSON data.
    private func makeService(
        json: String,
        userDefaults: UserDefaults = UserDefaults(suiteName: "TermPackRegistryTest")!
    ) -> TermPackRegistryService {
        let responseData = Data(json.utf8)
        let capturedURL = self.testURL!
        let mockFetch: @Sendable (URLRequest) async throws -> (Data, URLResponse) = { _ in
            let response = HTTPURLResponse(
                url: capturedURL,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [:]
            )!
            return (responseData, response)
        }
        return TermPackRegistryService(
            registryURL: capturedURL,
            cacheDuration: 0,
            userDefaults: userDefaults,
            fetchData: mockFetch
        )
    }

    /// Creates a service whose fetchData throws the provided error.
    private func makeFailingService(
        error: Error,
        userDefaults: UserDefaults = UserDefaults(suiteName: "TermPackRegistryTest")!
    ) -> TermPackRegistryService {
        let capturedURL = self.testURL!
        let mockFetch: @Sendable (URLRequest) async throws -> (Data, URLResponse) = { _ in
            throw error
        }
        return TermPackRegistryService(
            registryURL: capturedURL,
            cacheDuration: 0,
            userDefaults: userDefaults,
            fetchData: mockFetch
        )
    }

    // MARK: - Valid Registry Response

    func testFetchRegistry_withValidJSON_populatesCommunityPacks() async {
        let json = """
        {
            "schemaVersion": 1,
            "packs": [
                {
                    "id": "community-pack-1",
                    "name": "Community Pack One",
                    "description": "A test community pack",
                    "icon": "star",
                    "version": "1.0.0",
                    "author": "TestAuthor",
                    "terms": ["FooTerm", "BarTerm"]
                },
                {
                    "id": "community-pack-2",
                    "name": "Community Pack Two",
                    "description": "Another test pack",
                    "icon": "bolt",
                    "version": "2.1.3",
                    "author": "OtherAuthor",
                    "terms": ["BazTerm"]
                }
            ]
        }
        """
        let service = makeService(json: json)
        let result = await service.fetchRegistry()

        XCTAssertTrue(result, "fetchRegistry should return true on success")
        XCTAssertEqual(service.fetchState, .loaded, "fetchState should be .loaded")
        XCTAssertEqual(service.communityPacks.count, 2, "Should load 2 packs")
    }

    func testFetchRegistry_withValidJSON_setsPackProperties() async {
        let json = """
        {
            "schemaVersion": 1,
            "packs": [
                {
                    "id": "test-pack",
                    "name": "Test Pack",
                    "description": "Description here",
                    "icon": "star",
                    "version": "3.2.1",
                    "author": "AuthorName",
                    "terms": ["Term1", "Term2"],
                    "corrections": [
                        {"original": "errror", "replacement": "error", "caseSensitive": false}
                    ]
                }
            ]
        }
        """
        let service = makeService(json: json)
        let _ = await service.fetchRegistry()

        XCTAssertEqual(service.communityPacks.count, 1)
        let pack = service.communityPacks[0]
        XCTAssertEqual(pack.id, "test-pack")
        XCTAssertEqual(pack.defaultName, "Test Pack")
        XCTAssertEqual(pack.defaultDescription, "Description here")
        XCTAssertEqual(pack.icon, "star")
        XCTAssertEqual(pack.version, "3.2.1")
        XCTAssertEqual(pack.author, "AuthorName")
        XCTAssertEqual(pack.terms, ["Term1", "Term2"])
        XCTAssertEqual(pack.corrections.count, 1)
        XCTAssertEqual(pack.corrections[0].original, "errror")
        XCTAssertEqual(pack.corrections[0].replacement, "error")
        XCTAssertEqual(pack.source, .community)
    }

    func testFetchRegistry_packsSortedByName() async {
        let json = """
        {
            "schemaVersion": 1,
            "packs": [
                {
                    "id": "z-pack",
                    "name": "Zebra Pack",
                    "description": "Z",
                    "icon": "z",
                    "version": "1.0.0",
                    "author": "A",
                    "terms": ["Z"]
                },
                {
                    "id": "a-pack",
                    "name": "Alpha Pack",
                    "description": "A",
                    "icon": "a",
                    "version": "1.0.0",
                    "author": "A",
                    "terms": ["A"]
                },
                {
                    "id": "m-pack",
                    "name": "Middle Pack",
                    "description": "M",
                    "icon": "m",
                    "version": "1.0.0",
                    "author": "A",
                    "terms": ["M"]
                }
            ]
        }
        """
        let service = makeService(json: json)
        let _ = await service.fetchRegistry()

        let names = service.communityPacks.map(\.defaultName)
        XCTAssertEqual(names, ["Alpha Pack", "Middle Pack", "Zebra Pack"],
                       "Packs should be sorted by name case-insensitively")
    }

    // MARK: - Localized Names and Descriptions

    func testFetchRegistry_withLocalizedData() async {
        let json = """
        {
            "schemaVersion": 1,
            "packs": [
                {
                    "id": "l10n-pack",
                    "name": "Localized Pack",
                    "description": "Default desc",
                    "icon": "globe",
                    "version": "1.0.0",
                    "author": "Test",
                    "terms": ["Hello"],
                    "names": {"zh": "本地化包"},
                    "descriptions": {"zh": "中文描述"}
                }
            ]
        }
        """
        let service = makeService(json: json)
        let _ = await service.fetchRegistry()

        XCTAssertEqual(service.communityPacks.count, 1)
        let pack = service.communityPacks[0]
        XCTAssertEqual(pack.localizedNames?["zh"], "本地化包")
        XCTAssertEqual(pack.localizedDescriptions?["zh"], "中文描述")
    }

    // MARK: - Invalid / Malformed JSON

    func testFetchRegistry_withInvalidJSON_returnsFalse() async {
        let service = makeService(json: "this is not json at all {{{")
        let result = await service.fetchRegistry()

        XCTAssertFalse(result, "fetchRegistry should return false on decode failure")
        if case .error(let message) = service.fetchState {
            XCTAssertFalse(message.isEmpty, "Error state should contain a message")
        } else {
            XCTFail("fetchState should be .error after JSON decode failure")
        }
    }

    func testFetchRegistry_withEmptyData_returnsFalse() async {
        let service = makeService(json: "")
        let result = await service.fetchRegistry()

        XCTAssertFalse(result, "fetchRegistry should return false on empty data")
    }

    func testFetchRegistry_withPartialJSON_returnsFalse() async {
        // Valid JSON but missing required fields
        let json = """
        {
            "schemaVersion": 1,
            "packs": [
                {"id": "incomplete"}
            ]
        }
        """
        let service = makeService(json: json)
        let result = await service.fetchRegistry()

        XCTAssertFalse(result, "fetchRegistry should return false when packs have missing required fields")
        if case .error = service.fetchState {
            // expected
        } else {
            XCTFail("fetchState should be .error for partial JSON")
        }
    }

    func testFetchRegistry_withNetworkError_returnsFalse() async {
        let service = makeFailingService(
            error: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet,
                           userInfo: [NSLocalizedDescriptionKey: "No internet connection"])
        )
        let result = await service.fetchRegistry()

        XCTAssertFalse(result, "fetchRegistry should return false on network error")
        if case .error(let message) = service.fetchState {
            XCTAssertTrue(message.contains("internet") || message.contains("No"),
                          "Error message should describe the network failure")
        } else {
            XCTFail("fetchState should be .error after network failure")
        }
    }

    // MARK: - Schema Version Validation

    func testFetchRegistry_withUnsupportedSchemaVersion_returnsFalse() async {
        let json = """
        {
            "schemaVersion": 99,
            "packs": [
                {
                    "id": "future-pack",
                    "name": "Future",
                    "description": "From the future",
                    "icon": "rocket",
                    "version": "1.0.0",
                    "author": "TimeTraveler",
                    "terms": ["Quantum"]
                }
            ]
        }
        """
        let service = makeService(json: json)
        let result = await service.fetchRegistry()

        XCTAssertFalse(result, "fetchRegistry should return false for unsupported schema version")
        if case .error(let message) = service.fetchState {
            XCTAssertTrue(message.contains("99"), "Error should mention the unsupported version")
        } else {
            XCTFail("fetchState should be .error for unsupported schema version")
        }
    }

    // MARK: - Empty Packs Array

    func testFetchRegistry_withEmptyPacksArray_succeedsWithNoPacks() async {
        let json = """
        {
            "schemaVersion": 1,
            "packs": []
        }
        """
        let service = makeService(json: json)
        let result = await service.fetchRegistry()

        XCTAssertTrue(result, "fetchRegistry should return true even with empty packs array")
        XCTAssertEqual(service.communityPacks.count, 0, "communityPacks should be empty")
        XCTAssertEqual(service.fetchState, .loaded)
    }

    // MARK: - Built-in Term Pack Collision Detection

    func testFetchRegistry_skipsBuiltInPackIDs() async {
        // "web-dev" is one of the built-in IDs in TermPack.builtInIDs
        let json = """
        {
            "schemaVersion": 1,
            "packs": [
                {
                    "id": "web-dev",
                    "name": "Fake Web Dev",
                    "description": "Should be filtered",
                    "icon": "globe",
                    "version": "1.0.0",
                    "author": "Attacker",
                    "terms": ["Evil"]
                },
                {
                    "id": "safe-pack",
                    "name": "Safe Pack",
                    "description": "Should remain",
                    "icon": "checkmark",
                    "version": "1.0.0",
                    "author": "Good",
                    "terms": ["Good"]
                }
            ]
        }
        """
        let service = makeService(json: json)
        let _ = await service.fetchRegistry()

        let ids = service.communityPacks.map(\.id)
        XCTAssertFalse(ids.contains("web-dev"), "Built-in pack IDs should be filtered out")
        XCTAssertTrue(ids.contains("safe-pack"), "Non-colliding pack should be kept")
        XCTAssertEqual(service.communityPacks.count, 1)
    }

    func testFetchRegistry_skipsAllBuiltInPackIDs() async {
        // All built-in IDs from TermPack.allPacks
        let builtInIDs = TermPack.builtInIDs
        var packEntries = builtInIDs.map { id in
            """
            {"id": "\(id)", "name": "Fake \(id)", "description": "Fake", "icon": "x", "version": "1.0.0", "author": "X", "terms": ["Fake"]}
            """
        }.joined(separator: ",\n")

        // Add one safe pack
        packEntries += """
        ,\n{
            "id": "legit-community-pack",
            "name": "Legit",
            "description": "Legit",
            "icon": "checkmark",
            "version": "1.0.0",
            "author": "Good",
            "terms": ["Real"]
        }
        """

        let json = """
        {
            "schemaVersion": 1,
            "packs": [\(packEntries)]
        }
        """
        let service = makeService(json: json)
        let _ = await service.fetchRegistry()

        XCTAssertEqual(service.communityPacks.count, 1, "Only the non-built-in pack should survive")
        XCTAssertEqual(service.communityPacks[0].id, "legit-community-pack")
    }

    // MARK: - Duplicate ID Filtering

    func testFetchRegistry_skipsDuplicatePackIDs() async {
        let json = """
        {
            "schemaVersion": 1,
            "packs": [
                {
                    "id": "dup-pack",
                    "name": "First Duplicate",
                    "description": "First",
                    "icon": "1",
                    "version": "1.0.0",
                    "author": "A",
                    "terms": ["A"]
                },
                {
                    "id": "dup-pack",
                    "name": "Second Duplicate",
                    "description": "Second",
                    "icon": "2",
                    "version": "1.0.0",
                    "author": "B",
                    "terms": ["B"]
                }
            ]
        }
        """
        let service = makeService(json: json)
        let _ = await service.fetchRegistry()

        XCTAssertEqual(service.communityPacks.count, 1, "Duplicate IDs should be deduplicated")
        XCTAssertEqual(service.communityPacks[0].defaultName, "First Duplicate",
                       "First occurrence should be kept")
    }

    // MARK: - Empty Terms and Corrections Filtering

    func testFetchRegistry_skipsPacksWithNoTermsOrCorrections() async {
        let json = """
        {
            "schemaVersion": 1,
            "packs": [
                {
                    "id": "empty-pack",
                    "name": "Empty Pack",
                    "description": "No content",
                    "icon": "circle",
                    "version": "1.0.0",
                    "author": "Nobody",
                    "terms": [],
                    "corrections": []
                },
                {
                    "id": "terms-only-pack",
                    "name": "Terms Only",
                    "description": "Has terms",
                    "icon": "t",
                    "version": "1.0.0",
                    "author": "A",
                    "terms": ["Something"]
                },
                {
                    "id": "corrections-only-pack",
                    "name": "Corrections Only",
                    "description": "Has corrections",
                    "icon": "c",
                    "version": "1.0.0",
                    "author": "B",
                    "terms": [],
                    "corrections": [{"original": "typo", "replacement": "fixed", "caseSensitive": true}]
                }
            ]
        }
        """
        let service = makeService(json: json)
        let _ = await service.fetchRegistry()

        let ids = service.communityPacks.map(\.id)
        XCTAssertEqual(ids.count, 2, "Pack with no terms and no corrections should be filtered")
        XCTAssertFalse(ids.contains("empty-pack"), "Pack with empty content should be filtered")
        XCTAssertTrue(ids.contains("terms-only-pack"))
        XCTAssertTrue(ids.contains("corrections-only-pack"))
    }

    func testFetchRegistry_handlesNullTermsAndCorrections() async {
        let json = """
        {
            "schemaVersion": 1,
            "packs": [
                {
                    "id": "null-fields-pack",
                    "name": "Null Fields",
                    "description": "No arrays",
                    "icon": "questionmark",
                    "version": "1.0.0",
                    "author": "A"
                }
            ]
        }
        """
        let service = makeService(json: json)
        let _ = await service.fetchRegistry()

        // terms and corrections are both nil, which means both default to [] -> empty -> filtered
        XCTAssertEqual(service.communityPacks.count, 0,
                       "Pack with null terms and corrections should be filtered as empty")
    }

    // MARK: - compareVersions

    func testCompareVersions_equal() {
        XCTAssertEqual(TermPackRegistryService.compareVersions("1.0.0", "1.0.0"), .orderedSame)
    }

    func testCompareVersions_firstGreater() {
        XCTAssertEqual(TermPackRegistryService.compareVersions("2.0.0", "1.0.0"), .orderedDescending)
    }

    func testCompareVersions_firstLesser() {
        XCTAssertEqual(TermPackRegistryService.compareVersions("1.0.0", "2.0.0"), .orderedAscending)
    }

    func testCompareVersions_majorSame_minorGreater() {
        XCTAssertEqual(TermPackRegistryService.compareVersions("1.2.0", "1.1.0"), .orderedDescending)
    }

    func testCompareVersions_majorSame_minorLesser() {
        XCTAssertEqual(TermPackRegistryService.compareVersions("1.1.0", "1.2.0"), .orderedAscending)
    }

    func testCompareVersions_patchDifference() {
        XCTAssertEqual(TermPackRegistryService.compareVersions("1.0.2", "1.0.1"), .orderedDescending)
        XCTAssertEqual(TermPackRegistryService.compareVersions("1.0.1", "1.0.2"), .orderedAscending)
    }

    func testCompareVersions_differentLengths() {
        // "1.0" is equivalent to "1.0.0"
        XCTAssertEqual(TermPackRegistryService.compareVersions("1.0", "1.0.0"), .orderedSame)
    }

    func testCompareVersions_shorterIsPaddedWithZeros() {
        XCTAssertEqual(TermPackRegistryService.compareVersions("1.1", "1.0.1"), .orderedDescending)
        XCTAssertEqual(TermPackRegistryService.compareVersions("1.0", "1.0.1"), .orderedAscending)
    }

    func testCompareVersions_singleComponent() {
        XCTAssertEqual(TermPackRegistryService.compareVersions("3", "2"), .orderedDescending)
        XCTAssertEqual(TermPackRegistryService.compareVersions("2", "3"), .orderedAscending)
        XCTAssertEqual(TermPackRegistryService.compareVersions("5", "5"), .orderedSame)
    }

    func testCompareVersions_emptyStrings() {
        XCTAssertEqual(TermPackRegistryService.compareVersions("", ""), .orderedSame)
    }

    // MARK: - Background Update Check

    func testBackgroundCheckDoesNotRecordTimestampWhenFetchFails() async {
        let suiteName = "TermPackRegistryServiceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = TermPackRegistryService(
            userDefaults: defaults,
            fetchData: { _ in throw URLError(.notConnectedToInternet) }
        )

        service.checkForUpdatesInBackground()

        for _ in 0..<20 {
            if case .error = service.fetchState {
                break
            }
            await Task.yield()
        }

        XCTAssertEqual(defaults.double(forKey: UserDefaultsKeys.termPackRegistryLastUpdateCheck), 0)
    }

    func testBackgroundCheckRecordsTimestampWhenFetchSucceeds() async throws {
        let suiteName = "TermPackRegistryServiceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let payload = """
        {
          "schemaVersion": 1,
          "packs": [
            {
              "id": "community-rust",
              "name": "Rust Terms",
              "description": "Rust ecosystem terms",
              "icon": "shippingbox",
              "version": "1.0.0",
              "author": "Tests",
              "terms": ["Tokio"]
            }
          ]
        }
        """.data(using: .utf8)!

        let service = TermPackRegistryService(
            userDefaults: defaults,
            fetchData: { _ in
                let response = HTTPURLResponse(
                    url: URL(string: "https://example.com/termpacks.json")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (payload, response)
            }
        )

        service.checkForUpdatesInBackground()

        for _ in 0..<20 {
            if service.fetchState == .loaded {
                break
            }
            await Task.yield()
        }

        XCTAssertGreaterThan(defaults.double(forKey: UserDefaultsKeys.termPackRegistryLastUpdateCheck), 0)
        XCTAssertEqual(service.communityPacks.map(\.id), ["community-rust"])
    }

    // MARK: - Cache Behavior

    func testFetchRegistry_cachedResult_returnsEarlyWithoutRefetch() async {
        // Use a service with long cache duration
        let json = """
        {
            "schemaVersion": 1,
            "packs": [
                {
                    "id": "cached-pack",
                    "name": "Cached",
                    "description": "Cached pack",
                    "icon": "c",
                    "version": "1.0.0",
                    "author": "A",
                    "terms": ["CachedTerm"]
                }
            ]
        }
        """
        let responseData = Data(json.utf8)
        let url = self.testURL!
        final class FetchCounter: @unchecked Sendable { var count = 0 }
        let counter = FetchCounter()
        let mockFetch: @Sendable (URLRequest) async throws -> (Data, URLResponse) = { _ in
            counter.count += 1
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [:]
            )!
            return (responseData, response)
        }
        let defaults = UserDefaults(suiteName: "CacheTest-\(UUID().uuidString)")!
        let service = TermPackRegistryService(
            registryURL: url,
            cacheDuration: 9999,
            userDefaults: defaults,
            fetchData: mockFetch
        )

        // First fetch should call the network
        let first = await service.fetchRegistry()
        XCTAssertTrue(first)
        XCTAssertEqual(counter.count, 1)

        // Second fetch (non-forced) should use cache and NOT call network
        let second = await service.fetchRegistry()
        XCTAssertTrue(second)
        XCTAssertEqual(counter.count, 1, "Second fetch should not call network when cache is valid")

        // Force refresh should call the network again
        let third = await service.fetchRegistry(force: true)
        XCTAssertTrue(third)
        XCTAssertEqual(counter.count, 2, "Force refresh should call network again")
    }

    func testFetchRegistry_forceRefresh_ignoresCache() async {
        let json = """
        {
            "schemaVersion": 1,
            "packs": [
                {
                    "id": "refreshed-pack",
                    "name": "Refreshed",
                    "description": "After refresh",
                    "icon": "r",
                    "version": "2.0.0",
                    "author": "A",
                    "terms": ["New"]
                }
            ]
        }
        """
        let service = makeService(json: json)
        let _ = await service.fetchRegistry()

        // Force refresh should re-fetch even with cache
        let result = await service.fetchRegistry(force: true)
        XCTAssertTrue(result)
        XCTAssertEqual(service.communityPacks.count, 1)
        XCTAssertEqual(service.communityPacks[0].version, "2.0.0")
    }

    // MARK: - Corrections-Only Pack

    func testFetchRegistry_packWithOnlyCorrectionsIncluded() async {
        let json = """
        {
            "schemaVersion": 1,
            "packs": [
                {
                    "id": "corrections-pack",
                    "name": "Corrections Only",
                    "description": "Only corrections, no terms",
                    "icon": "wrench",
                    "version": "1.0.0",
                    "author": "Fixer",
                    "terms": [],
                    "corrections": [
                        {"original": "recieve", "replacement": "receive", "caseSensitive": false},
                        {"original": "teh", "replacement": "the", "caseSensitive": false}
                    ]
                }
            ]
        }
        """
        let service = makeService(json: json)
        let _ = await service.fetchRegistry()

        XCTAssertEqual(service.communityPacks.count, 1)
        XCTAssertEqual(service.communityPacks[0].corrections.count, 2)
        XCTAssertEqual(service.communityPacks[0].terms.count, 0)
    }
}
