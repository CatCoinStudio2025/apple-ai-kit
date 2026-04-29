import Foundation

public struct ConversationContext: Codable, Sendable {
    public let previousIntent: Intent?
    public let previousEntities: [Entity]
    public let previousQuery: String?
    public let timestamp: Date

    public init(
        previousIntent: Intent? = nil,
        previousEntities: [Entity] = [],
        previousQuery: String? = nil,
        timestamp: Date = Date()
    ) {
        self.previousIntent = previousIntent
        self.previousEntities = previousEntities
        self.previousQuery = previousQuery
        self.timestamp = timestamp
    }
}
