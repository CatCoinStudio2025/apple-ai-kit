import Foundation
import NLUCore

public final class ToolRouter: Sendable {
    private let registry: ToolRegistry
    private let intentToolMap: IntentToolMap

    public init(registry: ToolRegistry = ToolRegistry(), intentToolMap: IntentToolMap = IntentToolMap()) {
        self.registry = registry
        self.intentToolMap = intentToolMap
    }

    public func route(_ parsedQuery: ParsedQuery) async throws -> ToolResult {
        let intent = parsedQuery.intent

        guard intent != .unknown else {
            return ToolResult(
                intent: .unknown,
                success: true,
                data: nil,
                message: "Chào bạn! Tôi có thể giúp gì cho bạn hôm nay?"
            )
        }

        guard let toolEntry = registry.get(for: intent) else {
            return ToolResult(
                intent: intent,
                success: false,
                data: nil,
                message: "Xin lỗi, tôi chưa hiểu ý của bạn. Bạn có thể diễn đạt lại không?"
            )
        }

        let entities = parsedQuery.entities
        let input = ToolInput(intent: intent, entities: entities, originalText: parsedQuery.originalText)

        let result = try await executeTool(toolEntry, with: input)

        return result
    }

    private func executeTool(_ tool: any Sendable, with input: ToolInput) async throws -> ToolResult {
        let mirror = Mirror(reflecting: tool)

        guard let executeMethod = mirror.children.first(where: { $0.label == "execute" }) else {
            throw ToolRouterError.executionFailed("Tool does not have execute method")
        }

        guard let function = executeMethod.value as? (ToolInput) async throws -> ToolOutput else {
            throw ToolRouterError.executionFailed("Invalid tool signature")
        }

        let output = try await function(input)

        return ToolResult(
            intent: input.intent,
            success: true,
            data: output.data,
            message: output.message
        )
    }

    public func registerDefaultTools() {
    }
}

public struct ToolInput: Sendable {
    public let intent: Intent
    public let entities: [Entity]
    public let originalText: String

    public init(intent: Intent, entities: [Entity], originalText: String) {
        self.intent = intent
        self.entities = entities
        self.originalText = originalText
    }
}

public struct ToolOutput: @unchecked Sendable {
    public let data: [String: Any]?
    public let message: String

    public init(data: [String: Any]? = nil, message: String) {
        self.data = data
        self.message = message
    }
}

public struct ToolResult: @unchecked Sendable {
    public let intent: Intent
    public let success: Bool
    public let data: [String: Any]?
    public let message: String

    public init(intent: Intent, success: Bool, data: [String: Any]?, message: String) {
        self.intent = intent
        self.success = success
        self.data = data
        self.message = message
    }
}
