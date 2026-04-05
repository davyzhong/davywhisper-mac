import Foundation
import DavyWhisperPluginSDK
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DavyWhisper", category: "PostProcessingPipeline")

struct PostProcessingResult {
    let text: String
    let appliedSteps: [String]
}

@MainActor
final class PostProcessingPipeline {
    private let snippetService: SnippetService
    private let appFormatterService: AppFormatterService?

    init(snippetService: SnippetService, appFormatterService: AppFormatterService? = nil) {
        self.snippetService = snippetService
        self.appFormatterService = appFormatterService
    }

    func process(
        text: String,
        context: PostProcessingContext,
        llmHandler: ((String) async throws -> String)? = nil,
        outputFormat: String? = nil,
        llmStepName: String? = nil
    ) async throws -> PostProcessingResult {
        // Build priority-ordered step list: (priority, id)
        // IDs: -1 = LLM, -2 = snippets, -4 = app formatter
        var steps: [(priority: Int, id: Int)] = []

        // App formatter at priority 150 (before LLM at 300)
        let formattingEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.appFormattingEnabled)
        if formattingEnabled, outputFormat != nil, appFormatterService != nil {
            steps.append((150, -4))
        }

        if llmHandler != nil {
            steps.append((300, -1))
        }
        steps.append((500, -2))
        steps.sort { $0.priority < $1.priority }

        var result = text
        var appliedSteps: [String] = []
        for step in steps {
            let before = result
            do {
                switch step.id {
                case -4:
                    result = appFormatterService!.format(
                        text: result,
                        bundleId: context.bundleIdentifier,
                        outputFormat: outputFormat
                    )
                case -1:
                    result = try await llmHandler!(result)
                case -2:
                    result = snippetService.applySnippets(to: result)
                default:
                    break
                }
                if result != before {
                    let name: String
                    switch step.id {
                    case -4: name = "Formatting"
                    case -1: name = llmStepName ?? "Prompt"
                    case -2: name = "Snippets"
                    default: name = "Unknown"
                    }
                    appliedSteps.append(name)
                }
            } catch {
                let name: String
                switch step.id {
                case -4: name = "AppFormatter"
                case -1: name = "LLM/Translation"
                case -2: name = "Snippets"
                default: name = "Unknown"
                }
                logger.error("Post-processor '\(name)' failed: \(error.localizedDescription)")
                // Only re-throw for LLM step
                if step.id == -1 {
                    throw error
                }
            }
        }

        return PostProcessingResult(text: result, appliedSteps: appliedSteps)
    }
}
