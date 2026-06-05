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

    /// Full-text search using FTS5 MATCH query.
    func search(query: String, limit: Int = 50) throws -> [ClipboardItem] {
        guard let dbQueue = dbQueue else {
            throw RepositoryError.databaseNotReady
        }

        return try dbQueue.read { db in
            try ClipboardItem
                .filter(sql: """
                    id IN (
                        SELECT rowid FROM clipboard_items_fts
                        WHERE clipboard_items_fts MATCH ?
                    )
                    """,
                    arguments: [query]
                )
                .order(Column("created_at").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    // MARK: - Update

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
    func cleanup(retentionDays: Int, maxStorageMB: Int) throws -> Int {
        guard let dbQueue = dbQueue else {
            throw RepositoryError.databaseNotReady
        }

        return try dbQueue.write { db in
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date())!

            // Delete expired non-pinned items
            let deleted = try ClipboardItem
                .filter(Column("created_at") < cutoffDate)
                .filter(Column("is_pinned") == 0)
                .deleteAll(db)

            logger.info("Cleanup: deleted \(deleted) expired items")
            return deleted
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
