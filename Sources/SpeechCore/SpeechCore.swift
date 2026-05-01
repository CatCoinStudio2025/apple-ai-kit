import Foundation
import Speech

public struct SpeechCore {
    public let recognitionService: SpeechRecognitionService

    public init(recognitionService: SpeechRecognitionService) {
        self.recognitionService = recognitionService
    }
}
