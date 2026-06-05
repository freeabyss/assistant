import Foundation
import os.log

/// High-level content store that coordinates between the clipboard monitor,
/// database repository, and OCR service.
/// Implementation will be completed in US-003.
final class ContentStore {
    private let logger = Logger.clipboard
    private let repository = ContentRepository()

    /// Process and save a new clipboard event.
    func processEvent(_ event: ClipboardEvent) async throws -> Int64 {
        // Check for duplicates
        if let existing = try repository.findByHash(event.contentHash) {
            logger.debug("Duplicate content detected, hash: \(event.contentHash, privacy: .public)")
            return existing.id!
        }

        // Create item based on content type
        let item = ClipboardItem(
            contentType: event.contentType,
            textContent: event.textContent,
            imageData: event.imageData,
            contentHash: event.contentHash
        )

        let id = try repository.save(item)
        logger.info("Saved new clipboard item: id=\(id), type=\(event.contentType.rawValue, privacy: .public)")
        return id
    }
}
