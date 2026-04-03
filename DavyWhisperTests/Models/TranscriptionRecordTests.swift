import XCTest
@testable import DavyWhisper
import SwiftData

final class TranscriptionRecordTests: XCTestCase {

    // MARK: - pipelineStepList JSON Encoding/Decoding

    func testPipelineStepList_roundTrip() throws {
        let record = TranscriptionRecord(
            rawText: "original",
            finalText: "corrected",
            durationSeconds: 1.0,
            engineUsed: "WhisperKit"
        )
        record.pipelineStepList = ["Formatting", "Snippets", "Corrections"]

        let retrieved = record.pipelineStepList
        XCTAssertEqual(retrieved, ["Formatting", "Snippets", "Corrections"])
    }

    func testPipelineStepList_emptyReturnsEmptyArray() throws {
        let record = TranscriptionRecord(
            rawText: "text",
            finalText: "text",
            durationSeconds: 0,
            engineUsed: "WhisperKit"
        )
        record.pipelineSteps = nil
        XCTAssertEqual(record.pipelineStepList, [])
    }

    func testPipelineStepList_emptyArraySetsNil() throws {
        let record = TranscriptionRecord(
            rawText: "text",
            finalText: "text",
            durationSeconds: 0,
            engineUsed: "WhisperKit"
        )
        record.pipelineStepList = []
        XCTAssertNil(record.pipelineSteps)
    }

    func testPipelineStepList_legacyCommaSeparated_backwardCompatible() throws {
        let record = TranscriptionRecord(
            rawText: "text",
            finalText: "text",
            durationSeconds: 0,
            engineUsed: "WhisperKit"
        )
        // Old format: comma-separated string
        record.pipelineSteps = "Formatting,Snippets"

        let retrieved = record.pipelineStepList
        XCTAssertEqual(retrieved, ["Formatting", "Snippets"])
    }

    // MARK: - Computed Properties

    func testWasPostProcessed_trueWhenTextChanged() throws {
        let record = TranscriptionRecord(
            rawText: "original",
            finalText: "corrected",
            durationSeconds: 1.0,
            engineUsed: "WhisperKit"
        )
        XCTAssertTrue(record.wasPostProcessed)
    }

    func testWasPostProcessed_falseWhenTextSame() throws {
        let record = TranscriptionRecord(
            rawText: "same text",
            finalText: "same text",
            durationSeconds: 0,
            engineUsed: "WhisperKit"
        )
        XCTAssertFalse(record.wasPostProcessed)
    }

    func testWasPostProcessed_trueWithWhitespaceDifference() throws {
        // wasPostProcessed = true when trimmed rawText differs from finalText
        let record = TranscriptionRecord(
            rawText: "  HELLO WORLD  ",
            finalText: "hello world",
            durationSeconds: 1.0,
            engineUsed: "WhisperKit"
        )
        XCTAssertTrue(record.wasPostProcessed)
    }

    func testPreview_truncatesTo100Chars() throws {
        let longText = String(repeating: "x", count: 200)
        let record = TranscriptionRecord(
            rawText: longText,
            finalText: longText,
            durationSeconds: 0,
            engineUsed: "WhisperKit"
        )
        XCTAssertEqual(record.preview.count, 100)
        XCTAssertEqual(record.preview, String(repeating: "x", count: 100))
    }

    func testPreview_exact100Chars_noTruncation() throws {
        let exact100 = String(repeating: "a", count: 100)
        let record = TranscriptionRecord(
            rawText: exact100,
            finalText: exact100,
            durationSeconds: 0,
            engineUsed: "WhisperKit"
        )
        XCTAssertEqual(record.preview.count, 100)
    }

    // MARK: - App Domain

    func testAppDomain_extractsFromURL() throws {
        let record = TranscriptionRecord(
            rawText: "text",
            finalText: "text",
            durationSeconds: 0,
            engineUsed: "WhisperKit"
        )
        record.appURL = "https://github.com/user/repo"

        XCTAssertEqual(record.appDomain, "github.com")
    }

    func testAppDomain_nilWhenNoURL() throws {
        let record = TranscriptionRecord(
            rawText: "text",
            finalText: "text",
            durationSeconds: 0,
            engineUsed: "WhisperKit"
        )
        XCTAssertNil(record.appDomain)
    }

    func testAppDomain_nilWhenInvalidURL() throws {
        let record = TranscriptionRecord(
            rawText: "text",
            finalText: "text",
            durationSeconds: 0,
            engineUsed: "WhisperKit"
        )
        record.appURL = "not a valid url"
        XCTAssertNil(record.appDomain)
    }

    // MARK: - Word Count

    func testWordCount_storedInPipelineSteps() throws {
        // wordsCount is a property on the record
        let record = TranscriptionRecord(
            rawText: "one two three",
            finalText: "one two three",
            durationSeconds: 0,
            engineUsed: "WhisperKit"
        )
        record.wordsCount = 3
        XCTAssertEqual(record.wordsCount, 3)
    }

    // MARK: - Initialization

    func testInit_defaultValues() throws {
        let record = TranscriptionRecord(
            rawText: "raw",
            finalText: "final",
            durationSeconds: 2.5,
            engineUsed: "Deepgram"
        )
        XCTAssertEqual(record.rawText, "raw")
        XCTAssertEqual(record.finalText, "final")
        XCTAssertEqual(record.engineUsed, "Deepgram")
        XCTAssertNotNil(record.id)
        XCTAssertNotNil(record.timestamp)
        XCTAssertEqual(record.durationSeconds, 2.5)
    }
}
