import XCTest
@testable import DavyWhisper

/// Tests the audio ducking logic in AudioRecorderService:
/// - TranscriptionBufferState.mix: element-wise mixing with zero-padding and ducking
/// - buildMicDuckingProfile: envelope-based gain computation per MicDuckingMode
/// - smoothingCoefficient: exponential smoothing math
/// - MicDuckingMode enum and MicDuckingParameters configuration
final class AudioRecorderDuckingTests: XCTestCase {

    // MARK: - TranscriptionBufferState.mix — equal-length arrays

    @MainActor
    func testMixEqualLengthArraysPerformsElementWiseMix() {
        let mic: [Float] = [0.5, 0.5, 0.5, 0.5]
        let system: [Float] = [0.3, 0.3, 0.3, 0.3]

        let result = AudioRecorderService.TranscriptionBufferState.mix(
            micSamples: mic,
            systemSamples: system,
            micDuckingMode: .off
        )

        XCTAssertEqual(result.count, 4)
        // With .off mode, duckingProfile is nil, so micGain = 1.
        // Formula: max(-1, min(1, (systemSample + micSample * 1) * 0.5))
        for sample in result {
            let expected: Float = (0.3 + 0.5 * 1.0) * 0.5
            XCTAssertEqual(sample, expected, accuracy: 0.0001)
        }
    }

    // MARK: - TranscriptionBufferState.mix — mic longer than system

    @MainActor
    func testMixMicLongerThanSystemPadsSystemWithZeros() {
        let mic: [Float] = [0.8, 0.8, 0.8]
        let system: [Float] = [0.4]

        let result = AudioRecorderService.TranscriptionBufferState.mix(
            micSamples: mic,
            systemSamples: system,
            micDuckingMode: .off
        )

        XCTAssertEqual(result.count, 3)

        // Index 0: (0.4 + 0.8 * 1.0) * 0.5 = 0.6
        XCTAssertEqual(result[0], 0.6, accuracy: 0.0001)
        // Index 1: system padded to 0 → (0.0 + 0.8 * 1.0) * 0.5 = 0.4
        XCTAssertEqual(result[1], 0.4, accuracy: 0.0001)
        // Index 2: same as index 1
        XCTAssertEqual(result[2], 0.4, accuracy: 0.0001)
    }

    // MARK: - TranscriptionBufferState.mix — system longer than mic

    @MainActor
    func testMixSystemLongerThanMicPadsMicWithZeros() {
        let mic: [Float] = [0.6]
        let system: [Float] = [0.3, 0.3, 0.3]

        let result = AudioRecorderService.TranscriptionBufferState.mix(
            micSamples: mic,
            systemSamples: system,
            micDuckingMode: .off
        )

        XCTAssertEqual(result.count, 3)

        // Index 0: (0.3 + 0.6 * 1.0) * 0.5 = 0.45
        XCTAssertEqual(result[0], 0.45, accuracy: 0.0001)
        // Index 1: mic padded to 0 → (0.3 + 0.0) * 0.5 = 0.15
        XCTAssertEqual(result[1], 0.15, accuracy: 0.0001)
        // Index 2: same
        XCTAssertEqual(result[2], 0.15, accuracy: 0.0001)
    }

    // MARK: - TranscriptionBufferState.mix — empty arrays

    @MainActor
    func testMixBothEmptyReturnsEmptyArray() {
        let result = AudioRecorderService.TranscriptionBufferState.mix(
            micSamples: [],
            systemSamples: [],
            micDuckingMode: .aggressive
        )

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - TranscriptionBufferState.mix — both arrays same length, explicit

    @MainActor
    func testMixIdenticalLengthsProducesCorrectAverages() {
        let mic: [Float] = [1.0, 0.5, 0.0, -0.5]
        let system: [Float] = [0.0, 0.5, 1.0, -0.5]

        let result = AudioRecorderService.TranscriptionBufferState.mix(
            micSamples: mic,
            systemSamples: system,
            micDuckingMode: .off
        )

        XCTAssertEqual(result.count, 4)
        // (system[i] + mic[i] * 1.0) * 0.5
        XCTAssertEqual(result[0], (0.0 + 1.0) * 0.5, accuracy: 0.0001)
        XCTAssertEqual(result[1], (0.5 + 0.5) * 0.5, accuracy: 0.0001)
        XCTAssertEqual(result[2], (1.0 + 0.0) * 0.5, accuracy: 0.0001)
        XCTAssertEqual(result[3], (-0.5 + (-0.5)) * 0.5, accuracy: 0.0001)
    }

    // MARK: - TranscriptionBufferState.mix — output clamped to [-1, 1]

    @MainActor
    func testMixClampsOutputToUnitRange() {
        // Both at max amplitude → (1.0 + 1.0 * 1.0) * 0.5 = 1.0 (boundary)
        let mic: [Float] = [1.0]
        let system: [Float] = [1.0]

        let result = AudioRecorderService.TranscriptionBufferState.mix(
            micSamples: mic,
            systemSamples: system,
            micDuckingMode: .off
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], 1.0, accuracy: 0.0001)

        // Now test negative clamping
        let micNeg: [Float] = [-1.0]
        let sysNeg: [Float] = [-1.0]

        let negResult = AudioRecorderService.TranscriptionBufferState.mix(
            micSamples: micNeg,
            systemSamples: sysNeg,
            micDuckingMode: .off
        )

        XCTAssertEqual(negResult[0], -1.0, accuracy: 0.0001)
    }

    // MARK: - buildMicDuckingProfile — mode .off returns nil

    @MainActor
    func testDuckingProfileModeOffReturnsNil() {
        let profile = AudioRecorderService.buildMicDuckingProfile(
            frameCount: 100,
            sampleRate: 16000,
            mode: .off
        ) { _ in 0.5 }

        XCTAssertNil(profile)
    }

    // MARK: - buildMicDuckingProfile — mode .aggressive with positive system

    @MainActor
    func testDuckingProfileAggressiveWithPositiveSystemReturnsProfile() {
        let frameCount = 1600 // 0.1 seconds at 16kHz
        let systemSamples = [Float](repeating: 0.1, count: frameCount)

        let profile = AudioRecorderService.buildMicDuckingProfile(
            frameCount: frameCount,
            sampleRate: 16000,
            mode: .aggressive
        ) { index in
            index < systemSamples.count ? systemSamples[index] : 0
        }

        XCTAssertNotNil(profile)
        XCTAssertEqual(profile!.gains.count, frameCount)
        // Gains should be < 1 since system audio is strong
        XCTAssertLessThan(profile!.averageGain, 1.0)
    }

    // MARK: - buildMicDuckingProfile — mode .medium with mixed system

    @MainActor
    func testDuckingProfileMediumWithMixedSystemReturnsProfile() {
        let frameCount = 1600
        // First half loud, second half silent
        var systemSamples = [Float](repeating: 0.1, count: frameCount / 2)
        systemSamples.append(contentsOf: [Float](repeating: 0.0, count: frameCount / 2))

        let profile = AudioRecorderService.buildMicDuckingProfile(
            frameCount: frameCount,
            sampleRate: 16000,
            mode: .medium
        ) { index in
            index < systemSamples.count ? systemSamples[index] : 0
        }

        XCTAssertNotNil(profile)
        XCTAssertEqual(profile!.gains.count, frameCount)
    }

    // MARK: - buildMicDuckingProfile — different frame counts produce correct length

    @MainActor
    func testDuckingProfileDifferentFrameCounts() {
        for frameCount in [1, 100, 1600, 16000] {
            let systemSamples = [Float](repeating: 0.05, count: frameCount)

            let profile = AudioRecorderService.buildMicDuckingProfile(
                frameCount: frameCount,
                sampleRate: 16000,
                mode: .aggressive
            ) { index in
                index < systemSamples.count ? systemSamples[index] : 0
            }

            if let profile {
                XCTAssertEqual(profile.gains.count, frameCount, "Profile gains length mismatch for frameCount=\(frameCount)")
            }
        }
    }

    // MARK: - buildMicDuckingProfile — gains clamped between minimum and 1

    @MainActor
    func testDuckingProfileGainsClampedBetweenMinAndOne() {
        let frameCount = 16000 // 1 second
        // Very loud system audio to push ducking hard
        let systemSamples = [Float](repeating: 0.5, count: frameCount)

        let profile = AudioRecorderService.buildMicDuckingProfile(
            frameCount: frameCount,
            sampleRate: 16000,
            mode: .aggressive
        ) { index in
            index < systemSamples.count ? systemSamples[index] : 0
        }

        guard let profile else {
            XCTFail("Expected non-nil profile for aggressive mode with loud system audio")
            return
        }

        let aggressiveParams = AudioRecorderService.micDuckingParameters(for: .aggressive)!
        for (i, gain) in profile.gains.enumerated() {
            XCTAssertGreaterThanOrEqual(gain, aggressiveParams.minimumMicGain - 0.01,
                "Gain at index \(i) is \(gain), below minimum \(aggressiveParams.minimumMicGain)")
            XCTAssertLessThanOrEqual(gain, 1.0,
                "Gain at index \(i) is \(gain), above 1.0")
        }
    }

    // MARK: - buildMicDuckingProfile — zero frameCount returns nil

    @MainActor
    func testDuckingProfileZeroFrameCountReturnsNil() {
        let profile = AudioRecorderService.buildMicDuckingProfile(
            frameCount: 0,
            sampleRate: 16000,
            mode: .aggressive
        ) { _ in 0.5 }

        XCTAssertNil(profile)
    }

    // MARK: - buildMicDuckingProfile — silent system returns nil (no ducking needed)

    @MainActor
    func testDuckingProfileSilentSystemReturnsNil() {
        let frameCount = 1600
        let systemSamples = [Float](repeating: 0.0, count: frameCount)

        let profile = AudioRecorderService.buildMicDuckingProfile(
            frameCount: frameCount,
            sampleRate: 16000,
            mode: .aggressive
        ) { index in
            index < systemSamples.count ? systemSamples[index] : 0
        }

        // All-zero system audio: envelope stays at 0, ducking never engages,
        // so the guard `duckingEngaged == false` means nil is returned.
        XCTAssertNil(profile)
    }

    // MARK: - smoothingCoefficient — computation

    @MainActor
    func testSmoothingCoefficientKnownValues() {
        // exp(-1 / (timeConstant * sampleRate))
        // With timeConstant=1.0, sampleRate=1.0 → exp(-1) ≈ 0.3679
        let result = AudioRecorderService.smoothingCoefficient(timeConstant: 1.0, sampleRate: 1.0)
        XCTAssertEqual(result, Float(exp(-1.0)), accuracy: 0.0001)

        // Very large timeConstant → coefficient approaches 1 (slow smoothing)
        let slowSmooth = AudioRecorderService.smoothingCoefficient(timeConstant: 1000.0, sampleRate: 16000.0)
        XCTAssertGreaterThan(slowSmooth, 0.9999)

        // Very small timeConstant → coefficient approaches 0 (fast tracking)
        let fastTrack = AudioRecorderService.smoothingCoefficient(timeConstant: 0.00001, sampleRate: 16000.0)
        XCTAssertLessThan(fastTrack, 0.5)
    }

    @MainActor
    func testSmoothingCoefficientZeroInputsReturnZero() {
        XCTAssertEqual(AudioRecorderService.smoothingCoefficient(timeConstant: 0, sampleRate: 16000), 0)
        XCTAssertEqual(AudioRecorderService.smoothingCoefficient(timeConstant: 0.01, sampleRate: 0), 0)
        XCTAssertEqual(AudioRecorderService.smoothingCoefficient(timeConstant: 0, sampleRate: 0), 0)
    }

    // MARK: - MicDuckingMode enum

    @MainActor
    func testMicDuckingModeRawValues() {
        XCTAssertEqual(AudioRecorderService.MicDuckingMode.aggressive.rawValue, "aggressive")
        XCTAssertEqual(AudioRecorderService.MicDuckingMode.medium.rawValue, "medium")
        XCTAssertEqual(AudioRecorderService.MicDuckingMode.off.rawValue, "off")
    }

    @MainActor
    func testMicDuckingModeCaseIterable() {
        let allCases = AudioRecorderService.MicDuckingMode.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.aggressive))
        XCTAssertTrue(allCases.contains(.medium))
        XCTAssertTrue(allCases.contains(.off))
    }

    // MARK: - MicDuckingParameters — test mode configs

    @MainActor
    func testMicDuckingParametersAggressiveValues() {
        let params = AudioRecorderService.micDuckingParameters(for: .aggressive)
        XCTAssertNotNil(params)

        let p = params!
        XCTAssertEqual(p.minimumMicGain, 0.18, accuracy: 0.001)
        XCTAssertEqual(p.lowThreshold, 0.006, accuracy: 0.001)
        XCTAssertEqual(p.highThreshold, 0.025, accuracy: 0.001)
        XCTAssertEqual(p.holdTime, 0.12, accuracy: 0.01)
        XCTAssertEqual(p.envelopeAttackTime, 0.008, accuracy: 0.001)
        XCTAssertEqual(p.envelopeReleaseTime, 0.06, accuracy: 0.01)
        XCTAssertEqual(p.gainAttackTime, 0.02, accuracy: 0.01)
        XCTAssertEqual(p.gainReleaseTime, 0.28, accuracy: 0.01)
    }

    @MainActor
    func testMicDuckingParametersMediumValues() {
        let params = AudioRecorderService.micDuckingParameters(for: .medium)
        XCTAssertNotNil(params)

        let p = params!
        XCTAssertEqual(p.minimumMicGain, 0.42, accuracy: 0.001)
        XCTAssertEqual(p.lowThreshold, 0.01, accuracy: 0.001)
        XCTAssertEqual(p.highThreshold, 0.04, accuracy: 0.001)
        XCTAssertEqual(p.holdTime, 0.08, accuracy: 0.01)
        XCTAssertEqual(p.envelopeAttackTime, 0.012, accuracy: 0.001)
        XCTAssertEqual(p.envelopeReleaseTime, 0.08, accuracy: 0.01)
        XCTAssertEqual(p.gainAttackTime, 0.035, accuracy: 0.01)
        XCTAssertEqual(p.gainReleaseTime, 0.2, accuracy: 0.01)
    }

    @MainActor
    func testMicDuckingParametersOffReturnsNil() {
        let params = AudioRecorderService.micDuckingParameters(for: .off)
        XCTAssertNil(params)
    }

    @MainActor
    func testAggressiveMinimumGainLowerThanMedium() {
        let aggressive = AudioRecorderService.micDuckingParameters(for: .aggressive)!
        let medium = AudioRecorderService.micDuckingParameters(for: .medium)!

        // Aggressive mode should duck mic more aggressively (lower minimum gain)
        XCTAssertLessThan(aggressive.minimumMicGain, medium.minimumMicGain)
    }

    @MainActor
    func testAggressiveThresholdsMoreSensitiveThanMedium() {
        let aggressive = AudioRecorderService.micDuckingParameters(for: .aggressive)!
        let medium = AudioRecorderService.micDuckingParameters(for: .medium)!

        // Aggressive triggers ducking at lower system audio levels
        XCTAssertLessThan(aggressive.lowThreshold, medium.lowThreshold)
        XCTAssertLessThan(aggressive.highThreshold, medium.highThreshold)
    }

    // MARK: - TranscriptionBufferState.mixedBuffer routing

    @MainActor
    func testMixedBufferMicOnlyReturnsMicSamples() {
        var state = AudioRecorderService.TranscriptionBufferState()
        state.micSamples = [0.1, 0.2, 0.3]
        state.systemSamples = [0.4, 0.5, 0.6]

        let result = state.mixedBuffer(
            micEnabled: true,
            systemAudioEnabled: false,
            micDuckingMode: .off
        )

        XCTAssertEqual(result, [0.1, 0.2, 0.3])
    }

    @MainActor
    func testMixedBufferSystemOnlyReturnsSystemSamples() {
        var state = AudioRecorderService.TranscriptionBufferState()
        state.micSamples = [0.1, 0.2, 0.3]
        state.systemSamples = [0.4, 0.5, 0.6]

        let result = state.mixedBuffer(
            micEnabled: false,
            systemAudioEnabled: true,
            micDuckingMode: .off
        )

        XCTAssertEqual(result, [0.4, 0.5, 0.6])
    }

    @MainActor
    func testMixedBufferNeitherEnabledReturnsEmpty() {
        var state = AudioRecorderService.TranscriptionBufferState()
        state.micSamples = [0.1, 0.2, 0.3]
        state.systemSamples = [0.4, 0.5, 0.6]

        let result = state.mixedBuffer(
            micEnabled: false,
            systemAudioEnabled: false,
            micDuckingMode: .off
        )

        XCTAssertTrue(result.isEmpty)
    }

    @MainActor
    func testMixedBufferBothEnabledCallsMix() {
        var state = AudioRecorderService.TranscriptionBufferState()
        state.micSamples = [0.5, 0.5]
        state.systemSamples = [0.3, 0.3]

        let result = state.mixedBuffer(
            micEnabled: true,
            systemAudioEnabled: true,
            micDuckingMode: .off
        )

        XCTAssertEqual(result.count, 2)
        // Should match the mix output (with .off, duckingProfile is nil, micGain = 1)
        let expected: Float = (0.3 + 0.5) * 0.5
        XCTAssertEqual(result[0], expected, accuracy: 0.0001)
        XCTAssertEqual(result[1], expected, accuracy: 0.0001)
    }

    // MARK: - TranscriptionBufferState.reset

    @MainActor
    func testTranscriptionBufferResetClearsSamples() {
        var state = AudioRecorderService.TranscriptionBufferState()
        state.micSamples = [0.1, 0.2]
        state.systemSamples = [0.3, 0.4]

        state.reset()

        XCTAssertTrue(state.micSamples.isEmpty)
        XCTAssertTrue(state.systemSamples.isEmpty)
    }

    // MARK: - transcriptionSampleRate constant

    @MainActor
    func testTranscriptionSampleRateIs16kHz() {
        XCTAssertEqual(AudioRecorderService.transcriptionSampleRate, 16000.0)
    }
}
