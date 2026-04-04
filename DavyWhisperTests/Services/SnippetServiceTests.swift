import XCTest
import SwiftData
@testable import DavyWhisper

@MainActor
final class SnippetServiceTests: XCTestCase {

    // MARK: - 1. Initialization

    @MainActor
    func testInit_emptyState() throws {
        let (service, appDir) = makeService()
        defer { cleanup(service: service, appDir: appDir) }

        XCTAssertTrue(service.snippets.isEmpty,
                       "Newly initialized service should have no snippets")
        XCTAssertEqual(service.enabledSnippetsCount, 0,
                       "enabledSnippetsCount should be 0 when empty")
    }

    // MARK: - 2. addSnippet creates a snippet

    @MainActor
    func testAddSnippet_appearsInList() throws {
        let (service, appDir) = makeService()
        defer { cleanup(service: service, appDir: appDir) }

        service.addSnippet(trigger: ";sig", replacement: "Best regards, Davy")

        XCTAssertEqual(service.snippets.count, 1)
        let snippet = service.snippets.first
        XCTAssertNotNil(snippet)
        XCTAssertEqual(snippet?.trigger, ";sig")
        XCTAssertEqual(snippet?.replacement, "Best regards, Davy")
        XCTAssertFalse(snippet!.caseSensitive)
        XCTAssertTrue(snippet!.isEnabled)
        XCTAssertEqual(snippet!.usageCount, 0)
    }

    // MARK: - 3. addSnippet duplicate guard

    @MainActor
    func testAddSnippet_duplicateTrigger_silentSkip() throws {
        let (service, appDir) = makeService()
        defer { cleanup(service: service, appDir: appDir) }

        service.addSnippet(trigger: ";sig", replacement: "First version")
        service.addSnippet(trigger: ";sig", replacement: "Second version")

        XCTAssertEqual(service.snippets.count, 1,
                       "Duplicate trigger should be silently skipped")
        XCTAssertEqual(service.snippets.first?.replacement, "First version",
                       "Original snippet should remain unchanged")
    }

    // MARK: - 4. updateSnippet

    @MainActor
    func testUpdateSnippet_changesValues() throws {
        let (service, appDir) = makeService()
        defer { cleanup(service: service, appDir: appDir) }

        service.addSnippet(trigger: ";sig", replacement: "Old replacement")
        let snippet = service.snippets.first!
        let originalID = snippet.id

        service.updateSnippet(snippet, trigger: ";signature", replacement: "New replacement", caseSensitive: true)

        // After update + reload the list is re-fetched, so grab fresh reference
        let updated = service.snippets.first { $0.id == originalID }
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.trigger, ";signature")
        XCTAssertEqual(updated?.replacement, "New replacement")
        XCTAssertTrue(updated!.caseSensitive)
    }

    // MARK: - 5. deleteSnippet

    @MainActor
    func testDeleteSnippet_removesFromList() throws {
        let (service, appDir) = makeService()
        defer { cleanup(service: service, appDir: appDir) }

        service.addSnippet(trigger: ";tmp", replacement: "temp text")
        XCTAssertEqual(service.snippets.count, 1)

        let snippet = service.snippets.first!
        service.deleteSnippet(snippet)

        XCTAssertTrue(service.snippets.isEmpty,
                       "Snippet should be removed after deletion")
    }

    // MARK: - 6. toggleSnippet

    @MainActor
    func testToggleSnippet_flipsIsEnabled() throws {
        let (service, appDir) = makeService()
        defer { cleanup(service: service, appDir: appDir) }

        service.addSnippet(trigger: ";em", replacement: "email@domain.com")
        let snippet = service.snippets.first!

        XCTAssertTrue(snippet.isEnabled, "Snippet should start enabled")

        service.toggleSnippet(snippet)
        XCTAssertFalse(service.snippets.first!.isEnabled,
                        "After first toggle, snippet should be disabled")

        service.toggleSnippet(service.snippets.first!)
        XCTAssertTrue(service.snippets.first!.isEnabled,
                       "After second toggle, snippet should be enabled again")
    }

    // MARK: - 7. enabledSnippetsCount

    @MainActor
    func testEnabledSnippetsCount_countsOnlyEnabled() throws {
        let (service, appDir) = makeService()
        defer { cleanup(service: service, appDir: appDir) }

        service.addSnippet(trigger: ";a", replacement: "A")
        service.addSnippet(trigger: ";b", replacement: "B")
        service.addSnippet(trigger: ";c", replacement: "C")

        XCTAssertEqual(service.enabledSnippetsCount, 3,
                       "All three snippets should be enabled by default")

        let snippetB = service.snippets.first { $0.trigger == ";b" }!
        service.toggleSnippet(snippetB)

        XCTAssertEqual(service.enabledSnippetsCount, 2,
                       "Only two snippets should be counted after disabling one")
    }

    // MARK: - 8. applySnippets case-insensitive replacement

    @MainActor
    func testApplySnippets_caseInsensitiveReplacement() throws {
        let (service, appDir) = makeService()
        defer { cleanup(service: service, appDir: appDir) }

        service.addSnippet(trigger: ";sig", replacement: "Regards, Davy")

        let input = "Hello ;SIG and ;Sig world"
        let result = service.applySnippets(to: input)

        XCTAssertFalse(result.contains(";SIG"))
        XCTAssertFalse(result.contains(";Sig"))
        XCTAssertTrue(result.contains("Regards, Davy"),
                       "Case-insensitive matching should replace all variants")
    }

    // MARK: - 9. applySnippets case-sensitive replacement (no match when case differs)

    @MainActor
    func testApplySnippets_caseSensitive_noMatchOnDifferentCase() throws {
        let (service, appDir) = makeService()
        defer { cleanup(service: service, appDir: appDir) }

        service.addSnippet(trigger: ";Sig", replacement: "Regards, Davy", caseSensitive: true)

        // Lowercase trigger won't match uppercase trigger when caseSensitive = true
        let input = "hello ;sig world"
        let result = service.applySnippets(to: input)

        XCTAssertEqual(result, input,
                       "Case-sensitive snippet should not replace different-case trigger")
    }

    @MainActor
    func testApplySnippets_caseSensitive_exactMatchReplaces() throws {
        let (service, appDir) = makeService()
        defer { cleanup(service: service, appDir: appDir) }

        service.addSnippet(trigger: ";Sig", replacement: "Regards, Davy", caseSensitive: true)

        let input = "hello ;Sig world"
        let result = service.applySnippets(to: input)

        XCTAssertEqual(result, "hello Regards, Davy world",
                       "Case-sensitive snippet should replace exact-case trigger")
    }

    // MARK: - 10. applySnippets multiple matching snippets

    @MainActor
    func testApplySnippets_multipleSnippetsAllReplaced() throws {
        let (service, appDir) = makeService()
        defer { cleanup(service: service, appDir: appDir) }

        service.addSnippet(trigger: ";sig", replacement: "Regards")
        service.addSnippet(trigger: ";em", replacement: "email@domain.com")

        let input = "Send to ;em -- ;sig"
        let result = service.applySnippets(to: input)

        XCTAssertEqual(result, "Send to email@domain.com -- Regards",
                       "All matching snippets should be replaced")
    }

    // MARK: - 11. applySnippets skips disabled snippets

    @MainActor
    func testApplySnippets_disabledSnippetNotApplied() throws {
        let (service, appDir) = makeService()
        defer { cleanup(service: service, appDir: appDir) }

        service.addSnippet(trigger: ";sig", replacement: "Regards")
        let snippet = service.snippets.first!
        service.toggleSnippet(snippet) // disable it

        let input = "Hello ;sig"
        let result = service.applySnippets(to: input)

        XCTAssertEqual(result, input,
                       "Disabled snippet should not be applied")
    }

    // MARK: - 12. applySnippets increments usageCount

    @MainActor
    func testApplySnippets_incrementsUsageCount() throws {
        let (service, appDir) = makeService()
        defer { cleanup(service: service, appDir: appDir) }

        service.addSnippet(trigger: ";sig", replacement: "Regards")
        XCTAssertEqual(service.snippets.first?.usageCount, 0)

        let _ = service.applySnippets(to: "Hello ;sig")

        let snippet = service.snippets.first!
        XCTAssertEqual(snippet.usageCount, 1,
                       "usageCount should increment to 1 after a single apply")

        let _ = service.applySnippets(to: "Again ;sig")
        XCTAssertEqual(service.snippets.first!.usageCount, 2,
                       "usageCount should increment to 2 after a second apply")
    }

    @MainActor
    func testApplySnippets_noMatchDoesNotIncrementUsageCount() throws {
        let (service, appDir) = makeService()
        defer { cleanup(service: service, appDir: appDir) }

        service.addSnippet(trigger: ";sig", replacement: "Regards")

        let _ = service.applySnippets(to: "Hello world, nothing to replace here")

        XCTAssertEqual(service.snippets.first?.usageCount, 0,
                       "usageCount should remain 0 when trigger is not found")
    }

    // MARK: - 13. applySnippets placeholder expansion (DATE)

    @MainActor
    func testApplySnippets_placeholderExpansion_date() throws {
        let (service, appDir) = makeService()
        defer { cleanup(service: service, appDir: appDir) }

        service.addSnippet(trigger: ";date", replacement: "{{DATE}}")

        let result = service.applySnippets(to: "Today is ;date")

        XCTAssertFalse(result.contains("{{DATE}}"),
                       "Placeholder should be expanded, not left as-is")
        XCTAssertFalse(result.contains(";date"),
                       "Trigger should be replaced")
        // The result should contain a date string (non-empty after the prefix)
        let prefix = "Today is "
        XCTAssertTrue(result.hasPrefix(prefix),
                       "Result should start with 'Today is '")
        let datePart = String(result.dropFirst(prefix.count))
        XCTAssertFalse(datePart.isEmpty,
                       "Date expansion should produce non-empty text")
    }

    @MainActor
    func testApplySnippets_placeholderExpansion_time() throws {
        let (service, appDir) = makeService()
        defer { cleanup(service: service, appDir: appDir) }

        service.addSnippet(trigger: ";time", replacement: "{{TIME}}")

        let result = service.applySnippets(to: "Now: ;time")

        XCTAssertFalse(result.contains("{{TIME}}"),
                       "TIME placeholder should be expanded")
    }

    @MainActor
    func testApplySnippets_placeholderExpansion_customDateFormat() throws {
        let (service, appDir) = makeService()
        defer { cleanup(service: service, appDir: appDir) }

        service.addSnippet(trigger: ";ymd", replacement: "{{DATE:yyyy-MM-dd}}")

        let result = service.applySnippets(to: "Date: ;ymd")

        XCTAssertFalse(result.contains("{{DATE"))
        // Should contain a date in yyyy-MM-dd format (e.g. 2026-04-04)
        let dateRegex = try NSRegularExpression(pattern: "\\d{4}-\\d{2}-\\d{2}")
        let matches = dateRegex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        XCTAssertGreaterThan(matches.count, 0,
                              "Custom date format should produce yyyy-MM-dd")
    }

    // MARK: - 14. applySnippets no matching snippets returns original

    @MainActor
    func testApplySnippets_noMatch_returnsOriginalText() throws {
        let (service, appDir) = makeService()
        defer { cleanup(service: service, appDir: appDir) }

        service.addSnippet(trigger: ";sig", replacement: "Regards")

        let input = "Hello world, nothing to replace"
        let result = service.applySnippets(to: input)

        XCTAssertEqual(result, input,
                       "Original text should be returned unchanged when no triggers match")
    }

    @MainActor
    func testApplySnippets_emptySnippets_returnsOriginalText() throws {
        let (service, appDir) = makeService()
        defer { cleanup(service: service, appDir: appDir) }

        // No snippets added at all
        let input = "Some text without any snippets"
        let result = service.applySnippets(to: input)

        XCTAssertEqual(result, input,
                       "Original text returned when snippet list is empty")
    }

    // MARK: - Helpers

    /// Creates a fresh SnippetService backed by an isolated temp directory.
    /// Returns the service and the app-support directory for deferred cleanup.
    @MainActor
    private func makeService(prefix: String = "SnippetServiceTests") -> (SnippetService, URL) {
        let appDir = TestSupport.makeTemporaryDirectorySafe(prefix: prefix)
        // Wipe any stale SwiftData files to ensure a clean schema
        for suffix in ["", "-wal", "-shm"] {
            let url = appDir.appendingPathComponent("snippets.store\(suffix)")
            try? FileManager.default.removeItem(at: url)
        }
        let service = SnippetService(appSupportDirectory: appDir)
        return (service, appDir)
    }

    /// Deletes all remaining Snippet entities then removes the temp directory.
    @MainActor
    private func cleanup(service: SnippetService, appDir: URL) {
        for snippet in service.snippets {
            service.deleteSnippet(snippet)
        }
        TestSupport.remove(appDir)
    }
}

// MARK: - TestSupport convenience

private extension TestSupport {
    /// Non-throwing variant of `makeTemporaryDirectory` suitable for use in
    /// test helpers that cannot propagate errors.
    static func makeTemporaryDirectorySafe(prefix: String = "DavyWhisperTests") -> URL {
        (try? makeTemporaryDirectory(prefix: prefix))
            ?? FileManager.default.temporaryDirectory
                .appendingPathComponent("\(prefix)-fallback-\(UUID().uuidString)", isDirectory: true)
    }
}
