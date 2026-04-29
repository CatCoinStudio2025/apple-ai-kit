import Foundation
import ToolRouter

public protocol ResponseFormatterProtocol: Sendable {
    func format(_ result: ToolResult) -> String
}
