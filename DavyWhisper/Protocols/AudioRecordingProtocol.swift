import Foundation
import AVFoundation
import os

/// Abstracts microphone audio capture for testability.
/// The production implementation is AudioRecordingService.
@MainActor
protocol AudioRecordingProtocol: AnyObject {
    var isRecording: Bool { get }
    var audioLevel: Float { get }
    var hasMicrophonePermission: Bool { get }

    func requestMicrophonePermission() async -> Bool
    func startRecording() throws
    func stopRecording(policy: AudioRecordingService.StopPolicy) async -> [Float]
    func getCurrentBuffer() -> [Float]
    func getRecentBuffer(maxDuration: TimeInterval) -> [Float]
    var selectedDeviceID: AudioDeviceID? { get set }
}
