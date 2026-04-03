import Foundation
import AVFoundation
import Combine

/// Abstracts audio device enumeration and preview for testability.
/// The production implementation is AudioDeviceService.
protocol AudioDeviceProtocol: AnyObject {
    var inputDevices: [AudioInputDevice] { get }
    var selectedDeviceUID: String? { get set }
    var isPreviewActive: Bool { get }
    var previewAudioLevel: Float { get }
    func startPreview()
    func stopPreview()
}
