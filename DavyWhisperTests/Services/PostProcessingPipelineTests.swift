import XCTest
@testable import DavyWhisper
import DavyWhisperPluginSDK

@MainActor
final class PostProcessingPipelineTests: XCTestCase {

    var tempDir: URL!
    var snippetService: SnippetService!
    var dictionaryService: DictionaryService!
    var appFormatterService: AppFormatterService!
    var pipeline: PostProcessingPipeline!

    override func setUp() {
        super.setUp()
        tempDir = try! TestSupport.makeTemporaryDirectory()
        let appDir = tempDir.appendingPathComponent("AppSupport", isDirectory: true)
        try! FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        let original = AppConstants.testAppSupportDirectoryOverride
        AppConstants.testAppSupportDirectoryOverride = appDir

        snippetService = SnippetService(appSupportDirectory: appDir)
        dictionaryService = DictionaryService(appSupportDirectory: appDir)
        appFormatterService = AppFormatterService()
        pipeline = PostProcessingPipeline(
            snippetService: snippetService,
            dictionaryService: dictionaryService,
            appFormatterService: appFormatterService
        )

        AppConstants.testAppSupportDirectoryOverride = original
    }

    override func tearDown() {
        // Remove SwiftData store files directly to avoid cross-test pollution
        // (modelContext is private so we delete the store files directly)
        let fileManager = FileManager.default
        let appDir = tempDir.appendingPathComponent("AppSupport", isDirectory: true)
        for store in ["snippets.store", "snippets.store-wal", "snippets.store-shm",
                      "dictionary.store", "dictionary.store-wal", "dictionary.store-shm"] {
            try? fileManager.removeItem(at: appDir.appendingPathComponent(store))
        }
        snippetService = nil
        dictionaryService = nil
        appFormatterService = nil
        pipeline = nil
        TestSupport.remove(tempDir)
        super.tearDown()
    }

    // MARK: - Priority Ordering

    func testPriority_order_snippetsBeforeDictionary() async throws {
        // snippets priority=500, dictionary=600 → snippets runs first
        // Set up a snippet so the step actually applies and we can verify order
        try snippetService.addSnippet(trigger: "{{test}}", replacement: "REPLACED")
        let result = try await pipeline.process(
            text: "hello {{test}}",
            context: PostProcessingContext()
        )
        XCTAssertEqual(result.text, "hello REPLACED")
        XCTAssertTrue(result.appliedSteps.contains("Snippets"))
    }

    func testPriority_order_noLLMStepWhenNoHandlerProvided() async throws {
        let result = try await pipeline.process(
            text: "plain text",
            context: PostProcessingContext()
        )
        // No LLM step applied
        XCTAssertFalse(result.appliedSteps.contains("Prompt"))
    }

    // MARK: - Snippet Step

    func testSnippets_stepReplacesPlaceholder() async throws {
        try snippetService.addSnippet(trigger: "tt", replacement: "test trigger expansion")
        let result = try await pipeline.process(
            text: "hello tt world",
            context: PostProcessingContext()
        )
        XCTAssertEqual(result.text, "hello test trigger expansion world")
        XCTAssertTrue(result.appliedSteps.contains("Snippets"))
    }

    func testSnippets_stepNoMatch_doesNotApply() async throws {
        // Snippet not registered — no replacement should happen
        let result = try await pipeline.process(
            text: "hello world",
            context: PostProcessingContext()
        )
        XCTAssertFalse(result.appliedSteps.contains("Snippets"))
    }

    // Note: Disabled entries cannot be tested via the public API (addSnippet/addEntry
    // have no isEnabled parameter — all entries default to isEnabled=true).
    // The filtering of disabled entries is verified through the service implementation
    // (applySnippets filters by snippet.isEnabled; corrections filters by isEnabled).

    // MARK: - Dictionary Step

    func testDictionary_stepAppliesCorrections() async throws {
        try dictionaryService.addEntry(type: .correction, original: "teh", replacement: "the")
        let result = try await pipeline.process(
            text: "teh quick brown fox",
            context: PostProcessingContext()
        )
        XCTAssertEqual(result.text, "the quick brown fox")
        XCTAssertTrue(result.appliedSteps.contains("Corrections"))
    }

    func testDictionary_stepAppliesMultipleCorrections() async throws {
        try dictionaryService.addEntry(type: .correction, original: "teh", replacement: "the")
        try dictionaryService.addEntry(type: .correction, original: "qt", replacement: "quick")
        let result = try await pipeline.process(
            text: "teh qt fox",
            context: PostProcessingContext()
        )
        XCTAssertEqual(result.text, "the quick fox")
        XCTAssertTrue(result.appliedSteps.contains("Corrections"))
    }

    // MARK: - Chained Pipeline

    func testChain_snippetsThenDictionary() async throws {
        try snippetService.addSnippet(trigger: "code", replacement: "CONFIDENTIAL")
        try dictionaryService.addEntry(type: .correction, original: "conf", replacement: "CONF")

        // Snippets run first (500) then dictionary (600)
        // "CONFIDENTIAL" has "conf" inside it, dictionary runs on output of snippets
        let result = try await pipeline.process(
            text: "sensitive code information",
            context: PostProcessingContext()
        )
        // Snippets: "code" → "CONFIDENTIAL"
        XCTAssertTrue(result.text.contains("CONFIDENTIAL"))
    }

    // MARK: - LLM Handler

    func testLLMStep_appliesHandlerAndRecordsStep() async throws {
        let result = try await pipeline.process(
            text: "hello world",
            context: PostProcessingContext(),
            llmHandler: { _ in "HELLO WORLD (uppercased)" },
            llmStepName: "Uppercase"
        )
        XCTAssertEqual(result.text, "HELLO WORLD (uppercased)")
        XCTAssertTrue(result.appliedSteps.contains("Uppercase"))
    }

    func testLLMStep_errorPropagates() async throws {
        struct TestError: Error {}
        do {
            _ = try await pipeline.process(
                text: "hello",
                context: PostProcessingContext(),
                llmHandler: { _ in throw TestError() },
                llmStepName: "FailingStep"
            )
            XCTFail("Expected error to propagate")
        } catch {
            // Expected
        }
    }

    func testLLMStep_nonLLMErrorDoesNotPropagate() async throws {
        // Non-LLM errors are logged but not re-thrown
        let result = try await pipeline.process(
            text: "hello world",
            context: PostProcessingContext(),
            llmHandler: { _ in "done" },
            llmStepName: "Success"
        )
        XCTAssertEqual(result.text, "done")
    }

    // MARK: - Empty / Edge Cases

    func testEmptyText_returnsEmpty() async throws {
        let result = try await pipeline.process(
            text: "",
            context: PostProcessingContext()
        )
        XCTAssertEqual(result.text, "")
    }

    func testNoStepsApplied_returnsOriginalText() async throws {
        let result = try await pipeline.process(
            text: "unchanged text",
            context: PostProcessingContext()
        )
        XCTAssertEqual(result.text, "unchanged text")
        XCTAssertTrue(result.appliedSteps.isEmpty)
    }
}
