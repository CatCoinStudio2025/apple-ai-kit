import Foundation

public final class IntentClassifier: Sendable {
    private let classifier: IntentClassifierProtocol
    private let confidenceThreshold: Double

    public init(classifier: IntentClassifierProtocol, confidenceThreshold: Double = 0.7) {
        self.classifier = classifier
        self.confidenceThreshold = confidenceThreshold
    }

    public func classify(_ text: String) async throws -> ClassificationResult {
        let result = try await classifier.classify(text)
        if result.confidence.isConfident {
            return result
        }
        let adjustedConfidence = Confidence(
            score: result.confidence.score,
            threshold: confidenceThreshold
        )
        return ClassificationResult(intent: result.intent, confidence: adjustedConfidence)
    }

    public func classifyWithOptions(_ text: String, topK: Int = 3) async throws -> [ClassificationResult] {
        let results = try await classifier.classifyWithOptions(text, topK: topK)
        return results.map { result in
            ClassificationResult(
                intent: result.intent,
                confidence: Confidence(score: result.confidence.score, threshold: confidenceThreshold)
            )
        }
    }
}
