import Foundation
import AppKit
import os.log

/// Search source for clipboard history.
///
/// Wraps the existing SearchService (FTS5 + Spotlight) and adapts
/// results to the unified SearchSource protocol.
///
/// Also conforms to SearchServiceProtocol for backward compatibility
/// with ClipboardListViewModel.
final class ClipboardSearchSource: SearchSource, SearchServiceProtocol {
    let sourceType: SearchResultType = .clipboard
    private let logger = Logger.search
    private let searchService: SearchService

    init(searchService: SearchService = SearchService()) {
        self.searchService = searchService
    }

    // MARK: - SearchSource

    func search(query: String, limit: Int) async throws -> [UnifiedSearchResult] {
        let results = try await searchService.search(query: query, limit: limit, scope: .all)
        return results.map { convertToUnified($0) }
    }

    // MARK: - SearchServiceProtocol (backward compatibility)

    func search(query: String, limit: Int, scope: SearchScope) async throws -> [SearchResult] {
        return try await searchService.search(query: query, limit: limit, scope: scope)
    }

    // MARK: - Conversion

    /// Convert a legacy SearchResult to a UnifiedSearchResult.
    private func convertToUnified(_ result: SearchResult) -> UnifiedSearchResult {
        let item = result.item
        let title = item.textContent ?? item.ocrText ?? item.filePath ?? "Untitled"
        let subtitle = buildSubtitle(for: item)
        let icon = iconForContentType(item.contentType)
        let itemID = item.id ?? 0

        return UnifiedSearchResult(
            id: "clipboard:\(itemID)",
            title: title,
            subtitle: subtitle,
            icon: icon,
            type: .clipboard,
            score: result.score,
            highlightRanges: result.highlightRanges,
            action: .copyToClipboard(itemID: itemID)
        )
    }

    /// Build a subtitle string for a clipboard item.
    private func buildSubtitle(for item: ClipboardItem) -> String? {
        switch item.contentType {
        case .text:
            return item.createdAt.formatted(.relative(presentation: .named))
        case .rtf:
            return "Rich Text - \(item.createdAt.formatted(.relative(presentation: .named)))"
        case .image:
            var parts: [String] = ["Image"]
            if let ocr = item.ocrText, !ocr.isEmpty {
                parts.append("OCR text available")
            }
            parts.append(item.createdAt.formatted(.relative(presentation: .named)))
            return parts.joined(separator: " - ")
        case .file:
            if let path = item.filePath {
                return (path as NSString).lastPathComponent
            }
            return "File"
        }
    }

    /// Get SF Symbol icon for content type.
    private func iconForContentType(_ type: ContentType) -> NSImage? {
        let name: String
        switch type {
        case .text: name = "doc.text"
        case .rtf: name = "doc.richtext"
        case .image: name = "photo"
        case .file: name = "doc"
        }
        return NSImage(systemSymbolName: name, accessibilityDescription: type.displayName)
    }
}
