import Foundation

public final class NLUCore: Sendable {
    private let embedding: SentenceEmbedding
    private let classifier: IntentClassifier
    private let entityExtractor: EntityExtractor
    private let contextMemory: ContextMemory

    public init(
        intentPhrases: [Intent: [String]] = [:],
        confidenceThreshold: Double = 0.7
    ) {
        let sentenceEmbedding = SentenceEmbedding()
        self.embedding = sentenceEmbedding

        let similarity = SimilarityClassifier(embedding: sentenceEmbedding)
        if !intentPhrases.isEmpty {
            similarity.registerPhrases(intentPhrases)
        }
        let intentClassifier: IntentClassifierProtocol = similarity

        self.classifier = IntentClassifier(
            classifier: intentClassifier,
            confidenceThreshold: confidenceThreshold
        )

        self.entityExtractor = EntityExtractor()
        self.contextMemory = ContextMemory()
    }

    public func parse(_ text: String) async throws -> ParsedQuery {
        async let classificationTask = classifier.classify(text)
        async let entitiesTask = entityExtractor.extract(from: text)

        let (classification, entities) = try await (classificationTask, entitiesTask)

        contextMemory.save(classification.intent, entities: entities, query: text)

        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return ParsedQuery(
            originalText: text,
            normalizedText: normalizedText,
            intent: classification.intent,
            confidence: classification.confidence,
            entities: entities
        )
    }

    public func parseWithContext(_ text: String) async throws -> ParsedQuery {
        let parsed = try await parse(text)

        guard let context = contextMemory.getPreviousContext() else {
            return parsed
        }

        var mergedEntities = parsed.entities

        if parsed.entities.isEmpty {
            mergedEntities = context.previousEntities
        }

        return ParsedQuery(
            originalText: parsed.originalText,
            normalizedText: parsed.normalizedText,
            intent: parsed.intent,
            confidence: parsed.confidence,
            entities: mergedEntities
        )
    }

    public func getContext() -> ConversationContext? {
        contextMemory.getPreviousContext()
    }

    public func clearContext() {
        contextMemory.clear()
    }
}
