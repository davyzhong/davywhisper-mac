import Foundation
import XCTest
@testable import DavyWhisper
import DavyWhisperPluginSDK

/// HTTP API round-trip integration tests.
/// Uses TestServiceContainer for isolated service instances.
@MainActor
final class HTTPAPIRoundTripTests: XCTestCase {

    var container: TestServiceContainer!
    private var router: APIRouter!

    override func setUp() {
        super.setUp()
        container = try! TestServiceContainer()
        // Use the HTTP server's router directly for testing (no network needed)
        router = APIRouter()
        let handlers = APIHandlers(
            modelManager: container.modelManagerService,
            audioFileService: container.audioFileService,
            translationService: nil,
            historyService: container.historyService,
            profileService: container.profileService,
            dictationViewModel: container.dictationViewModel
        )
        handlers.register(on: router)
    }

    override func tearDown() {
        container.tearDown()
        container = nil
        router = nil
        super.tearDown()
    }

    // MARK: - Helper

    private func makeRequest(method: String, path: String, queryParams: [String: String] = [:], body: Data = Data()) -> HTTPRequest {
        HTTPRequest(method: method, path: path, queryParams: queryParams, headers: [:], body: body)
    }

    private func parseJSONResponse(_ response: HTTPResponse) throws -> [String: Any] {
        let json = try JSONSerialization.jsonObject(with: response.body)
        return try XCTUnwrap(json as? [String: Any])
    }

    // MARK: - Status Endpoint

    func testStatusEndpoint_returns200() async {
        let response = await router.route(makeRequest(method: "GET", path: "/v1/status"))
        XCTAssertEqual(response.status, 200)
        XCTAssertTrue(response.contentType.contains("application/json"))
    }

    func testStatusEndpoint_returnsModelStatus() async throws {
        let response = await router.route(makeRequest(method: "GET", path: "/v1/status"))
        let json = try parseJSONResponse(response)
        // No model loaded in test environment — status should be no_model or similar
        let status = json["status"] as? String
        XCTAssertFalse(status?.isEmpty ?? true)
    }

    // MARK: - History CRUD

    func testHistoryGET_returnsEntries() async throws {
        container.historyService.addRecord(
            rawText: "hello world",
            finalText: "Hello World",
            appName: "TestApp",
            appBundleIdentifier: "com.test.app",
            durationSeconds: 1.5,
            language: "en",
            engineUsed: "WhisperKit"
        )

        let response = await router.route(makeRequest(method: "GET", path: "/v1/history"))
        XCTAssertEqual(response.status, 200)

        let json = try parseJSONResponse(response)
        let entries = json["entries"] as? [[String: Any]]
        XCTAssertEqual(entries?.count, 1)
        XCTAssertEqual(entries?.first?["raw_text"] as? String, "hello world")
        XCTAssertEqual(entries?.first?["text"] as? String, "Hello World")
    }

    func testHistoryGET_returnsEmptyWhenNoRecords() async throws {
        let response = await router.route(makeRequest(method: "GET", path: "/v1/history"))
        XCTAssertEqual(response.status, 200)

        let json = try parseJSONResponse(response)
        let entries = json["entries"] as? [[String: Any]]
        XCTAssertEqual(entries?.count, 0)
    }

    func testHistoryGET_returnsMultipleEntries() async throws {
        container.historyService.addRecord(
            rawText: "r1",
            finalText: "R1",
            appName: nil,
            appBundleIdentifier: nil,
            durationSeconds: 1.0,
            language: nil,
            engineUsed: "X"
        )
        container.historyService.addRecord(
            rawText: "r2",
            finalText: "R2",
            appName: nil,
            appBundleIdentifier: nil,
            durationSeconds: 2.0,
            language: nil,
            engineUsed: "Y"
        )

        let response = await router.route(makeRequest(method: "GET", path: "/v1/history"))
        let json = try parseJSONResponse(response)
        let entries = json["entries"] as? [[String: Any]]
        XCTAssertEqual(entries?.count, 2)
    }

    // MARK: - History DELETE

    func testHistoryDELETE_requiresId_returns405Or404() async {
        // DELETE without id should not succeed
        let response = await router.route(makeRequest(method: "DELETE", path: "/v1/history"))
        XCTAssertTrue(response.status == 400 || response.status == 404 || response.status == 405)
    }

    // MARK: - Profiles Endpoint

    func testProfilesGET_returnsJSON() async {
        let response = await router.route(makeRequest(method: "GET", path: "/v1/profiles"))
        XCTAssertEqual(response.status, 200)
        XCTAssertTrue(response.contentType.contains("application/json"))
    }

    func testProfilesGET_emptyWhenNoProfiles() async throws {
        let response = await router.route(makeRequest(method: "GET", path: "/v1/profiles"))
        let json = try parseJSONResponse(response)
        let profiles = json["profiles"] as? [[String: Any]]
        XCTAssertEqual(profiles?.count, 0)
    }

    // MARK: - CORS / OPTIONS

    func testOPTIONS_returns200() async {
        let response = await router.route(makeRequest(method: "OPTIONS", path: "/v1/status"))
        XCTAssertEqual(response.status, 200)
    }

    // MARK: - 404 for Unknown Paths

    func testUnknownPath_returns404() async {
        let response = await router.route(makeRequest(method: "GET", path: "/v1/nonexistent"))
        XCTAssertEqual(response.status, 404)
    }

    func testWrongMethod_returns404Or405() async {
        // POST to a GET-only endpoint
        let response = await router.route(makeRequest(method: "POST", path: "/v1/status"))
        XCTAssertTrue(response.status == 404 || response.status == 405)
    }
}
