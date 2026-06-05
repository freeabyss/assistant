import Foundation
import os.log

/// Search scope for filtering results.
enum SearchScope {
    case all
    case textOnly
    case imageOCR
}

/// A search result with relevance scoring.
struct SearchResult {
    let item: ClipboardItem
    let score: Double
    let matchedField: String
}

/// Protocol for search operations.
protocol SearchServiceProtocol {
    func search(query: String, limit: Int, scope: SearchScope) async throws -> [SearchResult]
}

/// Search service combining FTS5 and Spotlight results.
/// Implementation will be completed in US-005.
final class SearchService: SearchServiceProtocol {
    private let logger = Logger.search
    private let repository = ContentRepository()

    func search(query: String, limit: Int = 50, scope: SearchScope = .all) async throws -> [SearchResult] {
        logger.info("SearchService.search() called - not yet fully implemented")
        let items = try repository.search(query: query, limit: limit)
        return items.map { SearchResult(item: $0, score: 1.0, matchedField: "text_content") }
    }
}
