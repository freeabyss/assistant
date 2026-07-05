import Foundation
import os.log

/// Service that periodically cleans up expired clipboard items and enforces storage limits.
///
/// - Runs on app launch and then every hour
/// - Executes on a background thread to avoid blocking the UI
/// - Pinned items are never automatically deleted
final class DataCleanupService {
    private let logger = Logger.database
    private let repository = ContentRepository()

    /// Timer for periodic cleanup (every hour).
    private var timer: Timer?

    /// Whether a cleanup is currently in progress.
    private var isCleaning = false

    // MARK: - Public API

    /// Start the periodic cleanup schedule.
    /// Also runs an immediate cleanup on the current call.
    func start() {
        logger.info("DataCleanupService starting")

        // Run immediate cleanup on launch
        Task.detached(priority: .utility) { [weak self] in
            self?.performCleanup()
        }

        // Schedule hourly cleanup
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task.detached(priority: .utility) {
                self.performCleanup()
            }
        }
    }

    /// Stop the periodic cleanup timer.
    func stop() {
        timer?.invalidate()
        timer = nil
        logger.info("DataCleanupService stopped")
    }

    // MARK: - Internal

    /// Perform a full cleanup cycle: read settings, run expiry, run storage limit.
    func performCleanup() {
        guard !isCleaning else {
            logger.debug("Cleanup already in progress, skipping")
            return
        }

        isCleaning = true
        defer { isCleaning = false }

        do {
            // Read settings from database
            let retentionDaysStr = try repository.readSetting(key: LegacySettingKey.retentionDays)
            let maxStorageMBStr = try repository.readSetting(key: LegacySettingKey.maxStorageMB)

            let retentionDays = Int(retentionDaysStr ?? LegacySettingKey.defaults[LegacySettingKey.retentionDays]!) ?? 30
            let maxStorageMB = Int(maxStorageMBStr ?? LegacySettingKey.defaults[LegacySettingKey.maxStorageMB]!) ?? 500

            // Run combined cleanup (expiry + storage limit)
            let deleted = try repository.cleanup(retentionDays: retentionDays, maxStorageMB: maxStorageMB)

            if deleted > 0 {
                logger.info("Cleanup complete: removed \(deleted) items (retention=\(retentionDays)d, maxStorage=\(maxStorageMB)MB)")
            } else {
                logger.debug("Cleanup complete: no items to remove")
            }
        } catch {
            logger.error("Cleanup failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
