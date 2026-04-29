import Foundation
import NaturalLanguage

public final class DateExtractor: EntityExtractorProtocol, @unchecked Sendable {
    private let tagger: NLTagger

    public init() {
        self.tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
    }

    public func extract(from text: String) async throws -> [Entity] {
        var entities: [Entity] = []

        entities.append(contentsOf: extractRelativeDates(from: text))
        entities.append(contentsOf: extractAbsoluteDates(from: text))

        return entities
    }

    public func extract(from text: String, types: [EntityType]) async throws -> [Entity] {
        guard types.contains(.date) else { return [] }
        return try await extract(from: text)
    }

    private func extractRelativeDates(from text: String) -> [Entity] {
        var entities: [Entity] = []

        let relativePatterns: [(String, String)] = [
            ("hôm nay", "today"),
            ("hôm qua", "yesterday"),
            ("ngày mai", "tomorrow"),
            ("tuần này", "this_week"),
            ("tuần sau", "next_week"),
            ("tháng này", "this_month")
        ]

        let lowercased = text.lowercased()

        for (pattern, normalized) in relativePatterns {
            if let range = lowercased.range(of: pattern) {
                entities.append(Entity(
                    type: .date,
                    value: pattern,
                    normalizedValue: normalized,
                    range: range.lowerBound.utf16Offset(in: text)..<range.upperBound.utf16Offset(in: text)
                ))
            }
        }

        return entities
    }

    private func extractAbsoluteDates(from text: String) -> [Entity] {
        var entities: [Entity] = []

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "vi_VN")

        let patterns = [
            ("dd/MM/yyyy", #"\b(\d{1,2}/\d{1,2}/\d{4})\b"#),
            ("dd-MM-yyyy", #"\b(\d{1,2}-\d{1,2}-\d{4})\b"#),
            ("dd MM yyyy", #"\b(\d{1,2}\s+\d{1,2}\s+\d{4})\b"#)
        ]

        for (format, pattern) in patterns {
            dateFormatter.dateFormat = format
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }

            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)

            for match in matches {
                if let swiftRange = Range(match.range(at: 1), in: text) {
                    let value = String(text[swiftRange])
                    if let date = dateFormatter.date(from: value) {
                        let normalized = ISO8601DateFormatter().string(from: date)
                        entities.append(Entity(
                            type: .date,
                            value: value,
                            normalizedValue: normalized
                        ))
                    }
                }
            }
        }

        return entities
    }
}
