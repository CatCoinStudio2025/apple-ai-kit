import Foundation
import NLUCore

public final class IntentToolMap: @unchecked Sendable {
    private var map: [Intent: String] = [:]

    public init() {}

    public func register(intent: Intent, toolName: String) {
        map[intent] = toolName
    }

    public func getToolName(for intent: Intent) -> String? {
        map[intent]
    }

    public func allMappings() -> [Intent: String] {
        map
    }
}
