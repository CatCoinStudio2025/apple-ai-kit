import Foundation

public final class TemplateParser {
    public init() {}

    public func parse(_ template: String) -> [TemplateToken] {
        var tokens: [TemplateToken] = []
        var current = ""
        var inSlot = false

        for char in template {
            if char == "{" {
                if !current.isEmpty {
                    tokens.append(.text(current))
                    current = ""
                }
                inSlot = true
            } else if char == "}" && inSlot {
                if !current.isEmpty {
                    tokens.append(.slot(current))
                    current = ""
                }
                inSlot = false
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            tokens.append(.text(current))
        }

        return tokens
    }
}

public enum TemplateToken: Sendable {
    case text(String)
    case slot(String)
}
