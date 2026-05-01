import Foundation
import NLUCore

public protocol ToolProtocol: Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable

    var intent: Intent { get }
    var name: String { get }
    var description: String { get }

    func execute(_ input: Input) async throws -> Output
}

public final class AnyTool: @unchecked Sendable {
    public let intent: Intent
    public let name: String
    public let description: String
    private let _execute: @Sendable (Any) async throws -> Any

    public init<T: ToolProtocol>(_ tool: T) {
        self.intent = tool.intent
        self.name = tool.name
        self.description = tool.description
        self._execute = { input in
            guard let typedInput = input as? T.Input else {
                throw ToolRouterError.executionFailed("Invalid input type")
            }
            return try await tool.execute(typedInput)
        }
    }

    public func execute(_ input: Any) async throws -> Any {
        try await _execute(input)
    }
}
