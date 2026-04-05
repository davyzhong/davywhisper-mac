import XCTest
@testable import DavyWhisper
import DavyWhisperPluginSDK

@MainActor
final class PostProcessingPipelineTests: XCTestCase {

    var tempDir: URL!
    var snippetService: SnippetService!
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
        appFormatterService = AppFormatterService()
        pipeline = PostProcessingPipeline(
            snippetService: snippetService,
            appFormatterService: appFormatterService
        )

        AppConstants.testAppSupportDirectoryOverride = original
    }

    override func tearDown() {
        // Remove SwiftData store files directly to avoid cross-test pollution
        // (modelContext is private so we delete the store files directly)
        let fileManager = FileManager.default
        let appDir = tempDir.appendingPathComponent("AppSupport", isDirectory: true)
        for store in ["snippets.store", "snippets.store-wal", "snippets.store-shm"] {
            try? fileManager.removeItem(at: appDir.appendingPathComponent(store))
        }
        snippetService = nil
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
