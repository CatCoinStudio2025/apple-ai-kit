import Foundation
import NaturalLanguage

public enum SentenceEmbeddingError: Error, Sendable {
    case embeddingFailed
    case emptyText
    case invalidDimension
    case modelNotAvailable
}
