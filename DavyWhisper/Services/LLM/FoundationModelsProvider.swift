import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

@available(macOS 26, *)
final class FoundationModelsProvider: LLMProvider, @unchecked Sendable {

    var isAvailable: Bool {
        #if canImport(FoundationModels)
        SystemLanguageModel.default.availability == .available
        #else
        false
        #endif
    }

    func process(systemPrompt: String, userText: String) async throws -> String {
        #if canImport(FoundationModels)
        let availability = SystemLanguageModel.default.availability
        guard availability == .available else {
            throw LLMError.notAvailable
        }

        let session = LanguageModelSession(instructions: systemPrompt)
        let response = try await session.respond(to: userText)
        return response.content
        #else
        throw LLMError.notAvailable
        #endif
    }
}
