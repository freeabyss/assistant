import Foundation
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
/// Implementation will be completed in US-003.
final class ClipboardMonitor: ClipboardMonitorProtocol {
    private let logger = Logger.clipboard

    var onNewContent: AsyncStream<ClipboardEvent> {
        AsyncStream { continuation in
            // Will be implemented in US-003
            continuation.finish()
        }
    }

    func start() {
        logger.info("ClipboardMonitor.start() called - not yet implemented")
    }

    func stop() {
        logger.info("ClipboardMonitor.stop() called - not yet implemented")
    }

    func pollNow() async {
        logger.debug("ClipboardMonitor.pollNow() called - not yet implemented")
    }
}
