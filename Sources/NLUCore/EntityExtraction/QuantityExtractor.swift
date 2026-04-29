import Foundation
import NaturalLanguage

public final class QuantityExtractor: EntityExtractorProtocol, @unchecked Sendable {
    private let numberTagger = NLTagger(tagSchemes: [.nameTypeOrLexicalClass])

    public func extract(from text: String) async throws -> [Entity] {
        var entities: [Entity] = []
        let numberWords = extractNumberWords(from: text)
        entities.append(contentsOf: numberWords)

        let digitNumbers = extractDigitNumbers(from: text)
        entities.append(contentsOf: digitNumbers)

        return entities
    }

    public func extract(from text: String, types: [EntityType]) async throws -> [Entity] {
        guard types.contains(.quantity) else { return [] }
        return try await extract(from: text)
    }

    private func extractNumberWords(from text: String) -> [Entity] {
        var entities: [Entity] = []

        let numberWordMap: [String: String] = [
            "một": "1", "hai": "2", "ba": "3", "bốn": "4",
            "năm": "5", "sáu": "6", "bảy": "7", "tám": "8", "chín": "9",
            "mười": "10", "chục": "10", "trăm": "100"
        ]

        let lowercased = text.lowercased()

        for (word, number) in numberWordMap {
            if let range = lowercased.range(of: word) {
                entities.append(Entity(
                    type: .quantity,
                    value: word,
                    normalizedValue: number,
                    range: range.lowerBound.utf16Offset(in: text)..<range.upperBound.utf16Offset(in: text)
                ))
            }
        }

        return entities
    }

    private func extractDigitNumbers(from text: String) -> [Entity] {
        var entities: [Entity] = []

        let pattern = #"\b(\d+)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        for match in matches {
            if let swiftRange = Range(match.range(at: 1), in: text) {
                let value = String(text[swiftRange])
                if let number = Int(value), number > 0 && number < 1000 {
                    entities.append(Entity(
                        type: .quantity,
                        value: value,
                        normalizedValue: value
                    ))
                }
            }
        }

        return entities
    }
}
