import Foundation
import AppKit
@testable import DavyWhisper

/// Mock SoundService for unit testing.
@MainActor
final class MockSoundService: SoundProtocol {

    // MARK: - State

    private var _choices: [SoundEvent: SoundChoice] = [:]

    // MARK: - Call counting

    var playCallCount = 0
    var choiceCallCount = 0
    var updateChoiceCallCount = 0

    // MARK: - Recorded calls

    private(set) var playedEvents: [(event: SoundEvent, enabled: Bool)] = []
    private(set) var choiceEventArgs: [SoundEvent] = []
    private(set) var updatedChoices: [(event: SoundEvent, choice: SoundChoice)] = []

    // MARK: - Stubs

    var playStub: ((SoundEvent, Bool) -> Void)?

    // MARK: - Protocol methods

    func play(_ event: SoundEvent, enabled: Bool) {
        playCallCount += 1
        playedEvents.append((event, enabled))
        playStub?(event, enabled)
    }

    func choice(for event: SoundEvent) -> SoundChoice {
        choiceCallCount += 1
        choiceEventArgs.append(event)
        return _choices[event] ?? event.defaultChoice
    }

    func updateChoice(for event: SoundEvent, choice: SoundChoice) {
        updateChoiceCallCount += 1
        _choices[event] = choice
        updatedChoices.append((event, choice))
    }

    func resetChoice(for event: SoundEvent) {
        _choices.removeValue(forKey: event)
    }

    // MARK: - Convenience helpers

    func reset() {
        _choices = [:]
        playCallCount = 0
        choiceCallCount = 0
        updateChoiceCallCount = 0
        playedEvents = []
        choiceEventArgs = []
        updatedChoices = []
        playStub = nil
    }
}
