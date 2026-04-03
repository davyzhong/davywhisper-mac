import Foundation
import AppKit

/// Abstracts sound playback for testability.
/// The production implementation is SoundService.
@MainActor
protocol SoundProtocol: AnyObject {
    func play(_ event: SoundEvent, enabled: Bool)
    func choice(for event: SoundEvent) -> SoundChoice
    func updateChoice(for event: SoundEvent, choice: SoundChoice)
}
