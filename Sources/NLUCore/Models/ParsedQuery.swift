import Foundation

public struct ParsedQuery: Sendable {
    public let originalText: String
    public let normalizedText: String
    public let intent: Intent
    public let confidence: Confidence
    public let entities: [Entity]
    public let timestamp: Date

    public init(
        originalText: String,
        normalizedText: String,
        intent: Intent,
        confidence: Confidence,
        entities: [Entity],
        timestamp: Date = Date()
    ) {
        self.originalText = originalText
        self.normalizedText = normalizedText
        self.intent = intent
        self.confidence = confidence
        self.entities = entities
        self.timestamp = timestamp
    }
}
