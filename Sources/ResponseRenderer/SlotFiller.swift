import Foundation

public final class SlotFiller: @unchecked Sendable {
    public init() {}

    public func fill(template: String, with data: [String: Any]) -> String {
        var result = template
        var current = ""
        var inSlot = false

        for char in template {
            if char == "{" {
                if !current.isEmpty {
                    result = result.replacingOccurrences(of: "{\(current)}", with: current)
                    current = ""
                }
                inSlot = true
            } else if char == "}" && inSlot {
                if !current.isEmpty {
                    if let value = data[current] {
                        result = result.replacingOccurrences(of: "{\(current)}", with: String(describing: value))
                    }
                    current = ""
                }
                inSlot = false
            } else if inSlot {
                current.append(char)
            }
        }

        if !current.isEmpty {
            result = result.replacingOccurrences(of: "{\(current)}", with: current)
        }

        return result
    }
}
