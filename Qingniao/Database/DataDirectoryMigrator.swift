import Foundation
import os.log

/// Migrates the Application Support data directory from the pre-v1.2 brand name
/// (`Assistant/`) to the current brand name (`Qingniao/`).
///
/// Strategy (see doc/architecture/db.md §8.4):
/// - If the new `Qingniao/` directory already exists → no-op (already migrated or
///   fresh install).
/// - Else if the legacy `Assistant/` directory exists → `moveItem` (rename, not
///   copy) the whole directory to `Qingniao/`, then rename the Core Data store
///   files `Assistant.sqlite(-shm/-wal)` → `Qingniao.sqlite(-shm/-wal)`.
/// - If the move fails (permissions / disk) → fallback: `copyItem` the legacy
///   directory to a timestamped `Qingniao-migration-backup-<ISO8601>/` sibling
///   and create a fresh empty `Qingniao/`, so the app can still launch. The
///   failure is surfaced so the caller can alert the user.
///
/// The Core Data lightweight migration (removing `ocrText`) is handled separately
/// by `PersistenceController` via `NSMigratePersistentStoresAutomaticallyOption` +
/// `NSInferMappingModelAutomaticallyOption`.
struct DataDirectoryMigrator {
    /// Outcome of a migration attempt, for logging / user-facing alerts.
    enum Outcome: Equatable {
        /// New directory already present; nothing to do.
        case alreadyMigrated
        /// No legacy directory found; fresh install.
        case freshInstall
        /// Legacy directory successfully moved/renamed to the new location.
        case migrated
        /// Move failed; legacy data was copied to `backupURL` and a fresh empty
        /// directory was created. The user should be informed.
        case fallbackBackup(backupURL: URL, underlying: String)
    }

    let applicationSupportDirectory: URL
    let legacyDirectoryName: String
    let newDirectoryName: String
    let legacyStoreFileName: String
    let newStoreFileName: String
    private let fileManager: FileManager
    private let logger = Logger.database
    private let now: () -> Date

    init(
        applicationSupportDirectory: URL = AssistantFileSystem.applicationSupportDirectory,
        legacyDirectoryName: String = AssistantFileSystem.legacyDirectoryName,
        newDirectoryName: String = AssistantFileSystem.directoryName,
        legacyStoreFileName: String = AssistantFileSystem.legacyStoreFileName,
        newStoreFileName: String = AssistantFileSystem.storeFileName,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.applicationSupportDirectory = applicationSupportDirectory
        self.legacyDirectoryName = legacyDirectoryName
        self.newDirectoryName = newDirectoryName
        self.legacyStoreFileName = legacyStoreFileName
        self.newStoreFileName = newStoreFileName
        self.fileManager = fileManager
        self.now = now
    }

    private var legacyURL: URL {
        applicationSupportDirectory.appendingPathComponent(legacyDirectoryName, isDirectory: true)
    }

    private var newURL: URL {
        applicationSupportDirectory.appendingPathComponent(newDirectoryName, isDirectory: true)
    }

    /// Runs the migration if needed. Never throws: on any move failure it falls
    /// back to a copy-based backup + fresh empty directory so the app still boots.
    @discardableResult
    func migrateIfNeeded() -> Outcome {
        // New directory already exists → already migrated or fresh install path
        // that created it. Treat as done.
        if fileManager.fileExists(atPath: newURL.path) {
            logger.debug("Data directory migration: new directory already present, skipping")
            return .alreadyMigrated
        }

        // No legacy directory → fresh install (nothing to migrate). Directory
        // structure is created later by AssistantFileSystem.ensureDirectoryStructure().
        guard fileManager.fileExists(atPath: legacyURL.path) else {
            logger.info("Data directory migration: no legacy Assistant directory, fresh install")
            return .freshInstall
        }

        // Attempt an atomic move (rename) of the whole directory.
        do {
            try fileManager.moveItem(at: legacyURL, to: newURL)
            renameStoreFiles(in: newURL)
            logger.info("Data directory migrated: \(legacyDirectoryName, privacy: .public) -> \(newDirectoryName, privacy: .public)")
            return .migrated
        } catch {
            logger.error("Data directory move failed: \(error.localizedDescription, privacy: .public); falling back to backup + fresh directory")
            return fallback(after: error)
        }
    }

    /// Renames the Core Data store files inside `directory` from the legacy name
    /// to the new name (including -shm / -wal sidecars).
    private func renameStoreFiles(in directory: URL) {
        let suffixes = ["", "-shm", "-wal"]
        for suffix in suffixes {
            let source = directory.appendingPathComponent(legacyStoreFileName + suffix, isDirectory: false)
            let destination = directory.appendingPathComponent(newStoreFileName + suffix, isDirectory: false)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            do {
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.moveItem(at: source, to: destination)
                logger.debug("Renamed store file \(source.lastPathComponent, privacy: .public) -> \(destination.lastPathComponent, privacy: .public)")
            } catch {
                logger.error("Failed to rename store file \(source.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Fallback when the move fails: copy the legacy directory to a timestamped
    /// backup and create a fresh empty new directory so the app can still launch.
    private func fallback(after moveError: Error) -> Outcome {
        let timestamp = ISO8601DateFormatter.filenameSafe.string(from: now())
        let backupURL = applicationSupportDirectory
            .appendingPathComponent("\(newDirectoryName)-migration-backup-\(timestamp)", isDirectory: true)

        do {
            try fileManager.copyItem(at: legacyURL, to: backupURL)
            logger.info("Legacy data copied to backup: \(backupURL.path, privacy: .public)")
        } catch {
            logger.error("Failed to back up legacy data during fallback: \(error.localizedDescription, privacy: .public)")
        }

        // Ensure a fresh empty new directory exists so Core Data can create a store.
        do {
            try fileManager.createDirectory(at: newURL, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create fresh data directory during fallback: \(error.localizedDescription, privacy: .public)")
        }

        return .fallbackBackup(backupURL: backupURL, underlying: moveError.localizedDescription)
    }
}

private extension ISO8601DateFormatter {
    /// ISO8601 formatter producing a filename-safe timestamp (no colons).
    static let filenameSafe: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withTimeZone]
        // `.withTime` without `.withColonSeparatorInTime` yields HHmmss (no colons),
        // safe for use in a directory name.
        return formatter
    }()
}
