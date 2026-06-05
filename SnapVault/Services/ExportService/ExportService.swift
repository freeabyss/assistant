import Foundation
import GRDB
import os.log

/// Result of a JSON import operation.
struct ImportResult {
    let imported: Int
    let skipped: Int
    let total: Int

    var summary: String {
        "Imported \(imported) items, skipped \(skipped) duplicates (\(total) total)"
    }
}

/// Errors specific to export/import operations.
enum ExportError: LocalizedError {
    case databaseNotReady
    case exportFailed(String)
    case importFailed(String)
    case invalidFormat(String)
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .databaseNotReady:
            return "Database is not initialized"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .importFailed(let reason):
            return "Import failed: \(reason)"
        case .invalidFormat(let reason):
            return "Invalid format: \(reason)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        }
    }
}

/// Service responsible for data import/export operations.
///
/// Handles three export formats:
/// - JSON: Full data with metadata, suitable for backup/restore
/// - CSV: Text-only fields, suitable for spreadsheet analysis
/// - Database: Raw SQLite file copy, for complete backup
///
/// Also handles JSON import with validation and deduplication.
final class ExportService {
    private let logger = Logger.app
    private let repository = ContentRepository()

    // MARK: - JSON Export

    /// Export clipboard history to a JSON file at the specified URL.
    ///
    /// JSON structure:
    /// ```json
    /// {
    ///   "version": "1.0",
    ///   "exported_at": "2026-06-05T12:00:00Z",
    ///   "item_count": 42,
    ///   "items": [ ... ]
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - items: Items to export. If nil, fetches all items from database.
    ///   - url: Destination file URL.
    /// - Throws: `ExportError` if export fails.
    func exportToJSON(items: [ClipboardItem]? = nil, to url: URL) throws {
        logger.info("Starting JSON export to \(url.path, privacy: .public)")

        let exportItems: [ClipboardItem]
        if let items = items {
            exportItems = items
        } else {
            guard let dbQueue = DatabaseManager.shared.dbQueue else {
                throw ExportError.databaseNotReady
            }
            exportItems = try dbQueue.read { db in
                try ClipboardItem
                    .order(Column("created_at").desc)
                    .fetchAll(db)
            }
        }

        let wrapper = ExportWrapper(
            version: "1.0",
            exportedAt: Date(),
            itemCount: exportItems.count,
            items: exportItems.map { ExportItem(from: $0) }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(wrapper)
        try data.write(to: url, options: .atomic)

        logger.info("JSON export complete: \(exportItems.count) items to \(url.path, privacy: .public)")
    }

    // MARK: - CSV Export

    /// Export clipboard history to a CSV file at the specified URL.
    ///
    /// Fields: id, content_type, text_content, ocr_text, is_pinned, created_at
    /// Uses UTF-8 with BOM for Excel compatibility with Chinese characters.
    /// Properly escapes commas, newlines, and quotes in field values.
    ///
    /// - Parameters:
    ///   - items: Items to export. If nil, fetches all items from database.
    ///   - url: Destination file URL.
    /// - Throws: `ExportError` if export fails.
    func exportToCSV(items: [ClipboardItem]? = nil, to url: URL) throws {
        logger.info("Starting CSV export to \(url.path, privacy: .public)")

        let exportItems: [ClipboardItem]
        if let items = items {
            exportItems = items
        } else {
            guard let dbQueue = DatabaseManager.shared.dbQueue else {
                throw ExportError.databaseNotReady
            }
            exportItems = try dbQueue.read { db in
                try ClipboardItem
                    .order(Column("created_at").desc)
                    .fetchAll(db)
            }
        }

        var csv = ""

        // UTF-8 BOM for Excel compatibility
        csv.append("\u{FEFF}")

        // Header row
        csv.append("id,content_type,text_content,ocr_text,is_pinned,created_at\n")

        // Data rows
        let dateFormatter = ISO8601DateFormatter()
        for item in exportItems {
            let id = item.id.map { String($0) } ?? ""
            let contentType = item.contentType.rawValue
            let textContent = escapeCSVField(item.textContent ?? "")
            let ocrText = escapeCSVField(item.ocrText ?? "")
            let isPinned = item.isPinned ? "1" : "0"
            let createdAt = dateFormatter.string(from: item.createdAt)

            csv.append("\(id),\(contentType),\(textContent),\(ocrText),\(isPinned),\(createdAt)\n")
        }

        guard let data = csv.data(using: .utf8) else {
            throw ExportError.exportFailed("Failed to encode CSV as UTF-8")
        }

        try data.write(to: url, options: .atomic)

        logger.info("CSV export complete: \(exportItems.count) items to \(url.path, privacy: .public)")
    }

    // MARK: - Database Export

    /// Export the raw database file to the specified URL.
    ///
    /// Optionally runs VACUUM before copying to reduce file size.
    ///
    /// - Parameters:
    ///   - url: Destination file URL.
    ///   - vacuum: Whether to run VACUUM before copying (default: true).
    /// - Throws: `ExportError` if export fails.
    func exportDatabase(to url: URL, vacuum: Bool = true) throws {
        logger.info("Starting database export to \(url.path, privacy: .public)")

        guard let dbQueue = DatabaseManager.shared.dbQueue else {
            throw ExportError.databaseNotReady
        }

        // Optionally VACUUM to reduce file size
        if vacuum {
            try dbQueue.write { db in
                try db.execute(sql: "VACUUM")
            }
            logger.info("VACUUM complete before export")
        }

        let sourceURL = DatabaseManager.databaseURL()

        // Remove destination if it exists
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        try FileManager.default.copyItem(at: sourceURL, to: url)

        logger.info("Database export complete to \(url.path, privacy: .public)")
    }

    // MARK: - JSON Import

    /// Import clipboard history from a JSON file.
    ///
    /// Validates the JSON format, checks for required fields, and deduplicates
    /// by content_hash. Returns statistics about the import.
    ///
    /// - Parameters:
    ///   - url: Source file URL.
    ///   - progress: Optional callback for progress updates (current, total).
    /// - Returns: `ImportResult` with import statistics.
    /// - Throws: `ExportError` if import fails.
    func importFromJSON(
        from url: URL,
        progress: ((Int, Int) -> Void)? = nil
    ) throws -> ImportResult {
        logger.info("Starting JSON import from \(url.path, privacy: .public)")

        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try to decode as wrapped format first, fall back to raw array
        let items: [ClipboardItem]
        do {
            let wrapper = try decoder.decode(ExportWrapper.self, from: data)
            items = wrapper.items.map { $0.toClipboardItem() }
        } catch {
            // Try legacy format (raw array of ClipboardItem)
            do {
                items = try decoder.decode([ClipboardItem].self, from: data)
            } catch {
                throw ExportError.invalidFormat("Invalid JSON format: \(error.localizedDescription)")
            }
        }

        guard !items.isEmpty else {
            throw ExportError.invalidFormat("No items found in export file")
        }

        logger.info("Parsed \(items.count) items from import file")

        // Pre-fetch existing hashes for deduplication
        let existingHashes = try fetchExistingHashes()

        var imported = 0
        var skipped = 0

        for (index, var item) in items.enumerated() {
            // Report progress
            progress?(index + 1, items.count)

            // Skip duplicates by content_hash
            if existingHashes.contains(item.contentHash) {
                skipped += 1
                continue
            }

            // Reset id for auto-increment
            item.id = nil

            _ = try repository.save(item)
            imported += 1
        }

        let result = ImportResult(imported: imported, skipped: skipped, total: items.count)
        logger.info("JSON import complete: \(result.summary, privacy: .public)")

        return result
    }

    // MARK: - Helpers

    /// Escape a string value for CSV format.
    ///
    /// - If the value contains commas, newlines, or double quotes, wrap in quotes
    ///   and escape internal quotes by doubling them.
    /// - Truncate very long text to avoid enormous CSV files.
    private func escapeCSVField(_ value: String) -> String {
        // Truncate long text fields (max 1000 chars for CSV)
        let truncated = value.count > 1000 ? String(value.prefix(1000)) + "..." : value

        // Check if escaping is needed
        if truncated.contains(",") || truncated.contains("\n") || truncated.contains("\r") || truncated.contains("\"") {
            // Escape double quotes by doubling them, then wrap in quotes
            let escaped = truncated.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }

        return truncated
    }

    /// Fetch all existing content hashes from the database for deduplication.
    private func fetchExistingHashes() throws -> Set<String> {
        guard let dbQueue = DatabaseManager.shared.dbQueue else {
            throw ExportError.databaseNotReady
        }

        return try dbQueue.read { db in
            let hashes = try String.fetchAll(db,
                sql: "SELECT content_hash FROM clipboard_items"
            )
            return Set(hashes)
        }
    }
}

// MARK: - Export Data Structures

/// Wrapper for JSON export format with metadata.
struct ExportWrapper: Codable {
    let version: String
    let exportedAt: Date
    let itemCount: Int
    let items: [ExportItem]
}

/// Serializable representation of a ClipboardItem for export/import.
///
/// Handles Base64 encoding for image data and omits internal GRDB fields.
struct ExportItem: Codable {
    let contentType: ContentType
    let textContent: String?
    let rtfContent: String?
    let imageData: String?  // Base64 encoded
    let filePath: String?
    let ocrText: String?
    let contentHash: String
    let isPinned: Bool
    let createdAt: Date
    let updatedAt: Date

    /// Create from a ClipboardItem, encoding image data as Base64.
    init(from item: ClipboardItem) {
        self.contentType = item.contentType
        self.textContent = item.textContent
        self.rtfContent = item.rtfContent
        self.imageData = item.imageData?.base64EncodedString()
        self.filePath = item.filePath
        self.ocrText = item.ocrText
        self.contentHash = item.contentHash
        self.isPinned = item.isPinned
        self.createdAt = item.createdAt
        self.updatedAt = item.updatedAt
    }

    /// Convert back to a ClipboardItem, decoding Base64 image data.
    func toClipboardItem() -> ClipboardItem {
        let decodedImageData: Data?
        if let base64 = imageData {
            decodedImageData = Data(base64Encoded: base64)
        } else {
            decodedImageData = nil
        }

        return ClipboardItem(
            contentType: contentType,
            textContent: textContent,
            rtfContent: rtfContent,
            imageData: decodedImageData,
            filePath: filePath,
            ocrText: ocrText,
            contentHash: contentHash,
            isPinned: isPinned,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
