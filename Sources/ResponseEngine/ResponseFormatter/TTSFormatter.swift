import Foundation
import AVFoundation

public final class TTSFormatter: @unchecked Sendable {
    private let synthesizer: AVSpeechSynthesizer

    public init() {
        self.synthesizer = AVSpeechSynthesizer()
    }

    public func prepareForSpeech(_ text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "vi-VN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        return utterance
    }

    public func speak(_ text: String) {
        let utterance = prepareForSpeech(text)
        synthesizer.speak(utterance)
    }

    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
