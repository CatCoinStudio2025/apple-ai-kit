import Foundation
import AVFoundation
import NaturalLanguage

public enum AudioError: Error, LocalizedError {
    case synthesisFailed(String)
    case audioEngineError(String)
    case voiceNotAvailable

    public var errorDescription: String? {
        switch self {
        case .synthesisFailed(let message):
            return "Synthesis failed: \(message)"
        case .audioEngineError(let message):
            return "Audio engine error: \(message)"
        case .voiceNotAvailable:
            return "Voice not available for requested language"
        }
    }
}

public enum SpeechSynthesisState: Sendable {
    case idle
    case speaking
    case paused
}

public protocol SpeechSynthesisService: Sendable {
    var currentState: SpeechSynthesisState { get }
    func speak(_ text: String, language: String?) async
    func speakMultiLanguage(_ text: String) async
    func stop() async
    func pause() async
    func resume() async
    var availableVoices: [AVSpeechSynthesisVoice] { get }
}

@available(macOS 26.0, *)
public final class SpeechSynthesisServiceImpl: SpeechSynthesisService, @unchecked Sendable {
    private let synthesizer: AVSpeechSynthesizer
    private let voiceMap: [String: AVSpeechSynthesisVoice]
    private var state: SpeechSynthesisState = .idle

    public nonisolated var currentState: SpeechSynthesisState {
        state
    }

    public var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
    }

    public init() {
        self.synthesizer = AVSpeechSynthesizer()
        self.voiceMap = Self.buildVoiceMap()
    }

    public func speak(_ text: String, language: String?) async {
        let voice: AVSpeechSynthesisVoice?
        if let lang = language {
            voice = voiceMap[lang] ?? AVSpeechSynthesisVoice(language: lang)
        } else {
            voice = AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        state = .speaking
        synthesizer.speak(utterance)
    }

    public func speakMultiLanguage(_ text: String) async {
        let segments = segmentByLanguage(text)
        for segment in segments {
            let voice: AVSpeechSynthesisVoice?
            voice = voiceMap[segment.language] ?? AVSpeechSynthesisVoice(language: segment.language)

            let utterance = AVSpeechUtterance(string: segment.text)
            utterance.voice = voice
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.pitchMultiplier = 1.0
            utterance.volume = 1.0

            synthesizer.speak(utterance)
        }
        state = .speaking
    }

    private func segmentByLanguage(_ text: String) -> [LanguageSegment] {
        var segments: [LanguageSegment] = []
        let tagger = NLTagger(tagSchemes: [.language])
        tagger.string = text

        var currentLang = "en"
        var currentText = ""
        var currentRange = text.startIndex..<text.startIndex

        let fullRange = text.startIndex..<text.endIndex
        tagger.enumerateTags(in: fullRange, unit: .word, scheme: .language, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let lang = tag?.rawValue ?? currentLang
            let word = String(text[range])

            if lang != currentLang {
                if !currentText.isEmpty {
                    segments.append(LanguageSegment(language: currentLang, text: currentText.trimmingCharacters(in: .whitespaces)))
                }
                currentLang = lang
                currentText = word
            } else {
                currentText += " " + word
            }
            return true
        }

        if !currentText.isEmpty {
            segments.append(LanguageSegment(language: currentLang, text: currentText.trimmingCharacters(in: .whitespaces)))
        }

        return segments
    }

    private struct LanguageSegment {
        let language: String
        let text: String
    }

    public func stop() async {
        synthesizer.stopSpeaking(at: .immediate)
        state = .idle
    }

    public func pause() async {
        synthesizer.pauseSpeaking(at: .immediate)
        state = .paused
    }

    public func resume() async {
        synthesizer.continueSpeaking()
        state = .speaking
    }

    private static func buildVoiceMap() -> [String: AVSpeechSynthesisVoice] {
        var map: [String: AVSpeechSynthesisVoice] = [:]
        for voice in AVSpeechSynthesisVoice.speechVoices() {
            let code = voice.language
            if map[code] == nil {
                map[code] = voice
            }
        }
        return map
    }
}

public struct AudioCore {
    public let synthesisService: SpeechSynthesisService

    public init(synthesisService: SpeechSynthesisService) {
        self.synthesisService = synthesisService
    }
}
