import Foundation
import NLUCore
import ToolRouter

public struct ResponseData: Sendable {
    public let intent: Intent
    public let originalQuery: String
    public let entities: [Entity]
    public let toolResult: ToolOutput
    public let context: ConversationContext?

    public init(
        intent: Intent,
        originalQuery: String,
        entities: [Entity],
        toolResult: ToolOutput,
        context: ConversationContext? = nil
    ) {
        self.intent = intent
        self.originalQuery = originalQuery
        self.entities = entities
        self.toolResult = toolResult
        self.context = context
    }
}
