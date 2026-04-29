import Foundation
import NLUCore
import ResponseEngine

public final class TemplateRenderer: ResponseRendererProtocol, @unchecked Sendable {
    private let slotFiller: SlotFiller
    private var templates: [String: String]

    public init() {
        self.slotFiller = SlotFiller()
        self.templates = Self.defaultTemplates()
    }

    public func render(_ data: ResponseData) async throws -> String {
        let templateKey = intentToTemplateKey(data.intent)
        guard let template = templates[templateKey] else {
            return templates["default"] ?? "Cảm ơn bạn."
        }

        var slotData: [String: Any] = [:]

        for entity in data.entities {
            slotData[entity.type.rawValue] = entity.value
        }

        if let resultData = data.toolResult.data {
            for (key, value) in resultData {
                slotData[key] = value
            }
        }

        slotData["message"] = data.toolResult.message

        return slotFiller.fill(template: template, with: slotData)
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

    private static func defaultTemplates() -> [String: String] {
        [
            "order_created": "Đã tạo đơn hàng {orderId} cho {product} với số lượng {quantity}.",
            "order_checked": "Đơn hàng {orderId} đang ở trạng thái: {status}.",
            "order_cancelled": "Đã hủy đơn hàng {orderId}.",
            "product_info": "Sản phẩm {productName} có giá {price} VNĐ.",
            "search_results": "Tìm thấy {count} sản phẩm phù hợp với '{query}'.",
            "order_history": "Bạn có {count} đơn hàng gần đây.",
            "address_updated": "Địa chỉ giao hàng đã được cập nhật thành: {address}.",
            "recommendations": "Gợi ý cho bạn: {products}.",
            "complaint_filed": "Đã ghi nhận khiếu nại của bạn. Mã khiếu nại: {complaintId}.",
            "refund_requested": "Yêu cầu hoàn tiền cho đơn {orderId} đã được tiếp nhận.",
            "error": "Xin lỗi, đã xảy ra lỗi: {message}",
            "unknown_intent": "Xin lỗi, tôi không hiểu ý của bạn. Bạn có thể diễn đạt lại không?",
            "default": "Cảm ơn bạn đã phản hồi."
        ]
    }
}
