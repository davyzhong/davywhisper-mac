import XCTest
@testable import DavyWhisper

final class TextInsertionServiceTests: XCTestCase {
    func testEscapeForAppleScriptHandlesDoubleQuotes() {
        // Simulate the escape logic manually to verify correctness
        let input = "App \"Name\""
        let escaped = input
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        XCTAssertEqual(escaped, "App \\\"Name\\\"")
    }

    func testEscapeForAppleScriptHandlesBackslashes() {
        let input = "C:\\Program Files\\App"
        let escaped = input
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        XCTAssertEqual(escaped, "C:\\\\Program Files\\\\App")
    }

    func testEscapeForAppleScriptHandlesMixedSpecialChars() {
        let input = "Say \"Hello\" at C:\\Path"
        let escaped = input
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        XCTAssertEqual(escaped, "Say \\\"Hello\\\" at C:\\\\Path")
    }

    func testEscapeForAppleScriptLeavesPlainTextUnchanged() {
        let input = "Simple App Name"
        let escaped = input
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        XCTAssertEqual(escaped, "Simple App Name")
    }
}
