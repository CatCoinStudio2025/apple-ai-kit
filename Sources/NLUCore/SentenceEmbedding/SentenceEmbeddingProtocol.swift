import Foundation
import NaturalLanguage

public protocol SentenceEmbeddingProtocol: Sendable {
    func embed(_ text: String) async throws -> [Float]
    func similarity(_ text1: String, _ text2: String) async throws -> Float
    func mostSimilar(to query: String, in candidates: [String]) async throws -> (String, Float)?
}
