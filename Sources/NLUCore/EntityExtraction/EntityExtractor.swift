import Foundation
import NaturalLanguage

public final class EntityExtractor: EntityExtractorProtocol {
    private let extractors: [EntityExtractorProtocol]

    public init() {
        self.extractors = [
            QuantityExtractor(),
            DateExtractor(),
            PersonExtractor()
        ]
    }

    public func extract(from text: String) async throws -> [Entity] {
        var allEntities: [Entity] = []

        for extractor in extractors {
            let entities = try await extractor.extract(from: text)
            allEntities.append(contentsOf: entities)
        }

        return extractProductAndOrderIds(from: text) + allEntities
    }

    public func extract(from text: String, types: [EntityType]) async throws -> [Entity] {
        let allEntities = try await extract(from: text)
        return allEntities.filter { types.contains($0.type) }
    }

    private func extractProductAndOrderIds(from text: String) -> [Entity] {
        var entities: [Entity] = []

        let productPattern = #"SP[0-9]{4,}"#
        let orderPattern = #"DH[0-9]{4,}"#

        if let regex = try? NSRegularExpression(pattern: productPattern) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)
            for match in matches {
                if let swiftRange = Range(match.range, in: text) {
                    let value = String(text[swiftRange])
                    entities.append(Entity(type: .productId, value: value, normalizedValue: value))
                }
            }
        }

        if let regex = try? NSRegularExpression(pattern: orderPattern) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)
            for match in matches {
                if let swiftRange = Range(match.range, in: text) {
                    let value = String(text[swiftRange])
                    entities.append(Entity(type: .orderId, value: value, normalizedValue: value))
                }
            }
        }

        return entities
    }
}
