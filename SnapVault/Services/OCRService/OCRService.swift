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

/// Minimum image dimension (width or height) in pixels for OCR processing.
/// Images smaller than this are skipped to avoid meaningless recognition on icons.
private let kMinImageDimension: CGFloat = 50

/// Minimum confidence threshold for text block acceptance.
private let kMinConfidence: Float = 0.5

/// OCR service using Vision framework's VNRecognizeTextRequest.
///
/// Supports Chinese and English mixed recognition with accurate mode.
/// Filters out low-confidence results and skips images that are too small.
final class OCRService: OCRServiceProtocol {
    private let logger = Logger.ocr

    func recognizeText(
        from imageData: Data,
        languages: [String] = ["zh-Hans", "en"]
    ) async throws -> OCRResult {
        logger.info("OCR started, image data size: \(imageData.count) bytes")

        // Validate image data and check dimensions.
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            logger.error("Failed to decode image data")
            throw SnapVaultError.ocrFailed(reason: "Unable to decode image data")
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        guard width >= kMinImageDimension && height >= kMinImageDimension else {
            logger.info("Image too small for OCR (\(width)x\(height)), skipping")
            return OCRResult(text: "", confidence: 0, blocks: [])
        }

        // Run recognition on a background thread (Vision perform() is synchronous).
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: SnapVaultError.ocrFailed(reason: "OCRService deallocated"))
                    return
                }
                do {
                    let result = try self.performRecognition(on: cgImage, languages: languages)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private

    /// Synchronous Vision recognition. Must be called off the main thread.
    private func performRecognition(on cgImage: CGImage, languages: [String]) throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLanguages = languages
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        // Support both traditional and simplified Chinese + English.
        request.customWords = []

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results else {
            logger.info("OCR returned no observations")
            return OCRResult(text: "", confidence: 0, blocks: [])
        }

        // Process observations: filter by confidence and build text blocks.
        var blocks: [TextBlock] = []
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }

            let confidence = topCandidate.confidence
            if confidence < kMinConfidence {
                logger.debug("Dropping low-confidence block (confidence=\(confidence)): \"\(topCandidate.string, privacy: .public)\"")
                continue
            }

            let block = TextBlock(
                text: topCandidate.string,
                confidence: confidence,
                boundingBox: observation.boundingBox
            )
            blocks.append(block)
        }

        // Concatenate all valid text blocks with newlines.
        let fullText = blocks.map(\.text).joined(separator: "\n")
        let avgConfidence: Float
        if blocks.isEmpty {
            avgConfidence = 0
        } else {
            avgConfidence = blocks.map(\.confidence).reduce(0, +) / Float(blocks.count)
        }

        logger.info("OCR completed: \(blocks.count) blocks, avg confidence=\(avgConfidence), text length=\(fullText.count)")

        return OCRResult(
            text: fullText,
            confidence: avgConfidence,
            blocks: blocks
        )
    }
}
