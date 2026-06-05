import Cocoa
import SwiftUI
import os.log

/// AppKit lifecycle delegate, bridges AppKit-specific setup that SwiftUI cannot handle.
class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger.app

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("SnapVault launching")

        // Initialize database
        do {
            try DatabaseManager.shared.setup()
            logger.info("Database initialized successfully")
        } catch {
            logger.error("Database initialization failed: \(error.localizedDescription, privacy: .public)")
        }

        // Ensure Application Support directory exists
        createApplicationSupportDirectory()

        logger.info("SnapVault launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("SnapVault terminating")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - Private

    private func createApplicationSupportDirectory() {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let appDir = appSupport.appendingPathComponent("SnapVault")
        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
            logger.debug("Created Application Support directory at \(appDir.path, privacy: .public)")
        }
    }
}
