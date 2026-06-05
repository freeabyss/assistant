import Foundation
import GRDB

/// Application settings stored as key-value pairs in the database.
struct AppSetting: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "app_settings"

    var key: String
    var value: String
}

/// Well-known setting keys with their default values.
enum SettingKey {
    static let retentionDays = "retention_days"
    static let maxStorageMB = "max_storage_mb"
    static let ocrEnabled = "ocr_enabled"
    static let pollIntervalMs = "poll_interval_ms"
    static let searchProvider = "search_provider"

    /// Default values for each setting.
    static let defaults: [String: String] = [
        retentionDays: "30",
        maxStorageMB: "500",
        ocrEnabled: "1",
        pollIntervalMs: "500",
        searchProvider: "fts"
    ]
}
