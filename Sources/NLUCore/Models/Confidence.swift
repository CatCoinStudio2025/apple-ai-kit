import Foundation

public struct Confidence: Sendable {
    public let score: Double
    public let threshold: Double

    public init(score: Double, threshold: Double = 0.7) {
        self.score = score
        self.threshold = threshold
    }

    public var isConfident: Bool {
        score >= threshold
    }

    public var percentageString: String {
        String(format: "%.0f%%", score * 100)
    }
}

public struct ClassificationResult: Sendable {
    public let intent: Intent
    public let confidence: Confidence

    public init(intent: Intent, confidence: Confidence) {
        self.intent = intent
        self.confidence = confidence
    }
}
