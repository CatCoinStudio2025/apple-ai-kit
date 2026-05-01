import Foundation

public struct ConversationSession: Sendable {
    public let id: String
    public let createdAt: Date
    public private(set) var messageCount: Int = 0

    public init(id: String) {
        self.id = id
        self.createdAt = Date()
    }

    public mutating func incrementMessageCount() {
        messageCount += 1
    }
}

public final class ConversationManager: @unchecked Sendable {
    private var sessions: [String: ConversationSession] = [:]
    private var contexts: [String: ContextMemory] = [:]
    private let lock = NSLock()

    public init() {}

    public func startConversation() -> String {
        lock.lock()
        defer { lock.unlock() }

        let id = UUID().uuidString
        sessions[id] = ConversationSession(id: id)
        contexts[id] = ContextMemory(maxHistory: 20)
        return id
    }

    public func getSession(_ id: String) -> ConversationSession? {
        lock.lock()
        defer { lock.unlock() }
        return sessions[id]
    }

    public func getContext(_ id: String) -> ContextMemory? {
        lock.lock()
        defer { lock.unlock() }
        return contexts[id]
    }

    public func endConversation(_ id: String) {
        lock.lock()
        defer { lock.unlock() }
        sessions.removeValue(forKey: id)
        contexts.removeValue(forKey: id)
    }

    public func hasConversation(_ id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return sessions[id] != nil
    }

    public func listConversations() -> [ConversationSession] {
        lock.lock()
        defer { lock.unlock() }
        return Array(sessions.values)
    }

    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        sessions.removeAll()
        contexts.removeAll()
    }
}
