import Foundation

/// Protocol for HTTP server dependency — enables mock injection in tests.
protocol HTTPServerProtocol: AnyObject {
    var onStateChange: ((Bool) -> Void)? { get set }
    func start(port: UInt16) throws
    func stop()
}
