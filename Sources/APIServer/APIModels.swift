import Foundation
import LLMEngine
import NLUCore
import ToolRouter
import ResponseEngine

public struct ChatCompletionRequest: Codable, Sendable {
    public let model: String
    public let messages: [ChatMessage]
    public let tools: [ToolDefinition]?
    public let temperature: Double?
    public let topP: Double?
    public let maxTokens: Int?
    public let stream: Bool?
    public let seed: Int?
    public let stop: String?
    public let presencePenalty: Double?
    public let frequencyPenalty: Double?
    public let user: String?

    private enum CodingKeys: String, CodingKey {
        case model, messages, tools, temperature, topP, maxTokens, stream, seed, stop, presencePenalty, frequencyPenalty, user
    }

    public init(
        model: String,
        messages: [ChatMessage],
        tools: [ToolDefinition]? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        maxTokens: Int? = nil,
        stream: Bool? = nil,
        seed: Int? = nil,
        stop: String? = nil,
        presencePenalty: Double? = nil,
        frequencyPenalty: Double? = nil,
        user: String? = nil
    ) {
        self.model = model
        self.messages = messages
        self.tools = tools
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.stream = stream
        self.seed = seed
        self.stop = stop
        self.presencePenalty = presencePenalty
        self.frequencyPenalty = frequencyPenalty
        self.user = user
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        model = try container.decode(String.self, forKey: .model)
        messages = try container.decode([ChatMessage].self, forKey: .messages)
        tools = try container.decodeIfPresent([ToolDefinition].self, forKey: .tools)
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
        topP = try container.decodeIfPresent(Double.self, forKey: .topP)
        maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxTokens)
        stream = try container.decodeIfPresent(Bool.self, forKey: .stream)
        seed = try container.decodeIfPresent(Int.self, forKey: .seed)
        stop = try container.decodeIfPresent(String.self, forKey: .stop)
        presencePenalty = try container.decodeIfPresent(Double.self, forKey: .presencePenalty)
        frequencyPenalty = try container.decodeIfPresent(Double.self, forKey: .frequencyPenalty)
        user = try container.decodeIfPresent(String.self, forKey: .user)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encodeIfPresent(tools, forKey: .tools)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(topP, forKey: .topP)
        try container.encodeIfPresent(maxTokens, forKey: .maxTokens)
        try container.encodeIfPresent(stream, forKey: .stream)
        try container.encodeIfPresent(seed, forKey: .seed)
        try container.encodeIfPresent(stop, forKey: .stop)
        try container.encodeIfPresent(presencePenalty, forKey: .presencePenalty)
        try container.encodeIfPresent(frequencyPenalty, forKey: .frequencyPenalty)
        try container.encodeIfPresent(user, forKey: .user)
    }
}

public struct ChatCompletionChoice: Codable, Sendable {
    public let index: Int
    public let message: ChatMessage
    public let finishReason: FinishReason?

    public init(index: Int, message: ChatMessage, finishReason: FinishReason?) {
        self.index = index
        self.message = message
        self.finishReason = finishReason
    }
}

public struct ChatCompletionResponse: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int64
    public let model: String
    public let choices: [ChatCompletionChoice]
    public let usage: TokenUsage?
    public let serviceTier: String?

    public init(
        id: String = UUID().uuidString,
        object: String = "chat.completion",
        created: Int64 = Int64(Date().timeIntervalSince1970),
        model: String,
        choices: [ChatCompletionChoice],
        usage: TokenUsage?,
        serviceTier: String? = nil
    ) {
        self.id = id
        self.object = object
        self.created = created
        self.model = model
        self.choices = choices
        self.usage = usage
        self.serviceTier = serviceTier
    }
}

public struct ModelsResponse: Codable, Sendable {
    public let object: String
    public let data: [ModelInfo]

    public init(data: [ModelInfo]) {
        self.object = "list"
        self.data = data
    }
}

public struct ModelInfo: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let ownedBy: String
    public let permission: [String]?
    public let root: String?
    public let parent: String?

    private enum CodingKeys: String, CodingKey {
        case id, object, created, permission, root, parent
        case ownedBy = "owned_by"
    }

    public init(
        id: String,
        object: String = "model",
        created: Int = Int(Date().timeIntervalSince1970),
        ownedBy: String,
        permission: [String]? = nil,
        root: String? = nil,
        parent: String? = nil
    ) {
        self.id = id
        self.object = object
        self.created = created
        self.ownedBy = ownedBy
        self.permission = permission
        self.root = root
        self.parent = parent
    }
}

public enum APIError: Error, LocalizedError, Codable, Sendable {
    case invalidRequest(String)
    case modelNotFound(String)
    case invalidAPIKey
    case rateLimitExceeded
    case serverError(String)
    case methodNotAllowed
    case internalError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidRequest(let msg): return "Invalid request: \(msg)"
        case .modelNotFound(let model): return "Model not found: \(model)"
        case .invalidAPIKey: return "Invalid API key"
        case .rateLimitExceeded: return "Rate limit exceeded"
        case .serverError(let msg): return "Server error: \(msg)"
        case .methodNotAllowed: return "Method not allowed"
        case .internalError(let msg): return "Internal error: \(msg)"
        }
    }
}

public struct ErrorResponse: Codable, Sendable {
    public let error: ErrorDetail

    public init(_ error: APIError) {
        self.error = ErrorDetail(error)
    }
}

public struct ErrorDetail: Codable, Sendable {
    public let message: String
    public let type: String
    public let code: String?

    public init(_ error: APIError) {
        self.message = error.errorDescription ?? "Unknown error"
        switch error {
        case .invalidRequest: self.type = "invalid_request_error"; self.code = "invalid_request"
        case .modelNotFound: self.type = "invalid_request_error"; self.code = "model_not_found"
        case .invalidAPIKey: self.type = "authentication_error"; self.code = "invalid_api_key"
        case .rateLimitExceeded: self.type = "rate_limit_error"; self.code = "rate_limit_exceeded"
        case .serverError: self.type = "server_error"; self.code = "server_error"
        case .methodNotAllowed: self.type = "invalid_request_error"; self.code = "method_not_allowed"
        case .internalError: self.type = "internal_error"; self.code = "internal_error"
        }
    }
}
