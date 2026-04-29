import Foundation

public protocol LLMEngineProtocol: Sendable {
    func generate(prompt: String) async throws -> String
    var modelName: String { get }
}

public enum LLMEngineError: Error, Sendable {
    case modelNotLoaded
    case generationFailed(String)
    case contextLengthExceeded
    case invalidResponse
    case unsupportedPlatform
}
