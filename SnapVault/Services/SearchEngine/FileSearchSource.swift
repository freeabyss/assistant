import Foundation
import os.log

/// Protocol for file search source.
protocol FileSearchSourceProtocol: SearchSource {
    /// Set the search scope (default: user home directory).
    func setSearchScope(_ paths: [URL])

    /// Set file type filters (UTI types).
    func setFileTypes(_ types: [String])
}

/// Search source for local files via Spotlight.
///
/// This is a skeleton implementation. Full logic will be implemented in US-015.
final class FileSearchSource: FileSearchSourceProtocol {
    let sourceType: SearchResultType = .file
    private let logger = Logger.search

    // MARK: - SearchSource

    func search(query: String, limit: Int) async throws -> [UnifiedSearchResult] {
        // TODO: US-015 will implement full file search
        return []
    }

    // MARK: - FileSearchSourceProtocol

    func setSearchScope(_ paths: [URL]) {
        // TODO: US-015 will implement scope configuration
        logger.info("FileSearchSource.setSearchScope() - not yet implemented")
    }

    func setFileTypes(_ types: [String]) {
        // TODO: US-015 will implement file type filtering
        logger.info("FileSearchSource.setFileTypes() - not yet implemented")
    }
}
