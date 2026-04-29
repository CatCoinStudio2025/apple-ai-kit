import Foundation

#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

public final class NLModelClassifier: IntentClassifierProtocol, @unchecked Sendable {
    #if canImport(NaturalLanguage)
    private let model: NLModel?
    #else
    private let model: Any? // placeholder when NaturalLanguage is unavailable
    #endif
    private let defaultIntents: [Intent]

    #if canImport(NaturalLanguage)
    public init(model: NLModel? = nil, defaultIntents: [Intent] = Intent.allCases) {
        self.model = model
        self.defaultIntents = defaultIntents
    }
    #else
    public init(model: Any? = nil, defaultIntents: [Intent] = Intent.allCases) {
        self.model = nil // NaturalLanguage not available; ignore passed model
        self.defaultIntents = defaultIntents
    }
    #endif

    public func classify(_ text: String) async throws -> ClassificationResult {
        #if canImport(NaturalLanguage)
        guard let model = model else {
            return fallbackClassify(text)
        }
        #else
        return fallbackClassify(text)
        #endif

        guard let prediction = model.predictedLabel(for: text) else {
            return ClassificationResult(
                intent: .unknown,
                confidence: Confidence(score: 0.0)
            )
        }

        let intent = Intent(rawValue: prediction) ?? .unknown
        let label = model.predictedLabelHypotheses(for: text, maximumCount: 1).first
        let score = label?.value ?? 0.5

        return ClassificationResult(
            intent: intent,
            confidence: Confidence(score: score)
        )
    }

    public func classifyWithOptions(_ text: String, topK: Int) async throws -> [ClassificationResult] {
        #if canImport(NaturalLanguage)
        guard let model = model else {
            return [fallbackClassify(text)]
        }
        #else
        return [fallbackClassify(text)]
        #endif

        let hypotheses = model.predictedLabelHypotheses(for: text, maximumCount: topK)

        return hypotheses.map { (label, score) in
            ClassificationResult(
                intent: Intent(rawValue: label) ?? .unknown,
                confidence: Confidence(score: score)
            )
        }
    }

    private func fallbackClassify(_ text: String) -> ClassificationResult {
        let lowercased = text.lowercased()

        let keywords: [Intent: [String]] = [
            .createOrder: ["tạo", "đặt", "mua", "order"],
            .checkOrder: ["kiểm tra", "xem", "trạng thái", "đơn"],
            .cancelOrder: ["hủy", "cancel"],
            .getProductInfo: ["thông tin", "chi tiết", "san pham"],
            .searchProducts: ["tìm", "kiếm", "search"],
            .getOrderHistory: ["lịch sử", "đơn hàng trước"],
            .updateShippingAddress: ["địa chỉ", "giao hàng"],
            .getRecommendations: ["gợi ý", "recommend"],
            .fileComplaint: ["khiếu nại", "phàn nàn"],
            .requestRefund: ["hoàn tiền", "refund"]
        ]

        var bestMatch: (Intent, Int) = (.unknown, 0)

        for (intent, words) in keywords {
            let matchCount = words.filter { lowercased.contains($0) }.count
            if matchCount > bestMatch.1 {
                bestMatch = (intent, matchCount)
            }
        }

        let confidence = bestMatch.1 > 0 ? Double(bestMatch.1) * 0.25 : 0.1

        return ClassificationResult(
            intent: bestMatch.0,
            confidence: Confidence(score: min(confidence, 0.9))
        )
    }
}
