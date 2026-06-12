import Foundation
import GRDB
import os.log
import ServiceManagement

/// Notification posted when settings change, so services can react.
extension Notification.Name {
    static let settingsDidChange = Notification.Name("com.assistant.settingsDidChange")
}

/// ViewModel for the preferences settings view.
///
/// Loads settings from the `app_settings` table on init and provides
/// methods to save changes back. Uses `@Published` properties for SwiftUI binding.
@MainActor
final class SettingsViewModel: ObservableObject {
    let logger = Logger.app
    private let repository = ContentRepository()
    private let exportService = ExportService()

    // MARK: - General Settings

    @Published var retentionDays: Int = 30
    @Published var maxStorageMB: Int = 500
    @Published var ocrEnabled: Bool = true
    @Published var pollInterval: Int = 500
    @Published var launchAtLogin: Bool = true

    /// Current language preference (persisted to UserDefaults AppleLanguages).
    @Published var selectedLanguage: String = {
        if let langs = UserDefaults.standard.stringArray(forKey: "AppleLanguages"),
           let first = langs.first, first.hasPrefix("zh") {
            return "zh-Hans"
        }
        return "en"
    }()

    // MARK: - Data Management

    @Published var databaseSizeMB: Double = 0
    @Published var totalItemCount: Int = 0

    /// Whether an export/import operation is in progress.
    @Published var isExporting: Bool = false
    @Published var isImporting: Bool = false
    @Published var isClearingHistory: Bool = false

    /// Import progress (current item / total items).
    @Published var importProgress: Double = 0

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
        (L10n.localized("settings.polling.500ms"), 500),
        (L10n.localized("settings.polling.1000ms"), 1000),
        (L10n.localized("settings.polling.2000ms"), 2000)
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

            if let val = settings[LegacySettingKey.retentionDays], let intVal = Int(val) {
                retentionDays = intVal
            }
            if let val = settings[LegacySettingKey.maxStorageMB], let intVal = Int(val) {
                maxStorageMB = intVal
            }
            if let val = settings[LegacySettingKey.ocrEnabled] {
                ocrEnabled = val == "1"
            }
            if let val = settings[LegacySettingKey.pollIntervalMs], let intVal = Int(val) {
                pollInterval = intVal
            }

            // Launch-at-login is default-on for Assistant; the persisted setting
            // is the user preference and SMAppService is the current system state.
            if let val = settings[LegacySettingKey.launchAtLoginEnabled] {
                launchAtLogin = val == "1"
            } else {
                launchAtLogin = true
            }

            logger.info("Settings loaded from database")
        } catch {
            logger.error("Failed to load settings: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Save Settings

    /// Save all current settings to the database and notify services.
    func save() async {
        do {
            try repository.updateSetting(key: LegacySettingKey.retentionDays, value: String(retentionDays))
            try repository.updateSetting(key: LegacySettingKey.maxStorageMB, value: String(maxStorageMB))
            try repository.updateSetting(key: LegacySettingKey.ocrEnabled, value: ocrEnabled ? "1" : "0")
            try repository.updateSetting(key: LegacySettingKey.pollIntervalMs, value: String(pollInterval))
            try repository.updateSetting(key: LegacySettingKey.launchAtLoginEnabled, value: launchAtLogin ? "1" : "0")

            // Launch at login
            try setLaunchAtLogin(launchAtLogin)

            // Notify services that settings changed
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)

            logger.info("Settings saved to database")
        } catch {
            logger.error("Failed to save settings: \(error.localizedDescription, privacy: .public)")
            alertTitle = L10n.localized("settings.saveError.title")
            alertMessage = L10n.localized("settings.saveError.message", error.localizedDescription)
            showAlert = true
        }
    }

    // MARK: - Reset to Defaults

    func resetToDefaults() {
        retentionDays = 30
        maxStorageMB = 500
        ocrEnabled = true
        pollInterval = 500
        launchAtLogin = true
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

    // MARK: - JSON Export

    /// Export clipboard history to a JSON file.
    func exportJSON(to url: URL) async {
        isExporting = true
        defer { isExporting = false }

        do {
            try exportService.exportToJSON(to: url)
            let count = totalItemCount
            dataOperationStatus = L10n.localized("settings.export.json.success", count)
            logger.info("Exported \(count) items to JSON: \(url.path, privacy: .public)")
        } catch {
            logger.error("JSON export failed: \(error.localizedDescription, privacy: .public)")
            alertTitle = L10n.localized("settings.exportError.title")
            alertMessage = L10n.localized("settings.exportError.message", error.localizedDescription)
            showAlert = true
        }
    }

    // MARK: - CSV Export

    /// Export clipboard history to a CSV file.
    func exportCSV(to url: URL) async {
        isExporting = true
        defer { isExporting = false }

        do {
            try exportService.exportToCSV(to: url)
            let count = totalItemCount
            dataOperationStatus = L10n.localized("settings.export.csv.success", count)
            logger.info("Exported \(count) items to CSV: \(url.path, privacy: .public)")
        } catch {
            logger.error("CSV export failed: \(error.localizedDescription, privacy: .public)")
            alertTitle = L10n.localized("settings.exportError.title")
            alertMessage = L10n.localized("settings.exportError.message", error.localizedDescription)
            showAlert = true
        }
    }

    // MARK: - Database Export

    /// Export the raw database file.
    func exportDatabase(to url: URL) async {
        isExporting = true
        defer { isExporting = false }

        do {
            try exportService.exportDatabase(to: url)
            dataOperationStatus = L10n.localized("settings.export.db.success")
            logger.info("Database exported to \(url.path, privacy: .public)")
        } catch {
            logger.error("Database export failed: \(error.localizedDescription, privacy: .public)")
            alertTitle = L10n.localized("settings.exportError.title")
            alertMessage = L10n.localized("settings.exportError.message", error.localizedDescription)
            showAlert = true
        }
    }

    // MARK: - JSON Import

    /// Import clipboard history from a JSON file with progress tracking.
    func importJSON(from url: URL) async {
        isImporting = true
        importProgress = 0
        defer {
            isImporting = false
            importProgress = 0
        }

        do {
            let result = try exportService.importFromJSON(from: url) { [weak self] current, total in
                Task { @MainActor in
                    self?.importProgress = Double(current) / Double(total)
                }
            }

            dataOperationStatus = result.summary
            loadDatabaseStats()
            NotificationCenter.default.post(name: .clipboardItemSaved, object: nil)
            logger.info("JSON import complete: \(result.summary, privacy: .public)")
        } catch {
            logger.error("JSON import failed: \(error.localizedDescription, privacy: .public)")
            alertTitle = L10n.localized("settings.importError.title")
            alertMessage = L10n.localized("settings.importError.message", error.localizedDescription)
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
            dataOperationStatus = L10n.localized("settings.clear.success", deleted)
            loadDatabaseStats()
            NotificationCenter.default.post(name: .clipboardItemSaved, object: nil)
            logger.info("Cleared \(deleted) items from history")
        } catch {
            logger.error("Clear history failed: \(error.localizedDescription, privacy: .public)")
            alertTitle = L10n.localized("settings.clearError.title")
            alertMessage = L10n.localized("settings.clearError.message", error.localizedDescription)
            showAlert = true
        }
    }
}
