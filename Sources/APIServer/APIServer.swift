import Foundation
import Network
import LLMEngine
import NLUCore
import ToolRouter
import ResponseEngine

public struct APIHTTPRequest {
    public let method: String
    public let path: String
    public let headers: [String: String]
    public let body: Data?

    public init(method: String, path: String, headers: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }
}

public final class HTTPServer: @unchecked Sendable {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.appleaikit.httpserver", qos: .userInitiated)
    private let llm: any LLMEngineProtocol
    private let nluCore: NLUCore
    private let toolRouter: ToolRouter
    private let sessionQueue = DispatchQueue(label: "com.appleaikit.httpserver.session")
    private var sessionHistories: [String: [ChatMessage]] = [:]

    public let host: String
    public let port: Int
    public let useTLS: Bool
    public private(set) var isRunning: Bool = false

    public init(
        host: String = "0.0.0.0",
        port: Int = 8314,
        useTLS: Bool = false,
        llm: any LLMEngineProtocol,
        nluCore: NLUCore = NLUCore(),
        toolRouter: ToolRouter = ToolRouter()
    ) {
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.llm = llm
        self.nluCore = nluCore
        self.toolRouter = toolRouter
    }

    public func start() async throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        if useTLS {
            let tlsOptions = NWProtocolTLS.Options()
            parameters.defaultProtocolStack.applicationProtocols.insert(tlsOptions, at: 0)
        }

        let nwHost: NWEndpoint.Host = host == "0.0.0.0" ? .ipv4(.any) : .init(host)
        listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: UInt16(port))!)

        listener?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.isRunning = true
                print("🚀 Server started on http\(self.useTLS ? "s" : "")://\(self.host):\(self.port)")
            case .failed(let error):
                print("❌ Server failed: \(error)")
            case .cancelled:
                print("🛑 Server cancelled")
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            guard let self = self else { return }
            self.handle(connection: connection)
        }

        listener?.start(queue: queue)
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        print("🛑 Server stopped")
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let self = self, let data = data, !data.isEmpty else {
                connection.cancel()
                return
            }

            guard let request = self.parseRequest(data: data) else {
                self.sendResponse(connection: connection, statusCode: 400, body: "Bad request")
                return
            }

            self.route(connection: connection, request: request)
        }
    }

    private func parseRequest(data: Data) -> APIHTTPRequest? {
        guard let string = String(data: data, encoding: .utf8) else { return nil }
        let lines = string.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }

        let parts = requestLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else { return nil }

        let method = String(parts[0])
        let path = String(parts[1])

        var headers: [String: String] = [:]
        var bodyStartIndex = 0
        for (i, line) in lines.enumerated() {
            if line.isEmpty {
                bodyStartIndex = i + 1
                break
            }
            if i > 0 {
                let headerParts = line.split(separator: ":", maxSplits: 1)
                if headerParts.count == 2 {
                    headers[String(headerParts[0]).trimmingCharacters(in: .whitespaces)] = String(headerParts[1]).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        var body: Data?
        if bodyStartIndex < lines.count {
            let bodyString = lines[bodyStartIndex...].joined(separator: "\r\n")
            body = bodyString.data(using: .utf8)
        }

        return APIHTTPRequest(method: method, path: path, headers: headers, body: body)
    }

    private func route(connection: NWConnection, request: APIHTTPRequest) {
        switch (request.method, request.path) {
        case ("POST", "/v1/chat/completions"):
            handleChatCompletions(connection: connection, request: request)
        case ("GET", "/v1/models"):
            handleModels(connection: connection)
        case ("GET", "/health"):
            sendResponse(connection: connection, statusCode: 200, body: "OK", contentType: "text/plain")
        default:
            sendResponse(connection: connection, statusCode: 404, body: "Not found")
        }
    }

    private func handleChatCompletions(connection: NWConnection, request: APIHTTPRequest) {
        guard let body = request.body,
              let completionRequest = try? JSONDecoder().decode(ChatCompletionRequest.self, from: body) else {
            let error = ErrorResponse(.invalidRequest("Invalid JSON body"))
            sendJSONResponse(connection: connection, response: error, statusCode: 400)
            return
        }

        let sessionId = completionRequest.user ?? "default"

        var messages: [ChatMessage] = []
        sessionQueue.sync {
            messages = sessionHistories[sessionId] ?? []
        }
        messages.append(contentsOf: completionRequest.messages)

        let config = GenerationConfig(
            temperature: completionRequest.temperature,
            topP: completionRequest.topP,
            maxTokens: completionRequest.maxTokens,
            stopSequences: completionRequest.stop.map { [$0] },
            presencePenalty: completionRequest.presencePenalty,
            frequencyPenalty: completionRequest.frequencyPenalty,
            seed: completionRequest.seed
        )

        Task {
            do {
                let chatResponse: ChatResponse
                if let tools = completionRequest.tools, !tools.isEmpty {
                    chatResponse = try await llm.chatWithTools(messages: messages, tools: tools, config: config)
                } else {
                    chatResponse = try await llm.chat(messages: messages, config: config)
                }

                let assistantMessage = ChatMessage(role: .assistant, content: chatResponse.content, toolCalls: chatResponse.toolCalls)

                self.sessionQueue.sync {
                    self.sessionHistories[sessionId] = messages + [assistantMessage]
                }

                let choice = ChatCompletionChoice(index: 0, message: assistantMessage, finishReason: chatResponse.finishReason)
                let response = ChatCompletionResponse(model: completionRequest.model, choices: [choice], usage: chatResponse.usage)

                self.sendJSONResponse(connection: connection, response: response, statusCode: 200)

            } catch {
                let errorResponse = ErrorResponse(.serverError(error.localizedDescription))
                self.sendJSONResponse(connection: connection, response: errorResponse, statusCode: 500)
            }
        }
    }

    private func handleModels(connection: NWConnection) {
        let models = [
            ModelInfo(id: llm.modelName, ownedBy: "apple"),
            ModelInfo(id: "apple-local", ownedBy: "apple")
        ]
        let response = ModelsResponse(data: models)
        sendJSONResponse(connection: connection, response: response, statusCode: 200)
    }

    private func sendResponse(connection: NWConnection, statusCode: Int, body: String, contentType: String = "text/plain") {
        let statusMessage: String
        switch statusCode {
        case 200: statusMessage = "OK"
        case 400: statusMessage = "Bad Request"
        case 404: statusMessage = "Not Found"
        case 500: statusMessage = "Internal Server Error"
        default: statusMessage = "Unknown"
        }

        let headers = "Content-Type: \(contentType)\r\nContent-Length: \(body.utf8.count)"
        let response = "HTTP/1.1 \(statusCode) \(statusMessage)\r\n\(headers)\r\n\r\n\(body)"

        guard let data = response.data(using: .utf8) else { return }
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func sendJSONResponse<T: Encodable>(connection: NWConnection, response: T, statusCode: Int) {
        guard let data = try? JSONEncoder().encode(response) else {
            sendResponse(connection: connection, statusCode: 500, body: "Encoding error")
            return
        }

        let statusMessage: String
        switch statusCode {
        case 200: statusMessage = "OK"
        case 400: statusMessage = "Bad Request"
        case 500: statusMessage = "Internal Server Error"
        default: statusMessage = "Unknown"
        }

        let headers = "Content-Type: application/json\r\nContent-Length: \(data.count)"
        let headerString = "HTTP/1.1 \(statusCode) \(statusMessage)\r\n\(headers)\r\n\r\n"

        guard var responseData = headerString.data(using: .utf8) else { return }
        responseData.append(contentsOf: data)

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
