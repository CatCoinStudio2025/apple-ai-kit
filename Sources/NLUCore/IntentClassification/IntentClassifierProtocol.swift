import Foundation

public protocol IntentClassifierProtocol: Sendable {
    func classify(_ text: String) async throws -> ClassificationResult
    func classifyWithOptions(_ text: String, topK: Int) async throws -> [ClassificationResult]
}
