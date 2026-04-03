import Foundation
import AVFoundation
@testable import DavyWhisper

/// Mock AudioDeviceService for unit testing.
/// Not @MainActor — protocol AudioDeviceProtocol is nonisolated.
final class MockAudioDeviceService: AudioDeviceProtocol {

    // MARK: - State

    var inputDevices: [AudioInputDevice] = []
    var selectedDeviceUID: String? = nil {
        didSet { selectedDeviceUIDDidSetCount += 1 }
    }
    var isPreviewActive: Bool = false
    var previewAudioLevel: Float = 0.0

    // MARK: - Call counting

    var startPreviewCallCount = 0
    var stopPreviewCallCount = 0
    var selectedDeviceUIDDidSetCount = 0

    // MARK: - Stubs

    var startPreviewStub: (() -> Void)?
    var stopPreviewStub: (() -> Void)?

    // MARK: - Protocol methods

    func startPreview() {
        startPreviewCallCount += 1
        isPreviewActive = true
        startPreviewStub?()
    }

    func stopPreview() {
        stopPreviewCallCount += 1
        isPreviewActive = false
        previewAudioLevel = 0.0
        stopPreviewStub?()
    }

    // MARK: - Convenience helpers

    func simulateDeviceChange(devices: [AudioInputDevice]) {
        inputDevices = devices
    }

    func simulateDeviceConnected(deviceID: AudioDeviceID, name: String, uid: String) {
        inputDevices.append(AudioInputDevice(deviceID: deviceID, name: name, uid: uid))
    }

    func simulateDeviceDisconnected(uid: String) {
        inputDevices.removeAll { $0.uid == uid }
        if selectedDeviceUID == uid {
            selectedDeviceUID = nil
        }
    }

    func simulatePreviewActive(level: Float) {
        isPreviewActive = true
        previewAudioLevel = level
    }

    func reset() {
        inputDevices = []
        selectedDeviceUID = nil
        isPreviewActive = false
        previewAudioLevel = 0.0
        startPreviewCallCount = 0
        stopPreviewCallCount = 0
        selectedDeviceUIDDidSetCount = 0
        startPreviewStub = nil
        stopPreviewStub = nil
    }
}
