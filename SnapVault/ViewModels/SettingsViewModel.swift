import Foundation
import GRDB
import os.log
import ServiceManagement

/// Notification posted when settings change, so services can react.
extension Notification.Name {
    static let settingsDidChange = Notification.Name("com.snapvault.settingsDidChange")
}

/// ViewModel for the preferences settings view.
///
/// Loads settings from the `app_settings` table on init and provides
/// methods to save changes back. Uses `@Published` properties for SwiftUI binding.
@MainActor
final class SettingsViewModel: ObservableObject {
    let logger = Logger.app
    private let repository = ContentRepository()

    // MARK: - General Settings

    @Published var retentionDays: Int = 30
    @Published var maxStorageMB: Int = 500
    @Published var ocrEnabled: Bool = true
    @Published var pollInterval: Int = 500
    @Published var launchAtLogin: Bool = false

    // MARK: - Data Management

    @Published var databaseSizeMB: Double = 0
    @Published var totalItemCount: Int = 0

    /// Whether an export/import operation is in progress.
    @Published var isExporting: Bool = false
    @Published var isImporting: Bool = false
    @Published var isClearingHistory: Bool = false

    /// Alert state for confirmations and messages.
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""

    /// Whether to show the clear history confirmation dialog.
    @Published var showClearHistoryConfirm: Bool = false

    /// Status message for data operations.
    @Published var dataOperationStatus: String?

    // MARK: - Poll Interval Options

    static let pollIntervalOptions: [(label: String, value: Int)] = [
        ("500 ms", 500),
        ("1000 ms", 1000),
        ("2000 ms", 2000)
    ]

    // MARK: - Initialization

    init() {
        loadSettings()
        loadDatabaseStats()
    }

    // MARK: - Load Settings

    /// Load all settings from the database into @Published properties.
    func loadSettings() {
        do {
            let settings = try repository.readAllSettings()

            if let val = settings[SettingKey.retentionDays], let intVal = Int(val) {
                retentionDays = intVal
            }
            if let val = settings[SettingKey.maxStorageMB], let intVal = Int(val) {
                maxStorageMB = intVal
            }
            if let val = settings[SettingKey.ocrEnabled] {
                ocrEnabled = val == "1"
            }
            if let val = settings[SettingKey.pollIntervalMs], let intVal = Int(val) {
                pollInterval = intVal
            }

            // Launch at login state from SMAppService
            launchAtLogin = SMAppService.mainApp.status == .enabled

            logger.info("Settings loaded from database")
        } catch {
            logger.error("Failed to load settings: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Save Settings

    /// Save all current settings to the database and notify services.
    func save() async {
        do {
            try repository.updateSetting(key: SettingKey.retentionDays, value: String(retentionDays))
            try repository.updateSetting(key: SettingKey.maxStorageMB, value: String(maxStorageMB))
            try repository.updateSetting(key: SettingKey.ocrEnabled, value: ocrEnabled ? "1" : "0")
            try repository.updateSetting(key: SettingKey.pollIntervalMs, value: String(pollInterval))

            // Launch at login
            try setLaunchAtLogin(launchAtLogin)

            // Notify services that settings changed
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)

            logger.info("Settings saved to database")
        } catch {
            logger.error("Failed to save settings: \(error.localizedDescription, privacy: .public)")
            alertTitle = "Save Error"
            alertMessage = "Failed to save settings: \(error.localizedDescription)"
            showAlert = true
        }
    }

    // MARK: - Reset to Defaults

    func resetToDefaults() {
        retentionDays = 30
        maxStorageMB = 500
        ocrEnabled = true
        pollInterval = 500
        launchAtLogin = false
    }

    // MARK: - Launch at Login

    private func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
            logger.info("Launch at login enabled")
        } else {
            try SMAppService.mainApp.unregister()
            logger.info("Launch at login disabled")
        }
    }

    // MARK: - Database Statistics

    /// Load database file size and item count.
    func loadDatabaseStats() {
        do {
            let stats = try repository.getStats()
            databaseSizeMB = stats.totalSizeMB
            totalItemCount = stats.totalItems
        } catch {
            logger.error("Failed to load database stats: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Data Export

    /// Export clipboard history to a JSON file.
    func exportData(to url: URL) async {
        isExporting = true
        defer { isExporting = false }

        do {
            let items = try repository.fetchHistory(page: 0, pageSize: 10000)

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            let data = try encoder.encode(items)
            try data.write(to: url)

            dataOperationStatus = "Exported \(items.count) items"
            logger.info("Exported \(items.count) items to \(url.path, privacy: .public)")
        } catch {
            logger.error("Export failed: \(error.localizedDescription, privacy: .public)")
            alertTitle = "Export Error"
            alertMessage = "Failed to export data: \(error.localizedDescription)"
            showAlert = true
        }
    }

    // MARK: - Data Import

    /// Import clipboard history from a JSON file.
    func importData(from url: URL) async {
        isImporting = true
        defer { isImporting = false }

        do {
            let data = try Data(contentsOf: url)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let items = try decoder.decode([ClipboardItem].self, from: data)

            var importedCount = 0
            for var item in items {
                // Reset id so it gets a new auto-increment
                item.id = nil
                // Check for duplicates by hash
                if try repository.findByHash(item.contentHash) != nil {
                    continue
                }
                _ = try repository.save(item)
                importedCount += 1
            }

            dataOperationStatus = "Imported \(importedCount) items"
            loadDatabaseStats()
            NotificationCenter.default.post(name: .clipboardItemSaved, object: nil)
            logger.info("Imported \(importedCount) items from \(url.path, privacy: .public)")
        } catch {
            logger.error("Import failed: \(error.localizedDescription, privacy: .public)")
            alertTitle = "Import Error"
            alertMessage = "Failed to import data: \(error.localizedDescription)"
            showAlert = true
        }
    }

    // MARK: - Clear History

    /// Clear all non-pinned clipboard history (with confirmation).
    func clearHistory() async {
        isClearingHistory = true
        defer { isClearingHistory = false }

        do {
            let deleted = try repository.clearAllHistory()
            dataOperationStatus = "Cleared \(deleted) items"
            loadDatabaseStats()
            NotificationCenter.default.post(name: .clipboardItemSaved, object: nil)
            logger.info("Cleared \(deleted) items from history")
        } catch {
            logger.error("Clear history failed: \(error.localizedDescription, privacy: .public)")
            alertTitle = "Clear Error"
            alertMessage = "Failed to clear history: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
