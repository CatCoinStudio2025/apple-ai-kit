import Foundation

public enum EntityType: String, Codable, Sendable {
    case productId
    case orderId
    case quantity
    case price
    case date
    case time
    case personName
    case location
    case email
    case phone
    case productCategory
    case color
    case size
    case brand
    case unknown
}

public struct Entity: Codable, Sendable, Identifiable {
    public let id: UUID
    public let type: EntityType
    public let value: String
    public let normalizedValue: String?
    public let range: Range<Int>?

    public init(
        id: UUID = UUID(),
        type: EntityType,
        value: String,
        normalizedValue: String? = nil,
        range: Range<Int>? = nil
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.normalizedValue = normalizedValue
        self.range = range
    }
}
