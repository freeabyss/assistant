import Foundation
import AppKit
import os.log

/// Clipboard change event emitted when new content is detected.
struct ClipboardEvent {
    let contentType: ContentType
    let textContent: String?
    let imageData: Data?
    let fileURLs: [URL]?
    let contentHash: String
    let timestamp: Date
}

/// Protocol for clipboard monitoring.
protocol ClipboardMonitorProtocol {
    /// Stream of clipboard change events.
    var onNewContent: AsyncStream<ClipboardEvent> { get }

    /// Start monitoring the system clipboard.
    func start()

    /// Stop monitoring.
    func stop()

    /// Manually trigger a poll (for testing).
    func pollNow() async
}

/// Monitors the system clipboard for changes by polling `NSPasteboard.changeCount`.
///
/// Polling frequency adapts to app state:
/// - **Foreground (active):** 500ms for near-instant capture.
/// - **Background (resigned):** 2000ms to reduce CPU usage.
///
/// Duplicate content is detected by comparing SHA-256 hashes against
/// the most recent records in `ContentRepository`.
final class ClipboardMonitor: ClipboardMonitorProtocol {
    private let logger = Logger.clipboard
    private let repository = ContentRepository()

    /// Timer interval when the app is in the foreground.
    private let activePollInterval: TimeInterval = 0.5

    /// Timer interval when the app is in the background.
    private let backgroundPollInterval: TimeInterval = 2.0

    /// Tracks the last observed `NSPasteboard.general.changeCount`.
    private var lastChangeCount: Int = 0

    /// Current polling timer.
    private var timer: Timer?

    /// Current polling interval (changes with app activation state).
    private var currentPollInterval: TimeInterval = 0.5

    /// Stores the AsyncStream continuation so we can yield events from the timer callback.
    private var continuation: AsyncStream<ClipboardEvent>.Continuation?

    /// Cached recent hashes for fast in-memory dedup (avoids a DB round-trip on every poll).
    private var recentHashes: Set<String> = []

    /// Observer token for `didBecomeActiveNotification`.
    private var becomeActiveObserver: NSObjectProtocol?

    /// Observer token for `didResignActiveNotification`.
    private var resignActiveObserver: NSObjectProtocol?

    /// Observer token for `settingsDidChange` notification.
    private var settingsChangeObserver: NSObjectProtocol?

    // MARK: - ClipboardMonitorProtocol

    var onNewContent: AsyncStream<ClipboardEvent> {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                self?.logger.debug("ClipboardEvent stream terminated")
            }
        }
    }

    func start() {
        guard timer == nil else {
            logger.warning("ClipboardMonitor already started")
            return
        }

        lastChangeCount = NSPasteboard.general.changeCount
        loadRecentHashes()

        // Read poll interval from settings
        let interval = readPollIntervalFromSettings()
        startTimer(interval: interval)
        registerAppNotifications()
        registerSettingsObserver()

        logger.info("ClipboardMonitor started (poll=\(Int(interval * 1000))ms)")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        unregisterAppNotifications()
        unregisterSettingsObserver()

        logger.info("ClipboardMonitor stopped")
    }

    func pollNow() async {
        await MainActor.run {
            checkForChanges()
        }
    }

    // MARK: - Polling

    /// Check the pasteboard's `changeCount` and process new content if it changed.
    private func checkForChanges() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        logger.debug("Clipboard changeCount changed to \(currentCount)")

        guard let event = readPasteboardContent(pasteboard) else {
            logger.debug("No recognizable content on pasteboard")
            return
        }

        // In-memory dedup: skip if we've already seen this hash recently.
        guard !recentHashes.contains(event.contentHash) else {
            logger.debug("Duplicate content (in-memory), hash: \(event.contentHash, privacy: .public)")
            return
        }

        recentHashes.insert(event.contentHash)

        // Keep the in-memory cache bounded (last 200 unique hashes).
        if recentHashes.count > 200 {
            let trimmed = recentHashes.suffix(100)
            recentHashes = Set(trimmed)
        }

        continuation?.yield(event)
        logger.info("New clipboard content: type=\(event.contentType.rawValue, privacy: .public), hash=\(event.contentHash.prefix(12), privacy: .public)")
    }

    // MARK: - Content Detection

    /// Read the pasteboard and return a `ClipboardEvent` if recognizable content is found.
    ///
    /// Priority order: RTF > plain text > image > file.
    private func readPasteboardContent(_ pasteboard: NSPasteboard) -> ClipboardEvent? {
        let types = pasteboard.types ?? []

        // 1. RTF (highest priority)
        if types.contains(.rtf),
           let rtfData = pasteboard.data(forType: .rtf),
           let rtfString = String(data: rtfData, encoding: .utf8) {
            let hash = CryptoHelper.sha256(rtfData)
            return ClipboardEvent(
                contentType: .rtf,
                textContent: rtfString,
                imageData: nil,
                fileURLs: nil,
                contentHash: hash,
                timestamp: Date()
            )
        }

        // 2. Plain text
        if types.contains(.string),
           let text = pasteboard.string(forType: .string), !text.isEmpty {
            let hash = CryptoHelper.sha256(text)
            return ClipboardEvent(
                contentType: .text,
                textContent: text,
                imageData: nil,
                fileURLs: nil,
                contentHash: hash,
                timestamp: Date()
            )
        }

        // 3. Image (TIFF or PNG)
        if types.contains(.tiff) || types.contains(.png) {
            let imageData: Data?
            if types.contains(.png) {
                imageData = pasteboard.data(forType: .png)
            } else {
                imageData = pasteboard.data(forType: .tiff)
            }

            if let data = imageData, !data.isEmpty {
                let hash = CryptoHelper.sha256(data)
                return ClipboardEvent(
                    contentType: .image,
                    textContent: nil,
                    imageData: data,
                    fileURLs: nil,
                    contentHash: hash,
                    timestamp: Date()
                )
            }
        }

        // 4. File URLs
        if types.contains(.fileURL) {
            let urls = pasteboard.pasteboardItems?.compactMap { item in
                item.string(forType: .fileURL).flatMap { URL(string: $0) }
            } ?? []

            if !urls.isEmpty {
                // Hash the sorted path strings for deterministic dedup.
                let pathString = urls.map(\.path).sorted().joined(separator: "\n")
                let hash = CryptoHelper.sha256(pathString)
                return ClipboardEvent(
                    contentType: .file,
                    textContent: nil,
                    imageData: nil,
                    fileURLs: urls,
                    contentHash: hash,
                    timestamp: Date()
                )
            }
        }

        return nil
    }

    // MARK: - Deduplication

    /// Load recent content hashes from the database into memory for fast dedup checks.
    private func loadRecentHashes() {
        do {
            let recentItems = try repository.fetchHistory(page: 0, pageSize: 10)
            recentHashes = Set(recentItems.compactMap(\.contentHash))
            logger.debug("Loaded \(self.recentHashes.count) recent hashes for dedup")
        } catch {
            logger.error("Failed to load recent hashes: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Timer Management

    /// Start (or restart) the polling timer with the given interval.
    private func startTimer(interval: TimeInterval) {
        currentPollInterval = interval
        timer?.invalidate()

        let newTimer = Timer(timeInterval: interval, target: self, selector: #selector(timerFired), userInfo: nil, repeats: true)
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    @objc private func timerFired() {
        checkForChanges()
    }

    // MARK: - App State Notifications

    /// Observe app activation state to adjust polling frequency.
    private func registerAppNotifications() {
        becomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let interval = self.readPollIntervalFromSettings()
            self.logger.debug("App became active – switching to \(Int(interval * 1000))ms polling")
            self.startTimer(interval: interval)
        }

        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.logger.debug("App resigned active – switching to \(Int(self.backgroundPollInterval * 1000))ms polling")
            self.startTimer(interval: self.backgroundPollInterval)
        }
    }

    private func unregisterAppNotifications() {
        if let observer = becomeActiveObserver {
            NotificationCenter.default.removeObserver(observer)
            becomeActiveObserver = nil
        }
        if let observer = resignActiveObserver {
            NotificationCenter.default.removeObserver(observer)
            resignActiveObserver = nil
        }
    }

    // MARK: - Settings Observer

    /// Register observer for settings changes to update poll interval.
    private func registerSettingsObserver() {
        settingsChangeObserver = NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let interval = self.readPollIntervalFromSettings()
            self.logger.debug("Settings changed – updating poll interval to \(Int(interval * 1000))ms")
            self.startTimer(interval: interval)
        }
    }

    private func unregisterSettingsObserver() {
        if let observer = settingsChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            settingsChangeObserver = nil
        }
    }

    /// Read the poll interval from app_settings, falling back to the default.
    private func readPollIntervalFromSettings() -> TimeInterval {
        do {
            if let msStr = try repository.readSetting(key: SettingKey.pollIntervalMs),
               let ms = Int(msStr), ms > 0 {
                return TimeInterval(ms) / 1000.0
            }
        } catch {
            logger.error("Failed to read poll interval setting: \(error.localizedDescription, privacy: .public)")
        }
        return activePollInterval
    }
}
