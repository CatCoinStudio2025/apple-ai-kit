import Foundation
import NaturalLanguage
import NLUCore
import ToolRouter
import ResponseEngine
import LLMEngine
import LLMEngineApple
import SpeechCore
import AudioCore
import VisionCore
import APIServer

@available(macOS 26.0, *)
final class AppleBaseLMApp: @unchecked Sendable {
    let nluCore: NLUCore
    let toolRouter: ToolRouter
    let responseEngine: ResponseEngine
    let llm: (any LLMEngineProtocol)?
    let systemPrompt: String
    let isLLMAvailable: Bool

    private let conversationManager: ConversationManager
    private let speechService: SpeechRecognitionService
    private let synthesisService: SpeechSynthesisService
    private let imageAnalysis: ImageAnalysisService
    private var server: HTTPServer?

    init(
        nluCore: NLUCore? = nil,
        systemPrompt: String = "You are a helpful AI assistant. Keep responses concise (1-2 sentences), clear, and easy to understand."
    ) {
        self.nluCore = nluCore ?? NLUCore()
        self.toolRouter = ToolRouter()
        self.responseEngine = ResponseEngine()
        self.systemPrompt = systemPrompt

        var engine: (any LLMEngineProtocol)? = nil
        var available = false
        do {
            engine = try LLMEngineApple.AppleFoundationEngine()
            available = true
        } catch {
            print("⚙️ LLM not available: \(error.localizedDescription)")
        }
        self.llm = engine
        self.isLLMAvailable = available

        self.conversationManager = ConversationManager()
        self.speechService = SpeechRecognitionServiceImpl()
        self.synthesisService = SpeechSynthesisServiceImpl()
        self.imageAnalysis = VisionImageAnalysisService()
    }

    // MARK: - Conversation API

    @discardableResult
    func startConversation() -> String {
        conversationManager.startConversation()
    }

    func endConversation(_ id: String) {
        conversationManager.endConversation(id)
    }

    func listConversations() -> [ConversationSession] {
        conversationManager.listConversations()
    }

    // MARK: - Stateless API (no conversation context)

    func processQuery(_ text: String) async -> String {
        await processQueryStateless(text)
    }

    func processQueryWithImage(_ text: String, imageData: Data) async -> String {
        await processQueryStatelessWithImage(text, imageData: imageData)
    }

    // MARK: - Conversation API (with session context)

    func processQuery(conversationId: String, text: String) async -> String {
        guard conversationManager.hasConversation(conversationId),
              let context = conversationManager.getContext(conversationId) else {
            return errorResponse(.fallback, in: detectLanguage(from: text))
        }

        return await processQueryWithContext(text, context: context)
    }

    func processQueryWithImage(conversationId: String, text: String, imageData: Data) async -> String {
        guard conversationManager.hasConversation(conversationId),
              let context = conversationManager.getContext(conversationId) else {
            return await processQueryStatelessWithImage(text, imageData: imageData)
        }

        return await processQueryWithContextAndImage(text, imageData: imageData, context: context)
    }

    // MARK: - Private implementations

    private func processQueryStateless(_ text: String) async -> String {
        let userLanguage = detectLanguage(from: text)

        do {
            let parsed = try await nluCore.parseStateless(text)
            let toolResult = try await toolRouter.route(parsed)

            let responseData = responseEngine.buildResponseData(
                from: parsed,
                toolResult: ToolOutput(data: toolResult.data, message: toolResult.message),
                context: nil
            )

            if let llm = llm, isLLMAvailable {
                let messages = [
                    ChatMessage(role: .system, content: systemPrompt),
                    ChatMessage(role: .user, content: buildPrompt(from: responseData, userLanguage: userLanguage))
                ]
                let response = try await llm.chat(messages: messages, config: nil)
                return response.content
            } else {
                return responseData.toolResult.message
            }
        } catch {
            if isSafetyGuardrailsError(error) {
                return errorResponse(.safetyGuardrails, in: userLanguage)
            }
            return errorResponse(.fallback, in: userLanguage)
        }
    }

    private func processQueryStatelessWithImage(_ text: String, imageData: Data) async -> String {
        let imageDescription = await analyzeImage(imageData)
        let enrichedText = text.isEmpty
            ? "Describe this image: \(imageDescription)"
            : "\(text)\n\nImage context: \(imageDescription)"
        return await processQueryStateless(enrichedText)
    }

    private func processQueryWithContext(_ text: String, context: ContextMemory) async -> String {
        let userLanguage = detectLanguage(from: text)

        do {
            let parsed = try await nluCore.parseWithContext(text, context: context)
            let toolResult = try await toolRouter.route(parsed)
            let prevContext = context.getPreviousContext()

            let responseData = responseEngine.buildResponseData(
                from: parsed,
                toolResult: ToolOutput(data: toolResult.data, message: toolResult.message),
                context: prevContext
            )

            if let llm = llm, isLLMAvailable {
                let messages = [
                    ChatMessage(role: .system, content: systemPrompt),
                    ChatMessage(role: .user, content: buildPrompt(from: responseData, userLanguage: userLanguage))
                ]
                let response = try await llm.chat(messages: messages, config: nil)
                return response.content
            } else {
                return responseData.toolResult.message
            }
        } catch {
            if isSafetyGuardrailsError(error) {
                return errorResponse(.safetyGuardrails, in: userLanguage)
            }
            return errorResponse(.fallback, in: userLanguage)
        }
    }

    private func processQueryWithContextAndImage(_ text: String, imageData: Data, context: ContextMemory) async -> String {
        let imageDescription = await analyzeImage(imageData)
        let enrichedText = text.isEmpty
            ? "Describe this image: \(imageDescription)"
            : "\(text)\n\nImage context: \(imageDescription)"
        return await processQueryWithContext(enrichedText, context: context)
    }

    private func analyzeImage(_ imageData: Data) async -> String {
        do {
            let result = try await imageAnalysis.analyzeImage(imageData)
            return result.combinedDescription
        } catch {
            return "[Image analysis failed: \(error.localizedDescription)]"
        }
    }

    // MARK: - Server Control

    func startServer(host: String = "0.0.0.0", port: Int = 8314, useTLS: Bool = false) async throws {
        guard let llm = llm else {
            throw LLMEngineError.modelNotLoaded
        }
        server = HTTPServer(
            host: host,
            port: port,
            useTLS: useTLS,
            llm: llm,
            nluCore: nluCore,
            toolRouter: toolRouter
        )
        try await server?.start()
    }

    func stopServer() {
        server?.stop()
        server = nil
    }

    var isServerRunning: Bool {
        server?.isRunning ?? false
    }

    // MARK: - Speech

    func recognizeSpeech(audioData: Data) async throws -> String {
        try await speechService.recognize(audioData: audioData)
    }

    func speak(_ text: String, language: String?) {
        Task {
            await synthesisService.speak(text, language: language)
        }
    }

    func speakMultiLanguage(_ text: String) {
        Task {
            await synthesisService.speakMultiLanguage(text)
        }
    }

    func stopSpeaking() {
        Task {
            await synthesisService.stop()
        }
    }

    // MARK: - Helpers

    private func detectLanguage(from text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue ?? "en"
    }

    private func languageName(for code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code) ?? code
    }

    private func errorResponse(_ key: ErrorResponseKey, in language: String) -> String {
        let messages: [String: String]
        switch key {
        case .safetyGuardrails:
            messages = [
                "vi": "Các biện pháp bảo vệ an toàn đã được kích hoạt.",
                "en": "Safety guardrails were triggered."
            ]
        case .fallback:
            messages = [
                "vi": "Xin lỗi, đã xảy ra lỗi. Vui lòng thử lại.",
                "en": "Sorry, an error occurred. Please try again."
            ]
        }
        return messages[language] ?? messages["en"] ?? "An error occurred."
    }

    private enum ErrorResponseKey {
        case safetyGuardrails
        case fallback
    }

    private func isSafetyGuardrailsError(_ error: Error) -> Bool {
        error.localizedDescription.lowercased().contains("safety guardrails were triggered")
    }

    private func buildPrompt(from data: ResponseData, userLanguage: String) -> String {
        let langInstruction: String
        if userLanguage == "vi" {
            langInstruction = "Hãy trả lời bằng tiếng Việt."
        } else if userLanguage == "ja" {
            langInstruction = "Respond in Japanese."
        } else if userLanguage == "ko" {
            langInstruction = "Respond in Korean."
        } else if userLanguage == "zh" {
            langInstruction = "Respond in Chinese."
        } else {
            langInstruction = "Respond in the user's language (\(languageName(for: userLanguage)))."
        }

        var prompt = systemPrompt

        prompt += "\n\n## User Query:\n"
        prompt += data.originalQuery

        if !data.entities.isEmpty {
            prompt += "\n\n## Detected Entities:\n"
            for entity in data.entities {
                prompt += "- \(entity.type.rawValue): \(entity.value)\n"
            }
        }

        prompt += "\n\n## Tool/Response:\n"
        prompt += data.toolResult.message

        if let context = data.context, let prevQuery = context.previousQuery {
            prompt += "\n\n## Conversation History:\n"
            prompt += "Previous query: \(prevQuery)\n"
        }

        prompt += "\n\n## Instruction:\n"
        prompt += langInstruction

        return prompt
    }
}
