import Foundation
import Vision
import ImageIO
import CoreGraphics

public enum VisionError: Error, LocalizedError {
    case imageLoadFailed(String)
    case analysisFailed(String)
    case unsupportedImageFormat

    public var errorDescription: String? {
        switch self {
        case .imageLoadFailed(let message):
            return "Failed to load image: \(message)"
        case .analysisFailed(let message):
            return "Vision analysis failed: \(message)"
        case .unsupportedImageFormat:
            return "Unsupported image format"
        }
    }
}

public struct OCRResult: Sendable {
    public let text: String
    public let confidence: Float
    public let boundingBox: CGRect

    public init(text: String, confidence: Float, boundingBox: CGRect) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

public struct FaceDetectionResult: Sendable {
    public let boundingBox: CGRect
    public let confidence: Float
    public let landmarks: [String: CGPoint]?

    public init(boundingBox: CGRect, confidence: Float, landmarks: [String: CGPoint]? = nil) {
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.landmarks = landmarks
    }
}

public struct BarcodeResult: Sendable {
    public let payload: String
    public let symbology: String
    public let boundingBox: CGRect

    public init(payload: String, symbology: String, boundingBox: CGRect) {
        self.payload = payload
        self.symbology = symbology
        self.boundingBox = boundingBox
    }
}

public struct SceneClassification: Sendable {
    public let identifier: String
    public let confidence: Float

    public init(identifier: String, confidence: Float) {
        self.identifier = identifier
        self.confidence = confidence
    }
}

public struct ImageAnalysisResult: Sendable {
    public let ocrTexts: [OCRResult]
    public let faces: [FaceDetectionResult]
    public let barcodes: [BarcodeResult]
    public let sceneClassifications: [SceneClassification]
    public let fullText: String

    public init(
        ocrTexts: [OCRResult] = [],
        faces: [FaceDetectionResult] = [],
        barcodes: [BarcodeResult] = [],
        sceneClassifications: [SceneClassification] = [],
        fullText: String = ""
    ) {
        self.ocrTexts = ocrTexts
        self.faces = faces
        self.barcodes = barcodes
        self.sceneClassifications = sceneClassifications
        self.fullText = fullText
    }

    public var combinedDescription: String {
        var parts: [String] = []
        if !ocrTexts.isEmpty {
            parts.append("Text found: \(ocrTexts.map(\.text).joined(separator: " "))")
        }
        if !faces.isEmpty {
            parts.append("\(faces.count) face(s) detected")
        }
        if !barcodes.isEmpty {
            let codes = barcodes.map { "\($0.symbology): \($0.payload)" }.joined(separator: ", ")
            parts.append("Barcodes: \(codes)")
        }
        if !sceneClassifications.isEmpty {
            let top = sceneClassifications.prefix(3).map { "\($0.identifier)" }.joined(separator: ", ")
            parts.append("Scene: \(top)")
        }
        return parts.isEmpty ? "No objects detected" : parts.joined(separator: "\n")
    }
}

public protocol ImageAnalysisService: Sendable {
    func analyzeImage(_ imageData: Data) async throws -> ImageAnalysisResult
    func recognizeText(in imageData: Data) async throws -> [OCRResult]
    func detectFaces(in imageData: Data) async throws -> [FaceDetectionResult]
    func detectBarcodes(in imageData: Data) async throws -> [BarcodeResult]
    func classifyScene(_ imageData: Data) async throws -> [SceneClassification]
}

private func cgImage(from data: Data) throws -> CGImage {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw VisionError.imageLoadFailed("Could not create CGImage from data")
    }
    return cgImage
}

@available(macOS 26.0, *)
public final class VisionImageAnalysisService: ImageAnalysisService, @unchecked Sendable {
    public init() {}

    public func analyzeImage(_ imageData: Data) async throws -> ImageAnalysisResult {
        let cgImage = try cgImage(from: imageData)

        async let ocrResults = recognizeText(in: imageData)
        async let faceResults = detectFaces(in: imageData)
        async let barcodeResults = detectBarcodes(in: imageData)
        async let sceneResults = classifyScene(imageData)

        let (ocr, faces, barcodes, scene) = try await (ocrResults, faceResults, barcodeResults, sceneResults)
        let fullText = ocr.map(\.text).joined(separator: " ")

        return ImageAnalysisResult(
            ocrTexts: ocr,
            faces: faces,
            barcodes: barcodes,
            sceneClassifications: scene,
            fullText: fullText
        )
    }

    public func recognizeText(in imageData: Data) async throws -> [OCRResult] {
        let cgImage = try cgImage(from: imageData)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: VisionError.analysisFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let results = observations.map { observation in
                    OCRResult(
                        text: observation.topCandidates(1).first?.string ?? "",
                        confidence: observation.confidence,
                        boundingBox: observation.boundingBox
                    )
                }
                continuation.resume(returning: results)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: VisionError.analysisFailed(error.localizedDescription))
            }
        }
    }

    public func detectFaces(in imageData: Data) async throws -> [FaceDetectionResult] {
        let cgImage = try cgImage(from: imageData)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: VisionError.analysisFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNFaceObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let results = observations.map { observation in
                    FaceDetectionResult(
                        boundingBox: observation.boundingBox,
                        confidence: observation.confidence ?? 1.0
                    )
                }
                continuation.resume(returning: results)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: VisionError.analysisFailed(error.localizedDescription))
            }
        }
    }

    public func detectBarcodes(in imageData: Data) async throws -> [BarcodeResult] {
        let cgImage = try cgImage(from: imageData)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: VisionError.analysisFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNBarcodeObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let results = observations.map { observation in
                    BarcodeResult(
                        payload: observation.payloadStringValue ?? "",
                        symbology: observation.symbology.rawValue,
                        boundingBox: observation.boundingBox
                    )
                }
                continuation.resume(returning: results)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: VisionError.analysisFailed(error.localizedDescription))
            }
        }
    }

    public func classifyScene(_ imageData: Data) async throws -> [SceneClassification] {
        let cgImage = try cgImage(from: imageData)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: VisionError.analysisFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let results = observations.prefix(5).map { observation in
                    SceneClassification(
                        identifier: observation.identifier,
                        confidence: observation.confidence
                    )
                }
                continuation.resume(returning: Array(results))
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: VisionError.analysisFailed(error.localizedDescription))
            }
        }
    }
}

public struct VisionCore {
    public let imageAnalysisService: ImageAnalysisService

    public init(imageAnalysisService: ImageAnalysisService) {
        self.imageAnalysisService = imageAnalysisService
    }
}
