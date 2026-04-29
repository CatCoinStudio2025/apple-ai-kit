import Foundation

public protocol EntityExtractorProtocol: Sendable {
    func extract(from text: String) async throws -> [Entity]
    func extract(from text: String, types: [EntityType]) async throws -> [Entity]
}
