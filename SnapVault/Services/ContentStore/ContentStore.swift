import Foundation
import os.log

/// Notification posted when a new clipboard item is saved.
/// Observers (e.g. ClipboardListViewModel) should call `refresh()` in response.
extension Notification.Name {
    static let clipboardItemSaved = Notification.Name("com.snapvault.clipboardItemSaved")
}

/// High-level content store that coordinates between the clipboard monitor,
/// database repository, and OCR service.
///
/// Responsibilities:
/// 1. Receive `ClipboardEvent` from `ClipboardMonitor`.
/// 2. De-duplicate via `ContentRepository.findByHash` (database-level check).
/// 3. Build a `ClipboardItem` and persist it.
/// 4. For images, run OCR via `OCRService` to extract searchable text.
/// 5. Post `clipboardItemSaved` so the UI can refresh.
final class ContentStore {
    private let logger = Logger.clipboard
    private let repository = ContentRepository()
    private let ocrService = OCRService()

    /// Debounce timer to avoid flooding the UI with rapid refresh notifications.
    private var refreshWorkItem: DispatchWorkItem?

    /// Minimum interval between UI refresh notifications (ms).
    private let refreshDebounceMs: Int = 300

    // MARK: - Public API

    /// Process and persist a new clipboard event.
    ///
    /// - Returns: The database row id of the saved item, or the existing id if duplicate.
    func processEvent(_ event: ClipboardEvent) async throws -> Int64 {
        // Database-level dedup (covers app restarts where in-memory cache is empty).
        if let existing = try repository.findByHash(event.contentHash) {
            logger.debug("Duplicate content detected (DB), hash: \(event.contentHash, privacy: .public)")
            return existing.id!
        }

        // Build the model object.
        let item = ClipboardItem(
            contentType: event.contentType,
            textContent: event.textContent,
            rtfContent: event.contentType == .rtf ? event.textContent : nil,
            imageData: event.imageData,
            filePath: event.fileURLs?.first?.path,
            contentHash: event.contentHash
        )

        let id = try repository.save(item)
        logger.info("Saved new clipboard item: id=\(id), type=\(event.contentType.rawValue, privacy: .public)")

        // Image OCR: recognize text from screenshots/images for searchability.
        if event.contentType == .image, let data = event.imageData {
            await performOCR(imageData: data, itemId: id)
        }

        // Notify the UI (debounced).
        scheduleRefreshNotification()

        return id
    }

    // MARK: - OCR

    /// Run OCR on an image and store the result.
    ///
    /// Checks the `ocr_enabled` setting before processing.
    /// OCR runs on a background thread; results are written back to the database
    /// and automatically synced to the FTS5 index via the UPDATE trigger.
    private func performOCR(imageData: Data, itemId: Int64) async {
        // Check OCR enabled setting.
        guard isOCREnabled() else {
            logger.debug("OCR is disabled, skipping for item \(itemId)")
            return
        }

        do {
            let result = try await ocrService.recognizeText(from: imageData, languages: ["zh-Hans", "en"])
            guard !result.text.isEmpty else {
                logger.debug("OCR returned empty text for item \(itemId)")
                return
            }

            // Update only the ocr_text field. The FTS5 UPDATE trigger
            // automatically syncs the new text to the search index.
            try repository.updateOCRText(id: itemId, ocrText: result.text)
            logger.info("OCR text saved for item \(itemId), length=\(result.text.count)")
        } catch {
            logger.error("OCR failed for item \(itemId): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Check if OCR is enabled in app settings.
    private func isOCREnabled() -> Bool {
        guard let dbQueue = DatabaseManager.shared.dbQueue else {
            return true // Default to enabled if DB not ready
        }
        do {
            return try dbQueue.read { db in
                if let setting = try AppSetting.fetchOne(db, key: SettingKey.ocrEnabled) {
                    return setting.value == "1"
                }
                return true // Default to enabled
            }
        } catch {
            logger.error("Failed to read OCR setting: \(error.localizedDescription)")
            return true
        }
    }

    // MARK: - Refresh Notification

    /// Post a refresh notification, debounced to avoid rapid-fire UI updates.
    private func scheduleRefreshNotification() {
        refreshWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            NotificationCenter.default.post(name: .clipboardItemSaved, object: nil)
            self?.logger.debug("Posted clipboardItemSaved notification")
        }

        refreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(refreshDebounceMs),
            execute: workItem
        )
    }
}
