import Foundation

public enum Intent: String, CaseIterable, Codable, Sendable {
    case createOrder
    case checkOrder
    case cancelOrder
    case getProductInfo
    case searchProducts
    case getOrderHistory
    case updateShippingAddress
    case getRecommendations
    case fileComplaint
    case requestRefund
    case unknown

    public var description: String {
        switch self {
        case .createOrder: return "Tạo đơn hàng mới"
        case .checkOrder: return "Kiểm tra trạng thái đơn hàng"
        case .cancelOrder: return "Hủy đơn hàng"
        case .getProductInfo: return "Lấy thông tin sản phẩm"
        case .searchProducts: return "Tìm kiếm sản phẩm"
        case .getOrderHistory: return "Xem lịch sử đơn hàng"
        case .updateShippingAddress: return "Cập nhật địa chỉ giao hàng"
        case .getRecommendations: return "Nhận gợi ý sản phẩm"
        case .fileComplaint: return "Khiếu nại"
        case .requestRefund: return "Yêu cầu hoàn tiền"
        case .unknown: return "Không xác định"
        }
    }
}
