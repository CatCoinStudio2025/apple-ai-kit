import Foundation
import FoundationModels
import LLMEngine

@available(macOS 26.0, iOS 26.0, *)
public final class AppleFoundationEngine: LLMEngineProtocol {
    private let model: SystemLanguageModel
    private let session: LanguageModelSession

    public var modelName: String { "AppleFoundationModel" }

    public var supportedTools: [ToolDefinition] { [] }

    public init() throws {
        self.model = SystemLanguageModel.default
        guard model.availability == .available else {
            throw LLMEngineError.unsupportedPlatform
        }
        self.session = LanguageModelSession(model: model)
    }

    public func chat(messages: [ChatMessage], config: GenerationConfig?) async throws -> ChatResponse {
        let prompt = buildPrompt(from: messages, tools: nil)
        let response = try await session.respond(to: prompt)
        return ChatResponse(
            content: response.content,
            toolCalls: nil,
            finishReason: .stop,
            usage: nil
        )
    }

    public func chatWithTools(
        messages: [ChatMessage],
        tools: [ToolDefinition],
        config: GenerationConfig?
    ) async throws -> ChatResponse {
        let prompt = buildPrompt(from: messages, tools: tools)
        let response = try await session.respond(to: prompt)
        let toolCalls = parseToolCalls(from: response.content)
        return ChatResponse(
            content: extractContent(from: response.content),
            toolCalls: toolCalls,
            finishReason: toolCalls.isEmpty ? .stop : .toolCalls,
            usage: nil
        )
    }

    private func buildPrompt(from messages: [ChatMessage], tools: [ToolDefinition]?) -> String {
        var prompt = ""

        if let tools = tools, !tools.isEmpty {
            prompt += "You have access to the following tools:\n"
            for tool in tools {
                prompt += "- \(tool.function.name): \(tool.function.description)\n"
                prompt += "  Parameters: \(describeParameters(tool.function.parameters))\n"
            }
            prompt += "\n"
        }

        for message in messages {
            switch message.role {
            case .system:
                prompt += "System: \(message.content)\n"
            case .user:
                prompt += "User: \(message.content)\n"
            case .assistant:
                prompt += "Assistant: \(message.content)\n"
            case .tool:
                if let name = message.name {
                    prompt += "Tool (\(name)): \(message.content)\n"
                }
            }
        }

        prompt += "Assistant:"
        return prompt
    }

    private func describeParameters(_ params: ToolParameters) -> String {
        var desc = "{\n"
        for (name, prop) in params.properties {
            var propDesc = "    \(name) (\(prop.type))"
            if let desc = prop.description {
                propDesc += ": \(desc)"
            }
            if let enumVals = prop.enumValues {
                propDesc += ", enum: \(enumVals)"
            }
            desc += propDesc + "\n"
        }
        desc += "}"
        return desc
    }

    private func parseToolCalls(from content: String) -> [ToolCall] {
        let pattern = #"<tool_call>\s*\{.*?"id":\s*"([^"]+)".*?"name":\s*"([^"]+)".*?"arguments":\s*"([^"]+)".*?\}</tool_call>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        let range = NSRange(content.startIndex..., in: content)
        var calls: [ToolCall] = []

        regex.enumerateMatches(in: content, options: [], range: range) { match, _, _ in
            guard let match = match,
                  match.numberOfRanges >= 4,
                  let idRange = Range(match.range(at: 1), in: content),
                  let nameRange = Range(match.range(at: 2), in: content),
                  let argsRange = Range(match.range(at: 3), in: content) else { return }

            let id = String(content[idRange])
            let name = String(content[nameRange])
            let args = String(content[argsRange])

            calls.append(ToolCall(
                id: id,
                function: ToolCallFunction(name: name, arguments: args)
            ))
        }

        return calls
    }

    private func extractContent(from content: String) -> String {
        if let range = content.range(of: "<tool_call>") {
            return String(content[content.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
