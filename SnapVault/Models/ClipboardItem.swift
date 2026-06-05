import Foundation
import GRDB

/// Content type of a clipboard item.
enum ContentType: String, Codable, CaseIterable, Identifiable {
    case text
    case rtf
    case image
    case file

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .rtf: return "Rich Text"
        case .image: return "Image"
        case .file: return "File"
        }
    }

    var iconName: String {
        switch self {
        case .text: return "doc.text"
        case .rtf: return "doc.richtext"
        case .image: return "photo"
        case .file: return "doc"
        }
    }
}

/// Core data model for a clipboard history record.
/// Maps to the `clipboard_items` database table.
struct ClipboardItem: Identifiable, Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "clipboard_items"

    var id: Int64?
    var contentType: ContentType
    var textContent: String?
    var rtfContent: String?
    var imageData: Data?
    var filePath: String?
    var ocrText: String?
    var contentHash: String
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Column Mapping

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id
        case contentType = "content_type"
        case textContent = "text_content"
        case rtfContent = "rtf_content"
        case imageData = "image_data"
        case filePath = "file_path"
        case ocrText = "ocr_text"
        case contentHash = "content_hash"
        case isPinned = "is_pinned"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - GRDB

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    // MARK: - Convenience Initializer

    /// Create a new clipboard item (not yet saved, id is nil).
    init(
        contentType: ContentType,
        textContent: String? = nil,
        rtfContent: String? = nil,
        imageData: Data? = nil,
        filePath: String? = nil,
        ocrText: String? = nil,
        contentHash: String,
        isPinned: Bool = false
    ) {
        self.id = nil
        self.contentType = contentType
        self.textContent = textContent
        self.rtfContent = rtfContent
        self.imageData = imageData
        self.filePath = filePath
        self.ocrText = ocrText
        self.contentHash = contentHash
        self.isPinned = isPinned
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Fetch Requests

    /// FTS5 association for full-text search.
    static let fts = hasOne(ClipboardItemFTS.self)
}

/// FTS5 virtual table record.
struct ClipboardItemFTS: FetchableRecord, PersistableRecord {
    static let databaseTableName = "clipboard_items_fts"

    var rowid: Int64
    var textContent: String?
    var ocrText: String?

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case rowid
        case textContent = "text_content"
        case ocrText = "ocr_text"
    }
}
