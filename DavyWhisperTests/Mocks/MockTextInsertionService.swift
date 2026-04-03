import Foundation
@testable import DavyWhisper

/// Mock TextInsertionService for unit testing.
@MainActor
final class MockTextInsertionService: TextInsertionProtocol {

    // MARK: - State

    var isAccessibilityGranted: Bool = true

    // MARK: - Call counting

    var insertTextCallCount = 0
    var requestAccessibilityPermissionCallCount = 0

    // MARK: - Recorded calls

    private(set) var insertedTexts: [(text: String, preserveClipboard: Bool)] = []

    // MARK: - Stubs

    var insertTextStub: ((String, Bool) async throws -> TextInsertionService.InsertionResult)?
    var requestAccessibilityPermissionStub: (() -> Void)?

    // MARK: - Protocol methods

    func insertText(_ text: String, preserveClipboard: Bool) async throws -> TextInsertionService.InsertionResult {
        insertTextCallCount += 1
        insertedTexts.append((text, preserveClipboard))
        if let stub = insertTextStub {
            return try await stub(text, preserveClipboard)
        }
        return .pasted
    }

    func requestAccessibilityPermission() {
        requestAccessibilityPermissionCallCount += 1
        requestAccessibilityPermissionStub?()
    }

    // MARK: - Convenience helpers

    func reset() {
        isAccessibilityGranted = true
        insertTextCallCount = 0
        requestAccessibilityPermissionCallCount = 0
        insertedTexts = []
        insertTextStub = nil
        requestAccessibilityPermissionStub = nil
    }
}
