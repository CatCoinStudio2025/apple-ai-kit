import Foundation

public final class SimilarityClassifier: IntentClassifierProtocol, @unchecked Sendable {
    private let embedding: SentenceEmbeddingProtocol
    private var intentPhrases: [Intent: [String]]
    private var cachedEmbeddings: [Intent: [String: [Float]]] = [:]

    public init(embedding: SentenceEmbeddingProtocol, intentPhrases: [Intent: [String]] = [:]) {
        self.embedding = embedding
        self.intentPhrases = intentPhrases
    }

    public func registerPhrases(_ phrases: [Intent: [String]]) {
        self.intentPhrases = phrases
        self.cachedEmbeddings.removeAll()
    }

    public func classify(_ text: String) async throws -> ClassificationResult {
        let results = try await classifyWithOptions(text, topK: 1)
        return results.first ?? ClassificationResult(intent: .unknown, confidence: Confidence(score: 0))
    }

    public func classifyWithOptions(_ text: String, topK: Int) async throws -> [ClassificationResult] {
        var similarities: [(Intent, Float)] = []

        for intent in Intent.allCases {
            guard let phrases = intentPhrases[intent], !phrases.isEmpty else { continue }

            var maxSimilarity: Float = 0

            for phrase in phrases {
                let similarity = try await embedding.similarity(text, phrase)
                maxSimilarity = max(maxSimilarity, similarity)
            }

            similarities.append((intent, maxSimilarity))
        }

        similarities.sort { $0.1 > $1.1 }
        let topResults = similarities.prefix(topK)

        return topResults.map { (intent, score) in
            ClassificationResult(
                intent: intent,
                confidence: Confidence(score: Double(score))
            )
        }
    }

    private func getCachedEmbedding(for intent: Intent, phrase: String) async throws -> [Float]? {
        if let phraseEmbeddings = cachedEmbeddings[intent], let cached = phraseEmbeddings[phrase] {
            return cached
        }

        let newEmbedding = try await embedding.embed(phrase)

        if cachedEmbeddings[intent] == nil {
            cachedEmbeddings[intent] = [:]
        }
        cachedEmbeddings[intent]?[phrase] = newEmbedding

        return newEmbedding
    }
}
