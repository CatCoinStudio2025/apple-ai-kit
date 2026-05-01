import Foundation
import NLUCore

public final class ToolRegistry: @unchecked Sendable {
    private var tools: [Intent: AnyTool] = [:]
    private let lock = NSLock()

    public init() {}

    public func register<T: ToolProtocol>(_ tool: T) {
        lock.lock()
        defer { lock.unlock() }
        tools[tool.intent] = AnyTool(tool)
    }

    public func get(for intent: Intent) -> AnyTool? {
        lock.lock()
        defer { lock.unlock() }
        return tools[intent]
    }

    public func allIntents() -> [Intent] {
        lock.lock()
        defer { lock.unlock() }
        return Array(tools.keys)
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        tools.removeAll()
    }
}
