import Foundation
import FoundationModels

@available(macOS 26.0, iOS 26.0, *)
public final class AppleFoundationEngine: LLMEngineProtocol {
    private let model: SystemLanguageModel
    private let session: LanguageModelSession

    public var modelName: String { "AppleFoundationModel" }

    public init() throws {
        self.model = SystemLanguageModel.default
        guard model.availability == .available else {
            throw LLMEngineError.unsupportedPlatform
        }
        self.session = LanguageModelSession(model: model)
    }

    public func generate(prompt: String) async throws -> String {
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
