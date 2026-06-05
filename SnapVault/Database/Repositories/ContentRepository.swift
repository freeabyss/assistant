import Foundation
import GRDB
import os.log

/// Errors specific to content repository operations.
enum RepositoryError: LocalizedError {
    case databaseNotReady
    case itemNotFound(Int64)
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .databaseNotReady:
            return "Database is not initialized"
        case .itemNotFound(let id):
            return "Item with id \(id) not found"
        case .saveFailed(let reason):
            return "Failed to save item: \(reason)"
        }
    }
}

/// Repository for clipboard item CRUD operations backed by GRDB.
final class ContentRepository {
    private let logger = Logger.database
    private var dbQueue: DatabaseQueue? {
        DatabaseManager.shared.dbQueue
    }

    // MARK: - Save

    /// Save a new clipboard item. Returns the inserted row id.
    func save(_ item: ClipboardItem) throws -> Int64 {
        guard let dbQueue = dbQueue else {
            throw RepositoryError.databaseNotReady
        }

        return try dbQueue.write { db in
            var record = item
            try record.insert(db)
            let id = db.lastInsertedRowID
            logger.debug("Saved clipboard item id=\(id)")
            return id
        }
    }

    // MARK: - Fetch

    /// Fetch a single item by id.
    func fetch(id: Int64) throws -> ClipboardItem? {
        guard let dbQueue = dbQueue else {
            throw RepositoryError.databaseNotReady
        }

        return try dbQueue.read { db in
            try ClipboardItem.fetchOne(db, id: id)
        }
    }

    /// Fetch history with pagination and optional filtering.
    func fetchHistory(
        page: Int = 0,
        pageSize: Int = 50,
        contentType: ContentType? = nil,
        pinnedOnly: Bool = false
    ) throws -> [ClipboardItem] {
        guard let dbQueue = dbQueue else {
            throw RepositoryError.databaseNotReady
        }

        return try dbQueue.read { db in
            var request = ClipboardItem.all()

            if let contentType = contentType {
                request = request.filter(Column("content_type") == contentType.rawValue)
            }

            if pinnedOnly {
                request = request.filter(Column("is_pinned") == 1)
            }

            // Pinned items first, then by created_at descending
            request = request
                .order(Column("is_pinned").desc, Column("created_at").desc)
                .limit(pageSize, offset: page * pageSize)

            return try request.fetchAll(db)
        }
    }

    /// Find a record by content hash (for deduplication).
    func findByHash(_ hash: String) throws -> ClipboardItem? {
        guard let dbQueue = dbQueue else {
            throw RepositoryError.databaseNotReady
        }

        return try dbQueue.read { db in
            try ClipboardItem
                .filter(Column("content_hash") == hash)
                .order(Column("created_at").desc)
                .fetchOne(db)
        }
    }

    // MARK: - Search

    /// Sanitize a user query string for safe use in FTS5 MATCH.
    ///
    /// - Splits by whitespace into segments
    /// - Escapes embedded double-quote characters
    /// - Wraps each segment in double quotes for phrase matching
    /// - Joins segments with AND for multi-keyword search
    ///
    /// Example: "hello world" -> '"hello" AND "world"'
    /// Example: "你好世界" -> '"你好世界"' (single segment, all chars adjacent)
    private static func sanitizeFTS5Query(_ query: String) -> String {
        let segments = query
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { segment -> String in
                // Escape double quotes inside the segment
                let escaped = segment.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escaped)\""
            }

        // Single segment: just the quoted phrase
        // Multiple segments: AND logic (all must match)
        return segments.joined(separator: " AND ")
    }

    /// A structured search result with relevance score and matched field info.
    struct FTS5SearchResult {
        let item: ClipboardItem
        let score: Double
        let matchedField: String
        let snippet: String
    }

    /// Full-text search using FTS5 MATCH query. Returns plain items (legacy interface).
    func search(query: String, limit: Int = 50) throws -> [ClipboardItem] {
        return try searchStructured(query: query, limit: limit).map { $0.item }
    }

    /// Full-text search with bm25 scoring, scope filtering, and snippet extraction.
    ///
    /// - Parameters:
    ///   - query: FTS5 query string (supports AND/OR/NEAR operators)
    ///   - limit: Maximum number of results
    ///   - scope: Search scope filter (all, textOnly, imageOCR)
    /// - Returns: Results sorted by relevance (pinned first, then bm25 score)
    func searchStructured(
        query: String,
        limit: Int = 50,
        scope: SearchScope = .all
    ) throws -> [FTS5SearchResult] {
        guard let dbQueue = dbQueue else {
            throw RepositoryError.databaseNotReady
        }

        // Build FTS5 MATCH query with optional column-specific scope filtering.
        // FTS5 column filter syntax: column_name : query
        //
        // For Chinese text with unicode61 tokenizer, each character is a separate token.
        // We wrap each whitespace-separated segment in double quotes for phrase matching,
        // and join multiple segments with AND for multi-keyword search.
        // Example: "你好 世界" -> '"你好" AND "世界"' (implicit phrase adjacency per segment)
        let sanitized = Self.sanitizeFTS5Query(query)
        let matchQuery: String
        switch scope {
        case .all:
            matchQuery = sanitized
        case .textOnly:
            matchQuery = "text_content : \(sanitized)"
        case .imageOCR:
            matchQuery = "ocr_text : \(sanitized)"
        }

        return try dbQueue.read { db in
            // Use raw SQL for bm25() ranking and snippet() extraction.
            // bm25() returns negative scores (lower = more relevant), we negate for intuitive ordering.
            // snippet() extracts matching text with configurable markers.
            let sql = """
                SELECT
                    ci.*,
                    -bm25(clipboard_items_fts) AS relevance_score,
                    snippet(clipboard_items_fts, 0, '**', '**', '...', 32) AS text_snippet,
                    snippet(clipboard_items_fts, 1, '**', '**', '...', 32) AS ocr_snippet
                FROM clipboard_items_fts
                JOIN clipboard_items ci ON ci.id = clipboard_items_fts.rowid
                WHERE clipboard_items_fts MATCH ?
                ORDER BY ci.is_pinned DESC, relevance_score DESC, ci.created_at DESC
                LIMIT ?
                """

            let rows = try Row.fetchAll(db, sql: sql, arguments: [matchQuery, limit])

            return rows.compactMap { row -> FTS5SearchResult? in
                // Decode the ClipboardItem from the joined row
                guard let item = try? ClipboardItem(row: row) else { return nil }

                let score = row["relevance_score"] as? Double ?? 0.0
                let textSnippet = row["text_snippet"] as? String ?? ""
                let ocrSnippet = row["ocr_snippet"] as? String ?? ""

                // Determine which field matched based on scope and snippet content
                let matchedField: String
                let snippet: String
                switch scope {
                case .textOnly:
                    matchedField = "text_content"
                    snippet = textSnippet
                case .imageOCR:
                    matchedField = "ocr_text"
                    snippet = ocrSnippet
                case .all:
                    // Use the snippet that contains highlight markers
                    if textSnippet.contains("**") {
                        matchedField = "text_content"
                        snippet = textSnippet
                    } else if ocrSnippet.contains("**") {
                        matchedField = "ocr_text"
                        snippet = ocrSnippet
                    } else {
                        matchedField = "text_content"
                        snippet = textSnippet
                    }
                }

                return FTS5SearchResult(
                    item: item,
                    score: score,
                    matchedField: matchedField,
                    snippet: snippet
                )
            }
        }
    }

    // MARK: - Update

    /// Update only the ocr_text field for an item.
    /// The FTS5 sync trigger automatically updates the search index.
    func updateOCRText(id: Int64, ocrText: String) throws {
        guard let dbQueue = dbQueue else {
            throw RepositoryError.databaseNotReady
        }

        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE clipboard_items SET ocr_text = ?, updated_at = ? WHERE id = ?",
                arguments: [ocrText, Date(), id]
            )
            logger.debug("Updated OCR text for item id=\(id), length=\(ocrText.count)")
        }
    }

    /// Toggle pinned state of an item.
    func togglePin(id: Int64) throws {
        guard let dbQueue = dbQueue else {
            throw RepositoryError.databaseNotReady
        }

        try dbQueue.write { db in
            guard var item = try ClipboardItem.fetchOne(db, id: id) else {
                throw RepositoryError.itemNotFound(id)
            }
            item.isPinned.toggle()
            item.updatedAt = Date()
            try item.update(db)
            logger.debug("Toggled pin for item id=\(id), isPinned=\(item.isPinned)")
        }
    }

    // MARK: - Delete

    /// Delete a single item by id.
    func delete(id: Int64) throws {
        guard let dbQueue = dbQueue else {
            throw RepositoryError.databaseNotReady
        }

        try dbQueue.write { db in
            try ClipboardItem.deleteOne(db, id: id)
            logger.debug("Deleted item id=\(id)")
        }
    }

    /// Delete multiple items by ids.
    func delete(ids: [Int64]) throws {
        guard let dbQueue = dbQueue else {
            throw RepositoryError.databaseNotReady
        }

        try dbQueue.write { db in
            for id in ids {
                try ClipboardItem.deleteOne(db, id: id)
            }
            logger.debug("Deleted \(ids.count) items")
        }
    }

    // MARK: - Cleanup

    /// Delete expired non-pinned items. Returns count of deleted items.
    func cleanupExpired(retentionDays: Int) throws -> Int {
        guard let dbQueue = dbQueue else {
            throw RepositoryError.databaseNotReady
        }

        return try dbQueue.write { db in
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date())!

            // Delete expired non-pinned items (pinned items are protected)
            let deleted = try ClipboardItem
                .filter(Column("created_at") < cutoffDate)
                .filter(Column("is_pinned") == 0)
                .deleteAll(db)

            logger.info("Cleanup: deleted \(deleted) expired items (retention=\(retentionDays) days)")
            return deleted
        }
    }

    /// Delete oldest non-pinned items until database size is under the limit.
    /// Returns count of deleted items.
    func cleanupStorage(maxStorageMB: Int) throws -> Int {
        guard let dbQueue = dbQueue else {
            throw RepositoryError.databaseNotReady
        }

        let dbPath = DatabaseManager.databaseURL().path
        let maxBytes = Int64(maxStorageMB) * 1024 * 1024
        var totalDeleted = 0
        let batchSize = 50

        // Loop: check size, delete a batch if over limit, repeat
        while true {
            // Check current DB file size
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath),
                  let fileSize = attrs[.size] as? Int64 else {
                break
            }

            if fileSize <= maxBytes {
                break
            }

            // Delete a batch of oldest non-pinned items
            let deleted = try dbQueue.write { db -> Int in
                let oldestIDs = try Int64.fetchAll(db,
                    sql: "SELECT id FROM clipboard_items WHERE is_pinned = 0 ORDER BY created_at ASC LIMIT ?",
                    arguments: [batchSize]
                )

                guard !oldestIDs.isEmpty else { return 0 }

                for id in oldestIDs {
                    try ClipboardItem.deleteOne(db, id: id)
                }
                return oldestIDs.count
            }

            totalDeleted += deleted

            // If we couldn't delete anything, break to avoid infinite loop
            if deleted == 0 {
                logger.warning("Storage cleanup: no more non-pinned items to delete, but size still exceeds limit")
                break
            }
        }

        if totalDeleted > 0 {
            logger.info("Storage cleanup: deleted \(totalDeleted) items to stay under \(maxStorageMB)MB limit")
        }
        return totalDeleted
    }

    /// Combined cleanup: first remove expired items, then enforce storage limit.
    /// Returns total count of deleted items.
    func cleanup(retentionDays: Int, maxStorageMB: Int) throws -> Int {
        let expired = try cleanupExpired(retentionDays: retentionDays)
        let storage = try cleanupStorage(maxStorageMB: maxStorageMB)
        return expired + storage
    }

    // MARK: - Settings

    /// Read a single setting value from app_settings table.
    func readSetting(key: String) throws -> String? {
        guard let dbQueue = dbQueue else {
            throw RepositoryError.databaseNotReady
        }

        return try dbQueue.read { db in
            try AppSetting.fetchOne(db, id: key)?.value
        }
    }

    // MARK: - Stats

    /// Get storage statistics.
    func getStats() throws -> (totalItems: Int, totalSizeMB: Double, itemsByType: [ContentType: Int]) {
        guard let dbQueue = dbQueue else {
            throw RepositoryError.databaseNotReady
        }

        return try dbQueue.read { db in
            let totalItems = try ClipboardItem.fetchCount(db)

            // Estimate DB file size
            let dbPath = DatabaseManager.databaseURL()
            let attrs = try FileManager.default.attributesOfItem(atPath: dbPath.path)
            let fileSize = (attrs[.size] as? Int64) ?? 0
            let totalSizeMB = Double(fileSize) / (1024 * 1024)

            // Count by type
            var itemsByType: [ContentType: Int] = [:]
            for type in ContentType.allCases {
                let count = try ClipboardItem
                    .filter(Column("content_type") == type.rawValue)
                    .fetchCount(db)
                itemsByType[type] = count
            }

            return (totalItems, totalSizeMB, itemsByType)
        }
    }
}
