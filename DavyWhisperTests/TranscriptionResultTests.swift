import XCTest
@testable import DavyWhisper

final class TranscriptionResultTests: XCTestCase {

    func testRealTimeFactor() {
        let result = TranscriptionResult(
            text: "Hello",
            detectedLanguage: "en",
            duration: 10.0,
            processingTime: 2.0,
            engineUsed: "WhisperKit",
            segments: []
        )
        XCTAssertEqual(result.realTimeFactor, 5.0)
    }

    func testRealTimeFactorZeroDuration() {
        let result = TranscriptionResult(
            text: "",
            detectedLanguage: nil,
            duration: 0.0,
            processingTime: 1.0,
            engineUsed: "test",
            segments: []
        )
        XCTAssertEqual(result.realTimeFactor, 0.0)
    }

    func testTranscriptionSegment() {
        let seg = TranscriptionSegment(text: "Hello world", start: 1.5, end: 3.0)
        XCTAssertEqual(seg.text, "Hello world")
        XCTAssertEqual(seg.start, 1.5)
        XCTAssertEqual(seg.end, 3.0)
    }

    func testTranscriptionResultFields() {
        let segments = [
            TranscriptionSegment(text: "Hello", start: 0.0, end: 1.0),
            TranscriptionSegment(text: "World", start: 1.0, end: 2.0),
        ]
        let result = TranscriptionResult(
            text: "Hello World",
            detectedLanguage: "en",
            duration: 2.0,
            processingTime: 0.5,
            engineUsed: "WhisperKit",
            segments: segments
        )

        XCTAssertEqual(result.text, "Hello World")
        XCTAssertEqual(result.detectedLanguage, "en")
        XCTAssertEqual(result.duration, 2.0)
        XCTAssertEqual(result.processingTime, 0.5)
        XCTAssertEqual(result.engineUsed, "WhisperKit")
        XCTAssertEqual(result.segments.count, 2)
    }

    func testTranscriptionTaskAllCases() {
        XCTAssertEqual(TranscriptionTask.allCases.count, 2)
        XCTAssertEqual(TranscriptionTask.transcribe.id, "transcribe")
        XCTAssertEqual(TranscriptionTask.translate.id, "translate")
    }
}
