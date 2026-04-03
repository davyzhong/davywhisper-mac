import Foundation
import AppKit

/// Abstracts text insertion (clipboard + CGEvent paste) for testability.
/// The production implementation is TextInsertionService.
@MainActor
protocol TextInsertionProtocol: AnyObject {
    var isAccessibilityGranted: Bool { get }
    func insertText(_ text: String, preserveClipboard: Bool) async throws -> TextInsertionService.InsertionResult
    func requestAccessibilityPermission()
}
