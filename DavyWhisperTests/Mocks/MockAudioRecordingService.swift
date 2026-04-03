import Foundation
import CoreAudio
@testable import DavyWhisper

/// Mock AudioRecordingService for unit testing.
/// All state starts as safe defaults; override properties or set stubs to control behavior.
@MainActor
final class MockAudioRecordingService: AudioRecordingProtocol {

    // MARK: - State

    var isRecording: Bool = false
    var audioLevel: Float = 0.0
    var hasMicrophonePermission: Bool = true
    var selectedDeviceID: AudioDeviceID? = nil

    // MARK: - Call counting

    var requestMicrophonePermissionCallCount = 0
    var startRecordingCallCount = 0
    var stopRecordingCallCount = 0
    var getCurrentBufferCallCount = 0
    var getRecentBufferCallCount = 0

    // MARK: - Recorded calls

    private(set) var recordedStopPolicies: [AudioRecordingService.StopPolicy] = []

    // MARK: - Stubs

    var requestMicrophonePermissionStub: (() -> Bool)?
    var startRecordingStub: (() throws -> Void)?
    var stopRecordingStub: (() -> [Float])?
    var getCurrentBufferStub: (() -> [Float])?
    var getRecentBufferStub: (() -> [Float])?

    // MARK: - Protocol methods

    func requestMicrophonePermission() async -> Bool {
        requestMicrophonePermissionCallCount += 1
        return requestMicrophonePermissionStub?() ?? hasMicrophonePermission
    }

    func startRecording() throws {
        startRecordingCallCount += 1
        isRecording = true
        audioLevel = 0.5
        try startRecordingStub?()
    }

    func stopRecording(policy: AudioRecordingService.StopPolicy) async -> [Float] {
        stopRecordingCallCount += 1
        recordedStopPolicies.append(policy)
        isRecording = false
        audioLevel = 0.0
        return stopRecordingStub?() ?? []
    }

    func getCurrentBuffer() -> [Float] {
        getCurrentBufferCallCount += 1
        return getCurrentBufferStub?() ?? []
    }

    func getRecentBuffer(maxDuration: TimeInterval) -> [Float] {
        getRecentBufferCallCount += 1
        return getRecentBufferStub?() ?? []
    }

    // MARK: - Convenience helpers

    func simulateRecordingStarted() {
        isRecording = true
        audioLevel = 0.75
    }

    func simulateRecordingStopped(samples: [Float] = Array(repeating: 0.1, count: 16000)) {
        isRecording = false
        audioLevel = 0.0
        stopRecordingStub?() == samples  // silence warning
    }

    func reset() {
        isRecording = false
        audioLevel = 0.0
        hasMicrophonePermission = true
        selectedDeviceID = nil
        requestMicrophonePermissionCallCount = 0
        startRecordingCallCount = 0
        stopRecordingCallCount = 0
        getCurrentBufferCallCount = 0
        getRecentBufferCallCount = 0
        recordedStopPolicies = []
        requestMicrophonePermissionStub = nil
        startRecordingStub = nil
        stopRecordingStub = nil
        getCurrentBufferStub = nil
        getRecentBufferStub = nil
    }
}
