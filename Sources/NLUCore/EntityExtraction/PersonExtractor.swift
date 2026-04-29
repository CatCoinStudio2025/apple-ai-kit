import Foundation
import NaturalLanguage

public final class PersonExtractor: EntityExtractorProtocol, @unchecked Sendable {
    private let tagger: NLTagger

    public init() {
        self.tagger = NLTagger(tagSchemes: [.nameType])
    }

    public func extract(from text: String) async throws -> [Entity] {
        var entities: [Entity] = []

        tagger.string = text
        let range = text.startIndex..<text.endIndex

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]

        tagger.enumerateTags(in: range, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if tag == .personalName {
                let value = String(text[tokenRange])
                entities.append(Entity(
                    type: .personName,
                    value: value,
                    normalizedValue: value
                ))
            }
            return true
        }

        return entities
    }

    public func extract(from text: String, types: [EntityType]) async throws -> [Entity] {
        guard types.contains(.personName) else { return [] }
        return try await extract(from: text)
    }
}
