import Foundation

public final class TemplateEngine {
    private let slotFiller: SlotFiller
    private var templates: [String: String] = [:]

    public init(slotFiller: SlotFiller = SlotFiller()) {
        self.slotFiller = slotFiller
        loadDefaultTemplates()
    }

    public func registerTemplate(_ key: String, template: String) {
        templates[key] = template
    }

    public func render(_ key: String, data: [String: Any]) -> String {
        guard let template = templates[key] else {
            return "Template not found: \(key)"
        }
        return slotFiller.fill(template: template, with: data)
    }

    private func loadDefaultTemplates() {
        templates = [
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
