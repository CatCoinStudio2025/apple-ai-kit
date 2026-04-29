import Foundation
import NLUCore
import ToolRouter

public final class TextFormatter: ResponseFormatterProtocol, @unchecked Sendable {
    private let templateEngine: TemplateEngine

    public init(templateEngine: TemplateEngine = TemplateEngine()) {
        self.templateEngine = templateEngine
    }

    public func format(_ result: ToolResult) -> String {
        guard result.success else {
            return templateEngine.render("error", data: ["message": result.message])
        }

        let templateKey = intentToTemplateKey(result.intent)

        var data: [String: Any] = result.data ?? [:]
        data["message"] = result.message

        return templateEngine.render(templateKey, data: data)
    }

    private func intentToTemplateKey(_ intent: Intent) -> String {
        switch intent {
        case .createOrder: return "order_created"
        case .checkOrder: return "order_checked"
        case .cancelOrder: return "order_cancelled"
        case .getProductInfo: return "product_info"
        case .searchProducts: return "search_results"
        case .getOrderHistory: return "order_history"
        case .updateShippingAddress: return "address_updated"
        case .getRecommendations: return "recommendations"
        case .fileComplaint: return "complaint_filed"
        case .requestRefund: return "refund_requested"
        case .unknown: return "unknown_intent"
        }
    }
}
