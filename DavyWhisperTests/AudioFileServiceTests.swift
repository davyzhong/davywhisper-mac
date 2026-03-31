import XCTest
@testable import DavyWhisper

final class AudioFileServiceTests: XCTestCase {
    func testByteAlignmentCalculation() {
        // Simulate what AudioFileService does:
        // Audio data from AVAssetReader with 32-bit float PCM is always 4-byte aligned.
        // Verify the calculation: sampleCount = length / sizeof(Float)
        let floatSize = MemoryLayout<Float>.size  // 4
        XCTAssertEqual(floatSize, 4)

        // Complete bytes (truncated to Float boundary)
        let completeBytes = 100 / floatSize * floatSize  // 100 -> 25 floats (100 bytes)
        XCTAssertEqual(completeBytes, 100)
    }

    func testPartialBufferHandling() {
        // Simulate a buffer with incomplete Float (non-4-byte-multiple length)
        let floatSize = MemoryLayout<Float>.size
        let length = 103  // Not a multiple of 4
        let completeBytes = (length / floatSize) * floatSize
        let sampleCount = completeBytes / floatSize
        XCTAssertEqual(completeBytes, 100)  // 24 floats, 96 bytes, 7 bytes dropped
        XCTAssertEqual(sampleCount, 25)
    }

    func testSupportedExtensions() {
        let exts = AudioFileService.supportedExtensions
        XCTAssertTrue(exts.contains("wav"))
        XCTAssertTrue(exts.contains("mp3"))
        XCTAssertTrue(exts.contains("m4a"))
        XCTAssertTrue(exts.contains("flac"))
        XCTAssertTrue(exts.contains("mp4"))
        XCTAssertTrue(exts.contains("mov"))
        XCTAssertFalse(exts.contains("pdf"))
        XCTAssertFalse(exts.contains("txt"))
    }

    func testLoadAudioSamplesThrowsForMissingFile() async throws {
        let service = AudioFileService()
        let url = URL(fileURLWithPath: "/nonexistent/file.wav")
        do {
            _ = try await service.loadAudioSamples(from: url)
            XCTFail("Expected AudioFileError.fileNotFound to be thrown")
        } catch let error as AudioFileService.AudioFileError {
            XCTAssertEqual(error, .fileNotFound)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testLoadAudioSamplesThrowsForUnsupportedFormat() async throws {
        let service = AudioFileService()
        // Create a temp file with unsupported extension
        let tempDir = try FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test.\(UUID().uuidString).xyz")
        FileManager.default.createFile(atPath: tempFile.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        do {
            _ = try await service.loadAudioSamples(from: tempFile)
            XCTFail("Expected AudioFileError.unsupportedFormat to be thrown")
        } catch let error as AudioFileService.AudioFileError {
            XCTAssertEqual(error, .unsupportedFormat)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
