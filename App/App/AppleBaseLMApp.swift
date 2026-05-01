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

@available(macOS 26.0, *)
final class AppleBaseLMApp: @unchecked Sendable {
    let nluCore: NLUCore
    let toolRouter: ToolRouter
    let responseEngine: ResponseEngine
    let llm: (any LLMEngineProtocol)?
    let systemPrompt: String
    let isLLMAvailable: Bool

    private let speechService: SpeechRecognitionService
    private let synthesisService: SpeechSynthesisService
    private let imageAnalysis: ImageAnalysisService

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

        self.speechService = SpeechRecognitionServiceImpl()
        self.synthesisService = SpeechSynthesisServiceImpl()
        self.imageAnalysis = VisionImageAnalysisService()
    }

    func processQuery(_ text: String) async -> String {
        let userLanguage = detectLanguage(from: text)

        do {
            let parsed = try await nluCore.parse(text)
            let toolResult = try await toolRouter.route(parsed)
            let context = nluCore.getContext()

            let responseData = responseEngine.buildResponseData(
                from: parsed,
                toolResult: ToolOutput(data: toolResult.data, message: toolResult.message),
                context: context
            )

            if let llm = llm, isLLMAvailable {
                let llmPrompt = buildPrompt(from: responseData, userLanguage: userLanguage)
                return try await llm.generate(prompt: llmPrompt)
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

    func processQueryWithImage(_ text: String, imageData: Data) async -> String {
        let userLanguage = detectLanguage(from: text)

        let imageDescription: String
        do {
            let result = try await imageAnalysis.analyzeImage(imageData)
            imageDescription = result.combinedDescription
        } catch {
            imageDescription = "[Image analysis failed: \(error.localizedDescription)]"
        }

        let enrichedText = text.isEmpty
            ? "Describe this image: \(imageDescription)"
            : "\(text)\n\nImage context: \(imageDescription)"

        return await processQuery(enrichedText)
    }

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
