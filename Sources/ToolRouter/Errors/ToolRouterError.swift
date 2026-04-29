import Foundation
import NLUCore

public enum ToolRouterError: Error, Sendable {
    case toolNotFound(Intent)
    case invalidInput
    case executionFailed(String)
    case registryEmpty
}
