import Foundation
import NLUCore

public enum ResponseEngineError: Error, Sendable {
    case invalidToolResult
    case renderingFailed(String)
}
