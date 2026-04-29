import Foundation

public final class SlotFiller {
    public init() {}

    public func fill(template: String, with data: [String: Any]) -> String {
        let parser = TemplateParser()
        let tokens = parser.parse(template)

        var result = ""

        for token in tokens {
            switch token {
            case .text(let text):
                result += text
            case .slot(let slotName):
                if let value = data[slotName] {
                    result += String(describing: value)
                } else {
                    result += "{\(slotName)}"
                }
            }
        }

        return result
    }
}
