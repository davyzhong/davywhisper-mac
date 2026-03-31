import XCTest
@testable import DavyWhisper

actor StateList {
    private(set) var items: [Bool] = []
    func append(_ item: Bool) { items.append(item) }
    func clear() { items.removeAll() }
}

final class HTTPServerTests: XCTestCase {
    var router: APIRouter!
    var server: HTTPServer!
    let testPort: UInt16 = 9878

    override func setUp() {
        super.setUp()
        router = APIRouter()
        router.register("GET", "/v1/status") { _ in
            HTTPResponse(
                status: 200,
                contentType: "application/json",
                body: "{\"status\":\"ok\"}".data(using: .utf8) ?? Data()
            )
        }
        server = HTTPServer(router: router)
    }

    override func tearDown() {
        server.stop()
        super.tearDown()
    }

    func testServerStartsAndReportsReadyState() async throws {
        let states = StateList()
        server.onStateChange = { isReady in
            Task { await states.append(isReady) }
        }
        try server.start(port: testPort)
        try? await Task.sleep(nanoseconds: 500_000_000)
        let last = await states.items.last ?? false
        XCTAssertTrue(last, "Server should report ready=true")
        server.stop()
    }

    func testServerStopSetsStateToFalse() async throws {
        let states = StateList()
        server.onStateChange = { isReady in
            Task { await states.append(isReady) }
        }
        try server.start(port: testPort)
        try? await Task.sleep(nanoseconds: 200_000_000)
        server.stop()
        try? await Task.sleep(nanoseconds: 200_000_000)
        let last = await states.items.last ?? true
        XCTAssertFalse(last, "Server should report ready=false after stop")
    }

    func testDoubleStartDoesNotCrash() async throws {
        try server.start(port: testPort)
        try? await Task.sleep(nanoseconds: 200_000_000)
        try server.start(port: testPort)  // calls stop() internally
        server.stop()
    }

    func testServerHandlesRequest() async throws {
        try server.start(port: testPort)
        try? await Task.sleep(nanoseconds: 300_000_000)

        let url = URL(string: "http://127.0.0.1:\(testPort)/v1/status")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, URLResponse), Error>) in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (data ?? Data(), response ?? URLResponse()))
                }
            }.resume()
        }
        let httpResponse = response as! HTTPURLResponse
        XCTAssertEqual(httpResponse.statusCode, 200)
        XCTAssertFalse(data.isEmpty)
        server.stop()
    }
}
