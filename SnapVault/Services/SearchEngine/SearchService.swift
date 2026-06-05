import Foundation
import AppKit
import os.log

/// Search scope for filtering results.
enum SearchScope {
    case all
    case textOnly
    case imageOCR
}

/// A search result with relevance scoring and highlight information.
struct SearchResult {
    let item: ClipboardItem
    let score: Double
    let matchedField: String
    let highlightRanges: [NSRange]
}

/// Protocol for search operations.
protocol SearchServiceProtocol {
    func search(query: String, limit: Int, scope: SearchScope) async throws -> [SearchResult]
}

/// Search service combining FTS5 and Spotlight results.
///
/// Primary search: GRDB FTS5 (fast, local, immediate).
/// Supplementary search: NSMetadataQuery / Spotlight (covers system-indexed content).
/// Spotlight results are merged with FTS5 results, deduped by item id, and sorted by relevance.
final class SearchService: SearchServiceProtocol {
    private let logger = Logger.search
    private let repository = ContentRepository()

    /// Spotlight query timeout in seconds.
    private let spotlightTimeout: TimeInterval = 2.0

    func search(query: String, limit: Int = 50, scope: SearchScope = .all) async throws -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        logger.info("SearchService.search() query='\(trimmed, privacy: .public)' scope=\(String(describing: scope))")

        // 1. Primary: FTS5 search (fast, always available)
        let ftsResults = try searchFTS5(query: trimmed, limit: limit, scope: scope)

        // 2. Supplementary: Spotlight search (may have indexing delay)
        let spotlightResults = await searchSpotlight(query: trimmed, limit: limit, scope: scope)

        // 3. Merge, dedup, sort
        let merged = mergeResults(ftsResults: ftsResults, spotlightResults: spotlightResults, limit: limit)

        logger.info("Search complete: FTS5=\(ftsResults.count), Spotlight=\(spotlightResults.count), merged=\(merged.count)")
        return merged
    }

    // MARK: - FTS5 Search

    /// Search using GRDB FTS5 full-text index.
    private func searchFTS5(query: String, limit: Int, scope: SearchScope) throws -> [SearchResult] {
        let ftsResults = try repository.searchStructured(query: query, limit: limit, scope: scope)

        return ftsResults.map { ftsResult in
            let highlightRanges = computeHighlightRanges(
                in: ftsResult.item.textContent ?? ftsResult.item.ocrText ?? "",
                query: query
            )
            return SearchResult(
                item: ftsResult.item,
                score: ftsResult.score,
                matchedField: ftsResult.matchedField,
                highlightRanges: highlightRanges
            )
        }
    }

    // MARK: - Spotlight Search

    /// Search using NSMetadataQuery (Spotlight) as supplementary source.
    private func searchSpotlight(query: String, limit: Int, scope: SearchScope) async -> [SearchResult] {
        // Spotlight is supplementary; if it fails or times out, we still have FTS5 results.
        return await withCheckedContinuation { continuation in
            let metadataQuery = NSMetadataQuery()
            metadataQuery.searchScopes = [NSMetadataQueryLocalComputerScope]

            // Build predicate based on scope
            let predicate: NSPredicate
            switch scope {
            case .all:
                predicate = NSPredicate(format: "kMDItemTextContent CONTAINS[cd] %@", query)
            case .textOnly:
                predicate = NSPredicate(format: "kMDItemTextContent CONTAINS[cd] %@", query)
            case .imageOCR:
                // Spotlight indexes OCR text in kMDItemTextContent for images
                predicate = NSPredicate(format: "kMDItemTextContent CONTAINS[cd] %@", query)
            }
            metadataQuery.predicate = predicate

            // Sort by relevance
            metadataQuery.sortDescriptors = [
                NSSortDescriptor(key: NSMetadataQueryResultContentRelevanceAttribute as String, ascending: false)
            ]

            var didResume = false
            let lock = NSLock()

            func safeResume(with results: [SearchResult]) {
                lock.lock()
                defer { lock.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: results)
            }

            // Observe query completion
            NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: metadataQuery,
                queue: .main
            ) { [weak self] _ in
                metadataQuery.disableUpdates()
                metadataQuery.stop()

                let results = self?.processSpotlightResults(metadataQuery, limit: limit) ?? []
                safeResume(with: results)
            }

            // Start the query on the current RunLoop
            let started = metadataQuery.start()
            if !started {
                logger.warning("Spotlight query failed to start")
                safeResume(with: [])
                return
            }

            // Timeout fallback - if Spotlight doesn't respond in time, return empty
            DispatchQueue.main.asyncAfter(deadline: .now() + spotlightTimeout) {
                if metadataQuery.isGathering {
                    metadataQuery.stop()
                }
                safeResume(with: [])
            }
        }
    }

    /// Process Spotlight query results into SearchResult objects.
    private func processSpotlightResults(_ query: NSMetadataQuery, limit: Int) -> [SearchResult] {
        guard let items = query.results as? [NSMetadataItem] else { return [] }

        var results: [SearchResult] = []
        let searchText = query.predicate?.predicateFormat ?? ""

        for metadataItem in items.prefix(limit) {
            // Extract text content from Spotlight metadata
            guard let textContent = metadataItem.value(forAttribute: kMDItemTextContent as String) as? String,
                  !textContent.isEmpty else {
                continue
            }

            // Try to match against existing clipboard items by content hash
            // Spotlight doesn't know about our item IDs, so we match by content
            let hash = CryptoHelper.sha256(textContent)
            if let existingItem = try? repository.findByHash(hash) {
                let relevance = metadataItem.value(forAttribute: NSMetadataQueryResultContentRelevanceAttribute as String) as? Double ?? 0.5
                let highlightRanges = computeHighlightRanges(in: textContent, query: searchText)

                results.append(SearchResult(
                    item: existingItem,
                    score: relevance,
                    matchedField: "text_content",
                    highlightRanges: highlightRanges
                ))
            }
        }

        return results
    }

    // MARK: - Result Merging

    /// Merge FTS5 and Spotlight results, dedup by item id, sort by relevance.
    private func mergeResults(ftsResults: [SearchResult], spotlightResults: [SearchResult], limit: Int) -> [SearchResult] {
        var seen = Set<Int64>()
        var merged: [SearchResult] = []

        // FTS5 results take priority (they are always fresh and directly indexed)
        for result in ftsResults {
            guard let id = result.item.id else { continue }
            if seen.insert(id).inserted {
                merged.append(result)
            }
        }

        // Add Spotlight results that are not already in FTS5 results
        for result in spotlightResults {
            guard let id = result.item.id else { continue }
            if seen.insert(id).inserted {
                merged.append(result)
            }
        }

        // Sort: pinned first, then by score descending, then by created_at descending
        merged.sort { lhs, rhs in
            if lhs.item.isPinned != rhs.item.isPinned {
                return lhs.item.isPinned
            }
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            return lhs.item.createdAt > rhs.item.createdAt
        }

        return Array(merged.prefix(limit))
    }

    // MARK: - Highlight Ranges

    /// Compute NSRange positions of query keywords within the text.
    /// Uses case-insensitive and diacritic-insensitive matching for Chinese support.
    private func computeHighlightRanges(in text: String, query: String) -> [NSRange] {
        guard !text.isEmpty, !query.isEmpty else { return [] }

        // Split query into individual keywords (space-separated)
        let keywords = query.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        var ranges: [NSRange] = []
        let nsText = text as NSString

        for keyword in keywords {
            // Use case-insensitive + diacritic-insensitive search for Chinese compatibility
            let options: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
            var searchRange = NSRange(location: 0, length: nsText.length)

            while searchRange.location < nsText.length {
                let foundRange = nsText.range(of: keyword, options: options, range: searchRange)
                guard foundRange.location != NSNotFound else { break }
                ranges.append(foundRange)
                searchRange = NSRange(
                    location: foundRange.location + foundRange.length,
                    length: nsText.length - (foundRange.location + foundRange.length)
                )
            }
        }

        // Sort ranges by location
        return ranges.sorted { $0.location < $1.location }
    }
}
