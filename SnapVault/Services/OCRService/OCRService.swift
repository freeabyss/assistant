import Foundation
import Vision
import os.log

/// Result of an OCR text recognition operation.
struct OCRResult {
    let text: String
    let confidence: Float
    let blocks: [TextBlock]
}

/// A single recognized text block.
struct TextBlock {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

/// Protocol for OCR operations.
protocol OCRServiceProtocol {
    func recognizeText(from imageData: Data, languages: [String]) async throws -> OCRResult
}

/// OCR service using Vision framework's VNRecognizeTextRequest.
/// Implementation will be completed in US-006.
final class OCRService: OCRServiceProtocol {
    private let logger = Logger.ocr

    func recognizeText(from imageData: Data, languages: [String] = ["en-US", "zh-Hans"]) async throws -> OCRResult {
        logger.info("OCRService.recognizeText() called - not yet fully implemented")
        // Placeholder - will be implemented in US-006
        return OCRResult(text: "", confidence: 0, blocks: [])
    }
}
