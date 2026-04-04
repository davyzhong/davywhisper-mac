import XCTest
@testable import DavyWhisper

final class WavEncoderTests: XCTestCase {

    // MARK: - Header Constants

    /// Offset 0-3: "RIFF" magic bytes
    func testRIFFHeaderMagic() {
        let data = WavEncoder.encode([])
        let riff = data.subdata(in: 0..<4)
        XCTAssertEqual(riff, Data([0x52, 0x49, 0x46, 0x46]), "First 4 bytes must be 'RIFF'")
    }

    /// Offset 8-11: "WAVE" magic bytes
    func testWAVEMagic() {
        let data = WavEncoder.encode([])
        let wave = data.subdata(in: 8..<12)
        XCTAssertEqual(wave, Data([0x57, 0x41, 0x56, 0x45]), "Bytes 8-11 must be 'WAVE'")
    }

    /// Offset 12-15: "fmt " sub-chunk marker
    func testFmtSubchunkMarker() {
        let data = WavEncoder.encode([])
        let fmt = data.subdata(in: 12..<16)
        XCTAssertEqual(fmt, Data([0x66, 0x6D, 0x74, 0x20]), "Bytes 12-15 must be 'fmt '")
    }

    /// Offset 36-39: "data" sub-chunk marker
    func testDataSubchunkMarker() {
        let data = WavEncoder.encode([])
        let dataMarker = data.subdata(in: 36..<40)
        XCTAssertEqual(dataMarker, Data([0x64, 0x61, 0x74, 0x61]), "Bytes 36-39 must be 'data'")
    }

    // MARK: - Header Field Values

    /// Offset 20-21: Audio format = 1 (PCM)
    func testPCMFormat() {
        let data = WavEncoder.encode([])
        let format = data.subdata(in: 20..<22).withUnsafeBytes { $0.load(as: UInt16.self) }
        XCTAssertEqual(format, 1, "Audio format must be 1 (PCM)")
    }

    /// Offset 22-23: Number of channels = 1 (mono)
    func testChannelCount() {
        let data = WavEncoder.encode([])
        let channels = data.subdata(in: 22..<24).withUnsafeBytes { $0.load(as: UInt16.self) }
        XCTAssertEqual(channels, 1, "Channel count must be 1 (mono)")
    }

    /// Offset 24-27: Sample rate should match parameter (default 16000)
    func testDefaultSampleRate() {
        let data = WavEncoder.encode([])
        let sampleRate = data.subdata(in: 24..<28).withUnsafeBytes { $0.load(as: UInt32.self) }
        XCTAssertEqual(sampleRate, 16000, "Default sample rate must be 16000 Hz")
    }

    /// Offset 24-27: Sample rate should reflect custom parameter
    func testCustomSampleRate() {
        let data = WavEncoder.encode([0.0], sampleRate: 44100)
        let sampleRate = data.subdata(in: 24..<28).withUnsafeBytes { $0.load(as: UInt32.self) }
        XCTAssertEqual(sampleRate, 44100, "Custom sample rate must be 44100 Hz")
    }

    /// Offset 28-31: Byte rate = sampleRate * numChannels * bitsPerSample/8
    func testByteRate() {
        let data = WavEncoder.encode([], sampleRate: 16000)
        let byteRate = data.subdata(in: 28..<32).withUnsafeBytes { $0.load(as: UInt32.self) }
        // 16000 * 1 * 2 = 32000
        XCTAssertEqual(byteRate, 32000, "Byte rate must be sampleRate * channels * bytesPerSample")
    }

    /// Offset 32-33: Block align = numChannels * bitsPerSample/8 = 2
    func testBlockAlign() {
        let data = WavEncoder.encode([])
        let blockAlign = data.subdata(in: 32..<34).withUnsafeBytes { $0.load(as: UInt16.self) }
        XCTAssertEqual(blockAlign, 2, "Block align must be numChannels * bytesPerSample = 2")
    }

    /// Offset 34-35: Bits per sample = 16
    func testBitsPerSample() {
        let data = WavEncoder.encode([])
        let bps = data.subdata(in: 34..<36).withUnsafeBytes { $0.load(as: UInt16.self) }
        XCTAssertEqual(bps, 16, "Bits per sample must be 16")
    }

    // MARK: - Empty Input

    /// Empty input produces exactly a 44-byte header with zero-length data section
    func testEmptyInputProducesHeaderOnly() {
        let data = WavEncoder.encode([])
        // 44 bytes header, 0 bytes payload
        XCTAssertEqual(data.count, 44, "Empty input must produce exactly 44-byte WAV header")
    }

    /// Empty input: file size field (offset 4-7) should be 36 (36 + 0 data bytes)
    func testEmptyInputFileSize() {
        let data = WavEncoder.encode([])
        let fileSize = data.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self) }
        XCTAssertEqual(fileSize, 36, "File size field for empty input must be 36")
    }

    /// Empty input: data chunk size (offset 40-43) should be 0
    func testEmptyInputDataSize() {
        let data = WavEncoder.encode([])
        let dataSize = data.subdata(in: 40..<44).withUnsafeBytes { $0.load(as: UInt32.self) }
        XCTAssertEqual(dataSize, 0, "Data size field for empty input must be 0")
    }

    // MARK: - Single Sample

    /// Single sample at 1.0 produces 44 + 2 = 46 bytes
    func testSingleSampleOutputSize() {
        let data = WavEncoder.encode([1.0])
        XCTAssertEqual(data.count, 46, "Single sample must produce 44 header + 2 data bytes")
    }

    /// Single sample at 1.0 converts to Int16 max (32767)
    func testSingleSampleMaxValue() {
        let data = WavEncoder.encode([1.0])
        let sample = data.subdata(in: 44..<46).withUnsafeBytes { $0.load(as: Int16.self) }
        XCTAssertEqual(sample, 32767, "Sample 1.0 must convert to Int16 max (32767)")
    }

    /// Single sample at -1.0 converts to Int16 min (-32767, not -32768 due to multiplication)
    func testSingleSampleMinValue() {
        let data = WavEncoder.encode([-1.0])
        let sample = data.subdata(in: 44..<46).withUnsafeBytes { $0.load(as: Int16.self) }
        XCTAssertEqual(sample, -32767, "Sample -1.0 must convert to -32767")
    }

    /// Single sample at 0.0 converts to 0
    func testSingleSampleZero() {
        let data = WavEncoder.encode([0.0])
        let sample = data.subdata(in: 44..<46).withUnsafeBytes { $0.load(as: Int16.self) }
        XCTAssertEqual(sample, 0, "Sample 0.0 must convert to 0")
    }

    // MARK: - Int16 Conversion Correctness

    /// 0.5 converts to Int16(0.5 * 32767) = 16383
    func testHalfAmplitudePositive() {
        let data = WavEncoder.encode([0.5])
        let sample = data.subdata(in: 44..<46).withUnsafeBytes { $0.load(as: Int16.self) }
        XCTAssertEqual(sample, 16383)
    }

    /// -0.5 converts to Int16(-0.5 * 32767) = -16383
    func testHalfAmplitudeNegative() {
        let data = WavEncoder.encode([-0.5])
        let sample = data.subdata(in: 44..<46).withUnsafeBytes { $0.load(as: Int16.self) }
        XCTAssertEqual(sample, -16383)
    }

    /// Multiple samples produce correct sequential Int16 values
    func testMultipleSamples() {
        let samples: [Float] = [0.0, 1.0, -1.0, 0.5]
        let data = WavEncoder.encode(samples)
        // 44 header + 4 samples * 2 bytes = 52
        XCTAssertEqual(data.count, 52)

        let expected: [Int16] = [0, 32767, -32767, 16383]
        for i in 0..<4 {
            let offset = 44 + i * 2
            let sample = data.subdata(in: offset..<(offset + 2)).withUnsafeBytes { $0.load(as: Int16.self) }
            XCTAssertEqual(sample, expected[i], "Sample \(i) mismatch")
        }
    }

    // MARK: - Sample Clamping

    /// Value > 1.0 must be clamped to 1.0 (Int16 max)
    func testClampingAboveOne() {
        let data = WavEncoder.encode([2.0])
        let sample = data.subdata(in: 44..<46).withUnsafeBytes { $0.load(as: Int16.self) }
        XCTAssertEqual(sample, 32767, "Values > 1.0 must clamp to Int16 max")
    }

    /// Value < -1.0 must be clamped to -1.0 (Int16 min via formula)
    func testClampingBelowMinusOne() {
        let data = WavEncoder.encode([-5.0])
        let sample = data.subdata(in: 44..<46).withUnsafeBytes { $0.load(as: Int16.self) }
        XCTAssertEqual(sample, -32767, "Values < -1.0 must clamp to -32767")
    }

    /// Extreme positive value
    func testClampingExtremePositive() {
        let data = WavEncoder.encode([Float.greatestFiniteMagnitude])
        let sample = data.subdata(in: 44..<46).withUnsafeBytes { $0.load(as: Int16.self) }
        XCTAssertEqual(sample, 32767)
    }

    /// Extreme negative value
    func testClampingExtremeNegative() {
        let data = WavEncoder.encode([-Float.greatestFiniteMagnitude])
        let sample = data.subdata(in: 44..<46).withUnsafeBytes { $0.load(as: Int16.self) }
        XCTAssertEqual(sample, -32767)
    }

    /// Mixed clamped and unclamped values
    func testMixedClampedSamples() {
        let samples: [Float] = [0.0, 1.5, -2.0, 0.25]
        let data = WavEncoder.encode(samples)
        let expected: [Int16] = [0, 32767, -32767, 8191] // 0.25 * 32767 = 8191.75 -> 8191
        for i in 0..<4 {
            let offset = 44 + i * 2
            let sample = data.subdata(in: offset..<(offset + 2)).withUnsafeBytes { $0.load(as: Int16.self) }
            XCTAssertEqual(sample, expected[i], "Clamped sample \(i) mismatch")
        }
    }

    // MARK: - File Size and Data Size Fields

    /// File size field = 36 + dataSize for a known sample count
    func testFileSizeField() {
        let samples: [Float] = [0.0, 0.0, 0.0] // 3 samples
        let data = WavEncoder.encode(samples)
        let fileSize = data.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self) }
        XCTAssertEqual(fileSize, 42, "File size must be 36 + 3*2 = 42")
    }

    /// Data chunk size field = samples.count * 2
    func testDataSizeField() {
        let samples: [Float] = [0.0, 0.0, 0.0, 0.0, 0.0] // 5 samples
        let data = WavEncoder.encode(samples)
        let dataSize = data.subdata(in: 40..<44).withUnsafeBytes { $0.load(as: UInt32.self) }
        XCTAssertEqual(dataSize, 10, "Data size must be 5 * 2 = 10")
    }

    /// Total data length = 44 + samples.count * 2
    func testTotalOutputLength() {
        let sampleCount = 100
        let samples = [Float](repeating: 0.5, count: sampleCount)
        let data = WavEncoder.encode(samples)
        XCTAssertEqual(data.count, 44 + sampleCount * 2)
    }

    // MARK: - Data Integrity

    /// Output data count matches expected WAV file size for 3 samples
    func testOutputSizeIsCorrect() {
        let data = WavEncoder.encode([0.0, 0.5, 1.0])
        // WAV header (44 bytes) + 3 samples * 2 bytes (16-bit PCM)
        let expectedSize = 44 + 3 * 2
        XCTAssertEqual(data.count, expectedSize, "Output size should be WAV header (44) + sample data")
    }
}
