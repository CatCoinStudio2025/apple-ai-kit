import Foundation

public enum LLMEngineError: Error, Sendable {
    case modelNotLoaded
    case generationFailed(String)
    case contextLengthExceeded
    case invalidResponse
    case unsupportedPlatform
    case toolCallFailed(String)
    case invalidRequest(String)
}

public enum MessageRole: String, Codable, Sendable {
    case system
    case user
    case assistant
    case tool
}

public struct ChatMessage: Codable, Sendable {
    public let role: MessageRole
    public let content: String
    public let name: String?
    public let toolCallId: String?
    public let toolCalls: [ToolCall]?

    public init(
        role: MessageRole,
        content: String,
        name: String? = nil,
        toolCallId: String? = nil,
        toolCalls: [ToolCall]? = nil
    ) {
        self.role = role
        self.content = content
        self.name = name
        self.toolCallId = toolCallId
        self.toolCalls = toolCalls
    }
}

public struct ToolCall: Codable, Sendable, Identifiable {
    public let id: String
    public let type: String
    public let function: ToolCallFunction

    public init(id: String, type: String = "function", function: ToolCallFunction) {
        self.id = id
        self.type = type
        self.function = function
    }
}

public struct ToolCallFunction: Codable, Sendable {
    public let name: String
    public let arguments: String

    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

public struct ToolDefinition: Codable, Sendable {
    public let type: String
    public let function: ToolFunction

    public init(type: String = "function", function: ToolFunction) {
        self.type = type
        self.function = function
    }
}

public struct ToolFunction: Codable, Sendable {
    public let name: String
    public let description: String
    public let parameters: ToolParameters

    public init(name: String, description: String, parameters: ToolParameters) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

public struct ToolParameters: Codable, Sendable {
    public let type: String
    public let properties: [String: ToolProperty]
    public let required: [String]?
    public let additionalProperties: Bool?

    public init(
        type: String = "object",
        properties: [String: ToolProperty],
        required: [String]? = nil,
        additionalProperties: Bool? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.additionalProperties = additionalProperties
    }
}

public struct ToolProperty: Codable, Sendable {
    public let type: String
    public let description: String?
    public let enumValues: [String]?

    public init(type: String, description: String? = nil, enumValues: [String]? = nil) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
    }

    private enum CodingKeys: String, CodingKey {
        case type, description
        case enumValues = "enum"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        enumValues = try container.decodeIfPresent([String].self, forKey: .enumValues)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(enumValues, forKey: .enumValues)
    }
}

public struct ChatResponse: Sendable {
    public let content: String
    public let toolCalls: [ToolCall]?
    public let finishReason: FinishReason
    public let usage: TokenUsage?

    public init(
        content: String,
        toolCalls: [ToolCall]? = nil,
        finishReason: FinishReason = .stop,
        usage: TokenUsage? = nil
    ) {
        self.content = content
        self.toolCalls = toolCalls
        self.finishReason = finishReason
        self.usage = usage
    }
}

public enum FinishReason: String, Codable, Sendable {
    case stop
    case length
    case toolCalls = "tool_calls"
    case contentFiltered = "content_filter"
    case error
}

public struct TokenUsage: Codable, Sendable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int

    public init(promptTokens: Int, completionTokens: Int, totalTokens: Int) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}

public struct GenerationConfig: Sendable {
    public var temperature: Double?
    public var topP: Double?
    public var maxTokens: Int?
    public var stopSequences: [String]?
    public var presencePenalty: Double?
    public var frequencyPenalty: Double?
    public var seed: Int?

    public init(
        temperature: Double? = nil,
        topP: Double? = nil,
        maxTokens: Int? = nil,
        stopSequences: [String]? = nil,
        presencePenalty: Double? = nil,
        frequencyPenalty: Double? = nil,
        seed: Int? = nil
    ) {
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.stopSequences = stopSequences
        self.presencePenalty = presencePenalty
        self.frequencyPenalty = frequencyPenalty
        self.seed = seed
    }
}

public protocol LLMEngineProtocol: Sendable {
    var modelName: String { get }

    func chat(messages: [ChatMessage], config: GenerationConfig?) async throws -> ChatResponse

    func chatWithTools(
        messages: [ChatMessage],
        tools: [ToolDefinition],
        config: GenerationConfig?
    ) async throws -> ChatResponse

    var supportedTools: [ToolDefinition] { get }
}
