import Foundation
import NLUCore
import ToolRouter

public final class ResponseEngine {
    public init() {}

    public func buildResponseData(
        intent: Intent,
        originalQuery: String,
        entities: [Entity],
        toolResult: ToolOutput,
        context: ConversationContext? = nil
    ) -> ResponseData {
        ResponseData(
            intent: intent,
            originalQuery: originalQuery,
            entities: entities,
            toolResult: toolResult,
            context: context
        )
    }

    public func buildResponseData(from parsedQuery: ParsedQuery, toolResult: ToolOutput, context: ConversationContext? = nil) -> ResponseData {
        ResponseData(
            intent: parsedQuery.intent,
            originalQuery: parsedQuery.originalText,
            entities: parsedQuery.entities,
            toolResult: toolResult,
            context: context
        )
    }
}
