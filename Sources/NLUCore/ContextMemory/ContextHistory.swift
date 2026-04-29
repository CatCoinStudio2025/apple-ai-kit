import Foundation

public struct ContextEntry: Codable, Sendable {
    public let intent: Intent
    public let entities: [Entity]
    public let query: String
    public let timestamp: Date

    public init(intent: Intent, entities: [Entity], query: String, timestamp: Date = Date()) {
        self.intent = intent
        self.entities = entities
        self.query = query
        self.timestamp = timestamp
    }
}

public final class ContextHistory: @unchecked Sendable {
    private var entries: [ContextEntry]
    private let maxEntries: Int

    public init(maxEntries: Int = 10) {
        self.entries = []
        self.maxEntries = maxEntries
    }

    public func add(_ entry: ContextEntry) {
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst()
        }
    }

    public func getRecentEntries(_ count: Int) -> [ContextEntry] {
        Array(entries.suffix(count))
    }

    public func getAll() -> [ContextEntry] {
        entries
    }

    public func clear() {
        entries.removeAll()
    }

    public func count() -> Int {
        entries.count
    }
}
