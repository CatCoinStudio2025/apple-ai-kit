import Foundation

public final class SentenceEmbedding: SentenceEmbeddingProtocol {
    private let embeddingDimension: Int = 384

    public init() {}

    public func embed(_ text: String) async throws -> [Float] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SentenceEmbeddingError.emptyText
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var embedding = [Float](repeating: 0, count: embeddingDimension)

        for token in trimmed.split(whereSeparator: \.isWhitespace) {
            var hasher = Hasher()
            hasher.combine(token)
            let hash = abs(hasher.finalize())
            let bucket = hash % embeddingDimension
            embedding[bucket] += 1.0
        }

        return normalize(embedding)
    }

    public func similarity(_ text1: String, _ text2: String) async throws -> Float {
        let embedding1 = try await embed(text1)
        let embedding2 = try await embed(text2)
        return cosineSimilarity(embedding1, embedding2)
    }

    public func mostSimilar(to query: String, in candidates: [String]) async throws -> (String, Float)? {
        guard !candidates.isEmpty else { return nil }

        let queryEmbedding = try await embed(query)
        var bestMatch: (String, Float) = ("", -1)

        for candidate in candidates {
            let candidateEmbedding = try await embed(candidate)
            let similarity = cosineSimilarity(queryEmbedding, candidateEmbedding)
            if similarity > bestMatch.1 {
                bestMatch = (candidate, similarity)
            }
        }

        return bestMatch.1 >= 0 ? bestMatch : nil
    }

    private func normalize(_ vector: [Float]) -> [Float] {
        let magnitude = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard magnitude > 0 else { return vector }
        return vector.map { $0 / Float(magnitude) }
    }

    private func cosineSimilarity(_ v1: [Float], _ v2: [Float]) -> Float {
        guard v1.count == v2.count else { return 0 }
        let dotProduct = zip(v1, v2).reduce(Float(0)) { $0 + $1.0 * $1.1 }
        let magnitude1 = sqrt(v1.reduce(Float(0)) { $0 + $1 * $1 })
        let magnitude2 = sqrt(v2.reduce(Float(0)) { $0 + $1 * $1 })
        guard magnitude1 > 0 && magnitude2 > 0 else { return 0 }
        return dotProduct / (magnitude1 * magnitude2)
    }
}
