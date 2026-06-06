import Foundation
import AppKit
import UniformTypeIdentifiers
import os.log

/// File information extracted from Spotlight metadata.
struct FileInfo {
    let name: String
    let path: URL
    let contentType: String       // UTI type
    let size: Int64
    let modifiedDate: Date
    let icon: NSImage?
}

/// Protocol for file search source.
protocol FileSearchSourceProtocol: SearchSource {
    /// Set the search scope (default: user home directory).
    func setSearchScope(_ paths: [URL])

    /// Set file type filters (UTI types).
    func setFileTypes(_ types: [String])
}

/// Search source for local files via Spotlight (NSMetadataQuery).
///
/// Uses the system Spotlight index to search for files by name and content.
/// Searches are performed on the main RunLoop (required by NSMetadataQuery)
/// with a configurable timeout to avoid blocking.
final class FileSearchSource: FileSearchSourceProtocol {
    let sourceType: SearchResultType = .file
    private let logger = Logger.search

    /// Spotlight query timeout in seconds.
    private let timeout: TimeInterval = 5.0

    /// Custom search scopes. If empty, defaults to user home directory.
    private var searchScopePaths: [URL] = []

    /// File type UTI filters. If empty, no type filtering is applied.
    private var fileTypes: [String] = []

    // MARK: - SearchSource

    func search(query: String, limit: Int) async throws -> [UnifiedSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        logger.info("FileSearchSource.search() query='\(trimmed, privacy: .public)' limit=\(limit)")

        let fileResults = await performSpotlightSearch(query: trimmed, limit: limit)

        let results = fileResults.map { fileInfo -> UnifiedSearchResult in
            let relevanceScore = computeRelevanceScore(fileInfo: fileInfo, query: trimmed)
            let subtitle = buildSubtitle(fileInfo: fileInfo)

            return UnifiedSearchResult(
                id: "file:\(fileInfo.path.path)",
                title: fileInfo.name,
                subtitle: subtitle,
                icon: fileInfo.icon,
                type: .file,
                score: relevanceScore,
                highlightRanges: computeHighlightRanges(in: fileInfo.name, query: trimmed),
                action: .openFile(path: fileInfo.path)
            )
        }

        logger.info("FileSearchSource found \(results.count) results for '\(trimmed, privacy: .public)'")
        return results
    }

    // MARK: - FileSearchSourceProtocol

    func setSearchScope(_ paths: [URL]) {
        searchScopePaths = paths
        logger.info("FileSearchSource.setSearchScope() paths=\(paths.map(\.path).joined(separator: ", "), privacy: .public)")
    }

    func setFileTypes(_ types: [String]) {
        fileTypes = types
        logger.info("FileSearchSource.setFileTypes() types=\(types.joined(separator: ", "), privacy: .public)")
    }

    // MARK: - Spotlight Query

    /// Perform a Spotlight search using NSMetadataQuery.
    ///
    /// NSMetadataQuery must be started on a RunLoop, so we dispatch to the main thread.
    /// Results are collected via the didFinishGathering notification with a timeout fallback.
    private func performSpotlightSearch(query: String, limit: Int) async -> [FileInfo] {
        return await withCheckedContinuation { continuation in
            // NSMetadataQuery requires RunLoop.main
            DispatchQueue.main.async { [self] in
                self.executeQuery(query: query, limit: limit, continuation: continuation)
            }
        }
    }

    /// Execute the NSMetadataQuery on the main RunLoop.
    private func executeQuery(query: String, limit: Int, continuation: CheckedContinuation<[FileInfo], Never>) {
        let metadataQuery = NSMetadataQuery()

        // Configure search scope
        if searchScopePaths.isEmpty {
            metadataQuery.searchScopes = [NSMetadataQueryUserHomeScope]
        } else {
            metadataQuery.searchScopes = searchScopePaths.map(\.path)
        }

        // Build predicate: search file name and content
        let namePredicate = NSPredicate(format: "kMDItemDisplayName CONTAINS[cd] %@", query)
        let contentPredicate = NSPredicate(format: "kMDItemTextContent CONTAINS[cd] %@", query)
        var compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [namePredicate, contentPredicate])

        // Apply file type filter if configured
        if !fileTypes.isEmpty {
            let typePredicates = fileTypes.map { NSPredicate(format: "kMDItemContentType == %@", $0) }
            let typeFilter = NSCompoundPredicate(orPredicateWithSubpredicates: typePredicates)
            compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [compoundPredicate, typeFilter])
        }

        metadataQuery.predicate = compoundPredicate

        // Sort by relevance
        metadataQuery.sortDescriptors = [
            NSSortDescriptor(key: NSMetadataQueryResultContentRelevanceAttribute as String, ascending: false)
        ]

        var didResume = false
        let lock = NSLock()

        func safeResume(with results: [FileInfo]) {
            lock.lock()
            defer { lock.unlock() }
            guard !didResume else { return }
            didResume = true
            continuation.resume(returning: results)
        }

        // Observe query completion
        let observer = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: metadataQuery,
            queue: .main
        ) { [weak self] _ in
            metadataQuery.disableUpdates()
            metadataQuery.stop()

            let results = self?.processResults(metadataQuery, limit: limit) ?? []
            safeResume(with: results)
        }

        // Start the query on the current RunLoop
        let started = metadataQuery.start()
        if !started {
            logger.warning("FileSearchSource: NSMetadataQuery failed to start")
            NotificationCenter.default.removeObserver(observer)
            safeResume(with: [])
            return
        }

        // Timeout protection: if Spotlight doesn't respond, return empty results
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            if metadataQuery.isGathering {
                self?.logger.warning("FileSearchSource: Spotlight query timed out after \(self?.timeout ?? 0)s")
                metadataQuery.stop()
            }
            safeResume(with: [])
        }
    }

    // MARK: - Result Processing

    /// Extract FileInfo objects from NSMetadataQuery results.
    private func processResults(_ query: NSMetadataQuery, limit: Int) -> [FileInfo] {
        guard let items = query.results as? [NSMetadataItem] else { return [] }

        var results: [FileInfo] = []

        for metadataItem in items.prefix(limit) {
            guard let fileInfo = extractFileInfo(from: metadataItem) else { continue }
            results.append(fileInfo)
        }

        return results
    }

    /// Extract a FileInfo from a single NSMetadataItem.
    private func extractFileInfo(from item: NSMetadataItem) -> FileInfo? {
        // File name (required)
        guard let name = item.value(forAttribute: kMDItemDisplayName as String) as? String,
              !name.isEmpty else {
            return nil
        }

        // File path (required)
        guard let pathString = item.value(forAttribute: kMDItemPath as String) as? String,
              !pathString.isEmpty else {
            return nil
        }
        let path = URL(fileURLWithPath: pathString)

        // UTI content type
        let contentType = item.value(forAttribute: kMDItemContentType as String) as? String ?? "public.data"

        // File size
        let size = (item.value(forAttribute: kMDItemFSSize as String) as? NSNumber)?.int64Value ?? 0

        // Modification date
        let modifiedDate = item.value(forAttribute: kMDItemContentModificationDate as String) as? Date ?? Date()

        // File icon from NSWorkspace
        let icon = NSWorkspace.shared.icon(forFile: path.path)

        return FileInfo(
            name: name,
            path: path,
            contentType: contentType,
            size: size,
            modifiedDate: modifiedDate,
            icon: icon
        )
    }

    // MARK: - Scoring

    /// Compute a relevance score (0-1) for a file result.
    ///
    /// Scoring factors:
    /// - Name match quality (prefix match > contains match)
    /// - Recency (more recently modified files score higher)
    private func computeRelevanceScore(fileInfo: FileInfo, query: String) -> Double {
        let queryLower = query.lowercased()
        let nameLower = fileInfo.name.lowercased()

        // Name match quality (0-0.7)
        var nameScore: Double = 0
        if nameLower.hasPrefix(queryLower) {
            nameScore = 0.7  // Prefix match: highest priority
        } else if nameLower.contains(queryLower) {
            nameScore = 0.5  // Contains match
        } else {
            // Matched via content, not file name
            nameScore = 0.2
        }

        // Recency bonus (0-0.3): files modified within 7 days get full bonus
        let daysSinceModified = Date().timeIntervalSince(fileInfo.modifiedDate) / 86400
        let recencyScore: Double
        if daysSinceModified < 1 {
            recencyScore = 0.3
        } else if daysSinceModified < 7 {
            recencyScore = 0.2
        } else if daysSinceModified < 30 {
            recencyScore = 0.1
        } else {
            recencyScore = 0.0
        }

        return min(nameScore + recencyScore, 1.0)
    }

    // MARK: - Subtitle

    /// Build a human-readable subtitle for a file result.
    private func buildSubtitle(fileInfo: FileInfo) -> String {
        var parts: [String] = []

        // File kind from UTI
        if let kind = UTType(fileInfo.contentType)?.localizedDescription {
            parts.append(kind)
        }

        // File size
        if fileInfo.size > 0 {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB, .useGB]
            formatter.countStyle = .file
            parts.append(formatter.string(fromByteCount: fileInfo.size))
        }

        // Relative modification time
        parts.append(relativeTimeString(from: fileInfo.modifiedDate))

        return parts.joined(separator: " · ")
    }

    /// Format a date as a relative time string (e.g. "2h ago", "3d ago").
    private func relativeTimeString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return NSLocalizedString("Just now", comment: "")
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return String(format: NSLocalizedString("%dm ago", comment: ""), minutes)
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return String(format: NSLocalizedString("%dh ago", comment: ""), hours)
        } else {
            let days = Int(interval / 86400)
            return String(format: NSLocalizedString("%dd ago", comment: ""), days)
        }
    }

    // MARK: - Highlight

    /// Compute highlight ranges for query keywords within the text.
    private func computeHighlightRanges(in text: String, query: String) -> [NSRange] {
        guard !text.isEmpty, !query.isEmpty else { return [] }

        let keywords = query.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        var ranges: [NSRange] = []
        let nsText = text as NSString

        for keyword in keywords {
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

        return ranges.sorted { $0.location < $1.location }
    }
}
