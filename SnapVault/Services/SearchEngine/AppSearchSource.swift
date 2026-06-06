import Foundation
import AppKit
import os.log

/// Application information for search results.
struct AppInfo {
    let name: String
    let bundleID: String
    let path: URL
    let icon: NSImage?
    let lastUsed: Date?
    let useCount: Int
}

/// Protocol for application search source.
protocol AppSearchSourceProtocol: SearchSource {
    /// Build or refresh the application index.
    func rebuildIndex() async

    /// Get application info by bundle identifier.
    func getAppInfo(bundleID: String) -> AppInfo?
}

/// Search source for installed applications.
///
/// This is a skeleton implementation. Full logic will be implemented in US-014.
final class AppSearchSource: AppSearchSourceProtocol {
    let sourceType: SearchResultType = .application
    private let logger = Logger.search

    // MARK: - SearchSource

    func search(query: String, limit: Int) async throws -> [UnifiedSearchResult] {
        // TODO: US-014 will implement full application search
        return []
    }

    // MARK: - AppSearchSourceProtocol

    func rebuildIndex() async {
        // TODO: US-014 will implement index building
        logger.info("AppSearchSource.rebuildIndex() - not yet implemented")
    }

    func getAppInfo(bundleID: String) -> AppInfo? {
        // TODO: US-014 will implement app info lookup
        return nil
    }
}
