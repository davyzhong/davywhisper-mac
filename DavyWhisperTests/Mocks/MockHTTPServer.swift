import Foundation
@testable import DavyWhisper

/// Mock HTTP server that throws on start() — used to test APIServerViewModel error handling.
final class MockHTTPServer: HTTPServerProtocol, @unchecked Sendable {
    var onStateChange: ((Bool) -> Void)?
    private(set) var startCallCount = 0
    var startShouldThrow = true
    var thrownError = NSError(domain: "MockHTTPServer", code: -99, userInfo: [NSLocalizedDescriptionKey: "Mock server failure"])

    init(router: APIRouter) {}

    func start(port: UInt16) throws {
        startCallCount += 1
        if startShouldThrow {
            throw thrownError
        }
    }

    func stop() {}
}
