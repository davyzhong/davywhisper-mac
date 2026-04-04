import XCTest
@testable import DavyWhisper

// MARK: - HistoryExporter Tests

final class HistoryExporterTests: XCTestCase {

    private func makeRecord(
        rawText: String = "hello world",
        finalText: String = "Hello world",
        language: String? = "en",
        engineUsed: String = "paraformer",
        modelUsed: String? = nil,
        appName: String? = nil,
        appBundleIdentifier: String? = nil,
        appURL: String? = nil,
        durationSeconds: Double = 5.0,
        wordsCount: Int = 0,
        pipelineStepList: [String] = []
    ) -> TranscriptionRecord {
        let record = TranscriptionRecord(
            rawText: rawText,
            finalText: finalText,
            appName: appName,
            appBundleIdentifier: appBundleIdentifier,
            appURL: appURL,
            durationSeconds: durationSeconds,
            language: language,
            engineUsed: engineUsed,
            modelUsed: modelUsed
        )
        record.wordsCount = wordsCount
        if !pipelineStepList.isEmpty {
            record.pipelineStepList = pipelineStepList
        }
        return record
    }

    // MARK: - ExportFormat Tests

    func testExportFormat_fileExtensions() {
        XCTAssertEqual(HistoryExportFormat.markdown.fileExtension, "md")
        XCTAssertEqual(HistoryExportFormat.plainText.fileExtension, "txt")
        XCTAssertEqual(HistoryExportFormat.json.fileExtension, "json")
    }

    func testExportFormat_displayNames() {
        XCTAssertEqual(HistoryExportFormat.markdown.displayName, "Markdown (.md)")
        XCTAssertEqual(HistoryExportFormat.plainText.displayName, "Plain Text (.txt)")
        XCTAssertEqual(HistoryExportFormat.json.displayName, "JSON (.json)")
    }

    func testExportFormat_allCases() {
        XCTAssertEqual(HistoryExportFormat.allCases.count, 3)
    }

    // MARK: - Markdown Export

    func testExportMarkdown_basicRecord() {
        let record = makeRecord(wordsCount: 2)
        let result = HistoryExporter.exportMarkdown(record)

        XCTAssertTrue(result.contains("# Transcription"))
        XCTAssertTrue(result.contains("**Duration:**"))
        XCTAssertTrue(result.contains("**Words:** 2"))
        XCTAssertTrue(result.contains("**Engine:** paraformer"))
        XCTAssertTrue(result.contains("Hello world"))
    }

    func testExportMarkdown_withLanguage() {
        let record = makeRecord(language: "zh")
        let result = HistoryExporter.exportMarkdown(record)
        XCTAssertTrue(result.contains("**Language:** ZH"))
    }

    func testExportMarkdown_withoutLanguage() {
        let record = makeRecord(language: nil)
        let result = HistoryExporter.exportMarkdown(record)
        XCTAssertFalse(result.contains("**Language:**"))
    }

    func testExportMarkdown_withAppInfo() {
        let record = makeRecord(appName: "Safari", appURL: "https://github.com/foo")
        let result = HistoryExporter.exportMarkdown(record)
        XCTAssertTrue(result.contains("**App:** Safari"))
        XCTAssertTrue(result.contains("github.com"))
    }

    func testExportMarkdown_withPostProcessing() {
        // wasPostProcessed is computed: rawText != finalText
        let record = makeRecord(rawText: "hello world", finalText: "Hello World")
        let result = HistoryExporter.exportMarkdown(record)
        XCTAssertTrue(result.contains("### Original"))
        XCTAssertTrue(result.contains("hello world"))
    }

    func testExportMarkdown_withoutPostProcessing() {
        // Same text = not post-processed
        let record = makeRecord(rawText: "Hello world", finalText: "Hello world")
        let result = HistoryExporter.exportMarkdown(record)
        XCTAssertFalse(result.contains("### Original"))
    }

    func testExportMarkdown_withPipelineSteps() {
        let record = makeRecord(pipelineStepList: ["dictation", "correction"])
        let result = HistoryExporter.exportMarkdown(record)
        XCTAssertTrue(result.contains("**Processing:**"))
    }

    func testExportMarkdown_durationFormatting_short() {
        let record = makeRecord(durationSeconds: 30)
        let result = HistoryExporter.exportMarkdown(record)
        XCTAssertTrue(result.contains("30s"))
    }

    func testExportMarkdown_durationFormatting_long() {
        let record = makeRecord(durationSeconds: 125)
        let result = HistoryExporter.exportMarkdown(record)
        XCTAssertTrue(result.contains("2m 5s"))
    }

    // MARK: - Plain Text Export

    func testExportPlainText() {
        let record = makeRecord(finalText: "This is the text")
        let result = HistoryExporter.exportPlainText(record)
        XCTAssertEqual(result, "This is the text")
    }

    // MARK: - JSON Export

    func testExportJSON_basicRecord() throws {
        let record = makeRecord(wordsCount: 2)
        let jsonString = HistoryExporter.exportJSON(record)

        let data = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["text"] as? String, "Hello world")
        XCTAssertEqual(json["rawText"] as? String, "hello world")
        XCTAssertEqual(json["duration"] as? Double, 5.0)
        XCTAssertEqual(json["words"] as? Int, 2)
        XCTAssertEqual(json["engine"] as? String, "paraformer")
        XCTAssertEqual(json["language"] as? String, "en")
    }

    func testExportJSON_withAppInfo() throws {
        let record = makeRecord(
            appName: "Notes",
            appBundleIdentifier: "com.apple.Notes",
            appURL: "https://example.com"
        )
        let jsonString = HistoryExporter.exportJSON(record)
        let data = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let app = json["app"] as! [String: String]
        XCTAssertEqual(app["name"], "Notes")
        XCTAssertEqual(app["bundleId"], "com.apple.Notes")
        XCTAssertEqual(app["url"], "https://example.com")
    }

    func testExportJSON_withModelUsed() throws {
        let record = makeRecord(modelUsed: "glm-4-flash")
        let jsonString = HistoryExporter.exportJSON(record)
        let data = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["model"] as? String, "glm-4-flash")
    }

    func testExportJSON_withPipelineSteps() throws {
        let record = makeRecord(pipelineStepList: ["dictation", "translation"])
        let jsonString = HistoryExporter.exportJSON(record)
        let data = jsonString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let steps = json["pipelineSteps"] as? [String]
        XCTAssertNotNil(steps)
        XCTAssertEqual(steps?.count, 2)
    }

    func testExportJSON_validJSON() {
        let record = makeRecord()
        let jsonString = HistoryExporter.exportJSON(record)
        let data = jsonString.data(using: .utf8)!
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    // MARK: - LLMProvider Tests

    func testLLMProviderType_displayName() {
        XCTAssertEqual(LLMProviderType.appleIntelligence.displayName, "Apple Intelligence")
    }

    func testLLMProviderType_rawValue() {
        XCTAssertEqual(LLMProviderType.appleIntelligence.rawValue, "appleIntelligence")
    }

    func testLLMError_descriptions() {
        XCTAssertFalse(LLMError.notAvailable.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(LLMError.providerError("test").errorDescription?.isEmpty ?? true)
        XCTAssertFalse(LLMError.inputTooLong.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(LLMError.noProviderConfigured.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(LLMError.noApiKey.errorDescription?.isEmpty ?? true)
    }

    func testLLMError_providerErrorIncludesMessage() {
        XCTAssertEqual(LLMError.providerError("timeout").errorDescription, "LLM error: timeout")
    }
}
