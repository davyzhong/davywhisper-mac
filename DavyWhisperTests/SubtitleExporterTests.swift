import XCTest
@testable import DavyWhisper

final class SubtitleExporterTests: XCTestCase {

    // MARK: - SRT

    func testExportSRTSingleSegment() {
        let segments = [TranscriptionSegment(text: "Hello world", start: 0.0, end: 2.5)]
        let result = SubtitleExporter.exportSRT(segments: segments)

        XCTAssertTrue(result.hasPrefix("1\n"))
        XCTAssertTrue(result.contains("00:00:00,000 --> 00:00:02,500"))
        XCTAssertTrue(result.contains("Hello world"))
    }

    func testExportSRTMultipleSegments() {
        let segments = [
            TranscriptionSegment(text: "First", start: 0.0, end: 1.0),
            TranscriptionSegment(text: "Second", start: 1.5, end: 3.0),
            TranscriptionSegment(text: "Third", start: 3.5, end: 5.0),
        ]
        let result = SubtitleExporter.exportSRT(segments: segments)

        XCTAssertEqual(result.components(separatedBy: "\n\n").count, 3)
        XCTAssertTrue(result.contains("1\n"))
        XCTAssertTrue(result.contains("2\n"))
        XCTAssertTrue(result.contains("3\n"))
    }

    func testExportSRTTimeFormatting() {
        // 1h 23m 45s 678ms
        let segments = [TranscriptionSegment(text: "test", start: 0.0, end: 5025.678)]
        let result = SubtitleExporter.exportSRT(segments: segments)

        XCTAssertTrue(result.contains("00:00:00,000 --> 01:23:45,678"))
    }

    func testExportSRTEmptySegments() {
        let result = SubtitleExporter.exportSRT(segments: [])
        XCTAssertEqual(result, "")
    }

    // MARK: - VTT

    func testExportVTTHeader() {
        let segments = [TranscriptionSegment(text: "Hello", start: 0.0, end: 1.0)]
        let result = SubtitleExporter.exportVTT(segments: segments)

        XCTAssertTrue(result.hasPrefix("WEBVTT\n\n"))
    }

    func testExportVTTSingleSegment() {
        let segments = [TranscriptionSegment(text: "Hello world", start: 0.0, end: 2.5)]
        let result = SubtitleExporter.exportVTT(segments: segments)

        XCTAssertTrue(result.contains("00:00:00.000 --> 00:00:02.500"))
        XCTAssertTrue(result.contains("Hello world"))
    }

    func testExportVTTEmptySegments() {
        let result = SubtitleExporter.exportVTT(segments: [])
        // WEBVTT header + empty line
        XCTAssertEqual(result, "WEBVTT\n")
    }

    // MARK: - Format enum

    func testSubtitleFormatExtensions() {
        XCTAssertEqual(SubtitleFormat.srt.fileExtension, "srt")
        XCTAssertEqual(SubtitleFormat.vtt.fileExtension, "vtt")
    }

    func testSubtitleFormatAllCases() {
        XCTAssertEqual(SubtitleFormat.allCases.count, 2)
    }
}
