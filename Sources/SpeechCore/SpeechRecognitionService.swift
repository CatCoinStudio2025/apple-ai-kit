import Foundation
import Speech

public enum SpeechRecognitionError: Error, LocalizedError {
    case notAuthorized
    case recognitionFailed(String)
    case audioEngineError(String)
    case noResult

    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized"
        case .recognitionFailed(let message):
            return "Recognition failed: \(message)"
        case .audioEngineError(let message):
            return "Audio engine error: \(message)"
        case .noResult:
            return "No recognition result"
        }
    }
}

public enum SpeechRecognitionAuthorizationStatus {
    case authorized
    case denied
    case notDetermined
}

public protocol SpeechRecognitionService: Sendable {
    func requestAuthorization() async -> SpeechRecognitionAuthorizationStatus
    func recognize(audioURL: URL) async throws -> String
    func recognize(audioData: Data) async throws -> String
    func startLiveRecognition(onResult: @escaping @Sendable (String, Bool) -> Void) async throws
    func stopLiveRecognition() async
    var isAvailable: Bool { get }
    var supportedLocales: [Locale] { get }
}

@available(macOS 26.0, *)
public final class SpeechRecognitionServiceImpl: SpeechRecognitionService, @unchecked Sendable {
    private let speechRecognizer: SFSpeechRecognizer?
    private let audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var liveRecognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var onResultCallback: (@Sendable (String, Bool) -> Void)?

    public var isAvailable: Bool {
        speechRecognizer?.isAvailable ?? false
    }

    public var supportedLocales: [Locale] {
        Array(SFSpeechRecognizer.supportedLocales())
    }

    public init(locale: Locale = Locale.current) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        self.audioEngine = AVAudioEngine()
    }

    public func requestAuthorization() async -> SpeechRecognitionAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .authorized:
                    continuation.resume(returning: .authorized)
                case .denied:
                    continuation.resume(returning: .denied)
                case .notDetermined:
                    continuation.resume(returning: .notDetermined)
                case .restricted:
                    continuation.resume(returning: .denied)
                @unknown default:
                    continuation.resume(returning: .notDetermined)
                }
            }
        }
    }

    public func recognize(audioURL: URL) async throws -> String {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechRecognitionError.recognitionFailed("Recognizer not available")
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false

        if #available(macOS 26.0, *) {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: SpeechRecognitionError.recognitionFailed(error.localizedDescription))
                    return
                }

                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    public func recognize(audioData: Data) async throws -> String {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        try audioData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        return try await recognize(audioURL: tempURL)
    }

    public func startLiveRecognition(onResult: @escaping @Sendable (String, Bool) -> Void) async throws {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechRecognitionError.recognitionFailed("Recognizer not available")
        }

        guard let audioEngine = audioEngine else {
            throw SpeechRecognitionError.audioEngineError("Audio engine not available")
        }

        await stopLiveRecognition()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(macOS 26.0, *) {
            request.requiresOnDeviceRecognition = true
        }

        liveRecognitionRequest = request
        onResultCallback = onResult

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.liveRecognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result = result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                self?.onResultCallback?(text, isFinal)
            }

            if error != nil || result?.isFinal == true {
                Task { [weak self] in
                    await self?.stopLiveRecognition()
                }
            }
        }
    }

    public func stopLiveRecognition() async {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        liveRecognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        liveRecognitionRequest = nil
        onResultCallback = nil
    }

    public func cancel() {
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}
