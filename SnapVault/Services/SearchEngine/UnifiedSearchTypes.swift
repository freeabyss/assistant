import Foundation
import AppKit

// MARK: - Search Result Type

/// Type of search result source.
enum SearchResultType: String, Codable, CaseIterable {
    case application
    case file
    case clipboard

    var displayName: String {
        switch self {
        case .application: return "Applications"
        case .file: return "Files"
        case .clipboard: return "Clipboard"
        }
    }

    var iconName: String {
        switch self {
        case .application: return "app.fill"
        case .file: return "doc.fill"
        case .clipboard: return "clipboard.fill"
        }
    }
}

// MARK: - Unified Search Result

/// A unified search result from any source.
struct UnifiedSearchResult: Identifiable {
    let id: String                // Unique identifier (sourceType:originalID)
    let title: String             // Primary title
    let subtitle: String?         // Secondary info
    let icon: NSImage?            // Display icon
    let type: SearchResultType    // Result source type
    let score: Double             // Composite ranking score (0-1)
    let highlightRanges: [NSRange] // Highlight positions in title
    let action: SearchResultAction // Action when selected
}

// MARK: - Search Result Action

/// Action to perform when a search result is selected.
enum SearchResultAction {
    case launchApp(bundleID: String, path: URL)
    case openFile(path: URL)
    case openInFinder(path: URL)
    case copyToClipboard(itemID: Int64)
}

// MARK: - Unified Search Response

/// Response from a unified search query, grouped by type.
struct UnifiedSearchResponse {
    let applications: [UnifiedSearchResult]
    let files: [UnifiedSearchResult]
    let clipboard: [UnifiedSearchResult]
    let totalCount: Int
    let elapsed: TimeInterval  // Search duration in milliseconds
}

// MARK: - SearchSource Protocol

/// Protocol for pluggable search sources.
///
/// Each source searches a specific domain (apps, files, clipboard)
/// and returns results in the unified format.
protocol SearchSource {
    /// The type of results this source produces.
    var sourceType: SearchResultType { get }

    /// Search this source for matching items.
    /// - Parameters:
    ///   - query: Search query string
    ///   - limit: Maximum number of results to return
    /// - Returns: Array of unified search results
    func search(query: String, limit: Int) async throws -> [UnifiedSearchResult]
}
