import Foundation
import NLUCore
import ResponseEngine

public protocol ResponseRendererProtocol: Sendable {
    func render(_ data: ResponseData) async throws -> String
}
