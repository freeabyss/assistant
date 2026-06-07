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

        // Spotlight: literal name + content match (no pinyin support server-side).
        var fileResults = await performSpotlightSearch(query: trimmed, limit: limit)

        // Client-side pinyin rerank: only meaningful when the query is plain
        // ASCII (potential pinyin/initials) and we got back files whose display
        // names contain CJK characters.
        let queryLower = trimmed.lowercased()
        let isPinyinCandidate = isASCIIQuery(queryLower)

        // When the user types pinyin, Spotlight's literal predicate often
        // misses CJK-named files. Augment the result set by scanning a small
        // recent-files window from common scopes and pinyin-matching client
        // side. We keep this strictly bounded (max 200 candidates) so cost
        // stays in the tens of ms range.
        if isPinyinCandidate {
            let augmented = await augmentWithPinyinScan(query: queryLower, existing: fileResults, limit: limit)
            fileResults.append(contentsOf: augmented)
        }

        let results = fileResults.map { fileInfo -> UnifiedSearchResult in
            var relevanceScore = computeRelevanceScore(fileInfo: fileInfo, query: trimmed)
            if isPinyinCandidate {
                // Apply a pinyin bonus when the file's display name pinyin/initials
                // match the query. Bonus is below literal name-prefix (0.7) so
                // exact matches still win.
                let bonus = pinyinScoreBonus(name: fileInfo.name, query: queryLower)
                if bonus > 0 {
                    relevanceScore = min(relevanceScore + bonus, 0.95)
                }
            }
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
        .sorted { $0.score > $1.score }

        logger.info("FileSearchSource found \(results.count) results for '\(trimmed, privacy: .public)' (pinyinCandidate=\(isPinyinCandidate))")
        return Array(results.prefix(limit))
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

    // MARK: - Pinyin Augmentation

    /// True if the query is plain ASCII — i.e. it could be pinyin/initials.
    private func isASCIIQuery(_ query: String) -> Bool {
        for scalar in query.unicodeScalars where scalar.value > 127 {
            return false
        }
        return !query.isEmpty
    }

    /// Compute a bonus score for files whose display name pinyin or initials
    /// match the query.
    ///
    /// Bonus tiers (mirrors AppSearchSource):
    /// - Pinyin prefix: +0.5
    /// - Initials match: +0.4
    /// - Pinyin contains: +0.3
    /// - No CJK characters in name → 0 (literal matching already applies)
    private func pinyinScoreBonus(name: String, query: String) -> Double {
        // Skip pure-ASCII names: literal contains/prefix already handled.
        guard containsCJK(name) else { return 0 }

        let pinyin = PinyinHelper.toPinyin(name)
        if pinyin.hasPrefix(query) { return 0.5 }

        let initials = PinyinHelper.toInitials(name)
        if !initials.isEmpty && initials.hasPrefix(query) { return 0.4 }

        if pinyin.contains(query) { return 0.3 }

        return 0
    }

    /// Scan the user's most-frequented directories for CJK-named files that
    /// match the pinyin query but were missed by Spotlight's literal predicate.
    ///
    /// Strategy:
    /// 1. Pick a small set of scopes (~/Desktop, ~/Documents, ~/Downloads or
    ///    the configured `searchScopePaths`).
    /// 2. Take the most-recently-modified ~200 entries.
    /// 3. Pinyin-match client side.
    /// 4. Skip anything already in `existing` (dedup by absolute path).
    ///
    /// Bounded cost: enumeration is shallow (top-level), no recursion into
    /// subdirectories, so even on large folders this stays sub-50ms.
    private func augmentWithPinyinScan(
        query: String,
        existing: [FileInfo],
        limit: Int
    ) async -> [FileInfo] {
        let existingPaths = Set(existing.map { $0.path.path })
        let scopes: [URL]
        if searchScopePaths.isEmpty {
            let home = FileManager.default.homeDirectoryForCurrentUser
            scopes = [
                home.appendingPathComponent("Desktop"),
                home.appendingPathComponent("Documents"),
                home.appendingPathComponent("Downloads"),
            ]
        } else {
            scopes = searchScopePaths
        }

        return await Task.detached(priority: .userInitiated) { [scopes, existingPaths, query, limit] in
            FileSearchSource.scanScopesForPinyin(
                scopes: scopes,
                query: query,
                excluding: existingPaths,
                limit: limit
            )
        }.value
    }

    /// Detached worker — kept static so it doesn't capture `self`.
    private static func scanScopesForPinyin(
        scopes: [URL],
        query: String,
        excluding: Set<String>,
        limit: Int
    ) -> [FileInfo] {
        let fm = FileManager.default
        var candidates: [(URL, Date)] = []
        let perScopeCap = 200

        for scope in scopes {
            guard let contents = try? fm.contentsOfDirectory(
                at: scope,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            ) else { continue }

            for url in contents.prefix(perScopeCap) {
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
                guard values?.isRegularFile == true else { continue }
                let mtime = values?.contentModificationDate ?? Date.distantPast
                candidates.append((url, mtime))
            }
        }

        // Sort newest-first then truncate
        candidates.sort { $0.1 > $1.1 }
        let pool = candidates.prefix(perScopeCap * 3)

        var results: [FileInfo] = []
        for (url, mtime) in pool {
            if results.count >= limit { break }
            if excluding.contains(url.path) { continue }
            let name = url.lastPathComponent
            // Only consider CJK-named files (otherwise Spotlight already covered)
            guard containsCJKStatic(name) else { continue }

            let pinyin = PinyinHelper.toPinyin(name)
            let initials = PinyinHelper.toInitials(name)
            let matches = pinyin.contains(query) || initials.hasPrefix(query)
            guard matches else { continue }

            let size: Int64
            if let s = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                size = Int64(s)
            } else {
                size = 0
            }
            let contentType: String
            if let uti = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType?.identifier {
                contentType = uti
            } else {
                contentType = "public.data"
            }
            let icon = NSWorkspace.shared.icon(forFile: url.path)

            results.append(FileInfo(
                name: name,
                path: url,
                contentType: contentType,
                size: size,
                modifiedDate: mtime,
                icon: icon
            ))
        }
        return results
    }

    /// Return true if any scalar in `s` is outside the ASCII range
    /// (cheap proxy for "contains CJK / non-Latin characters").
    private func containsCJK(_ s: String) -> Bool {
        for scalar in s.unicodeScalars where scalar.value > 127 {
            return true
        }
        return false
    }

    /// Static version of `containsCJK` for use in detached workers.
    private static func containsCJKStatic(_ s: String) -> Bool {
        for scalar in s.unicodeScalars where scalar.value > 127 {
            return true
        }
        return false
    }
}
