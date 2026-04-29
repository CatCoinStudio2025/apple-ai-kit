import Foundation

public protocol ContextMemoryProtocol: Sendable {
    func save(_ intent: Intent, entities: [Entity], query: String)
    func getPreviousContext() -> ConversationContext?
    func getRecentContexts(_ count: Int) -> [ConversationContext]
    func clear()
}

public final class ContextMemory: ContextMemoryProtocol, @unchecked Sendable {
    private let history: ContextHistory
    private let lock = NSLock()

    public init(maxHistory: Int = 10) {
        self.history = ContextHistory(maxEntries: maxHistory)
    }

    public func save(_ intent: Intent, entities: [Entity], query: String) {
        lock.lock()
        defer { lock.unlock() }

        let entry = ContextEntry(intent: intent, entities: entities, query: query)
        history.add(entry)
    }

    public func getPreviousContext() -> ConversationContext? {
        lock.lock()
        defer { lock.unlock() }

        guard let lastEntry = history.getRecentEntries(1).first else {
            return nil
        }

        let previousEntries = history.getRecentEntries(2)
        let previousEntry = previousEntries.count > 1 ? previousEntries[0] : nil

        return ConversationContext(
            previousIntent: previousEntry?.intent,
            previousEntities: previousEntry?.entities ?? [],
            previousQuery: previousEntry?.query,
            timestamp: lastEntry.timestamp
        )
    }

    public func getRecentContexts(_ count: Int) -> [ConversationContext] {
        lock.lock()
        defer { lock.unlock() }

        let recentEntries = history.getRecentEntries(count)
        return recentEntries.enumerated().map { index, entry in
            let earlierEntry = index + 1 < recentEntries.count ? recentEntries[index + 1] : nil
            return ConversationContext(
                previousIntent: earlierEntry?.intent,
                previousEntities: earlierEntry?.entities ?? [],
                previousQuery: earlierEntry?.query,
                timestamp: entry.timestamp
            )
        }
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        history.clear()
    }
}
