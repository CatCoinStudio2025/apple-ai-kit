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
