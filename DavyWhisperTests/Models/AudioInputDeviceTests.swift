import XCTest
@testable import DavyWhisper

final class AudioInputDeviceTests: XCTestCase {

    // MARK: - Equatable

    func testEquatable_sameValues_true() {
        let a = AudioInputDevice(deviceID: 1, name: "Mic", uid: "uid-abc")
        let b = AudioInputDevice(deviceID: 1, name: "Mic", uid: "uid-abc")
        XCTAssertEqual(a, b)
    }

    func testEquatable_differentDeviceID_false() {
        let a = AudioInputDevice(deviceID: 1, name: "Mic", uid: "uid-abc")
        let b = AudioInputDevice(deviceID: 2, name: "Mic", uid: "uid-abc")
        XCTAssertNotEqual(a, b)
    }

    func testEquatable_differentName_false() {
        let a = AudioInputDevice(deviceID: 1, name: "Mic A", uid: "uid-abc")
        let b = AudioInputDevice(deviceID: 1, name: "Mic B", uid: "uid-abc")
        XCTAssertNotEqual(a, b)
    }

    func testEquatable_differentUID_false() {
        let a = AudioInputDevice(deviceID: 1, name: "Mic", uid: "uid-abc")
        let b = AudioInputDevice(deviceID: 1, name: "Mic", uid: "uid-xyz")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - id

    func testId_returnsUID() {
        let device = AudioInputDevice(deviceID: 42, name: "Built-in Mic", uid: "com.apple.mic.builtin")
        XCTAssertEqual(device.id, "com.apple.mic.builtin")
    }
}
