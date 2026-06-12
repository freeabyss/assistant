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
/// Scans /Applications and ~/Applications on startup, builds an in-memory
/// sorted index, and supports prefix / contains / fuzzy (Levenshtein) matching.
final class AppSearchSource: AppSearchSourceProtocol {
    let sourceType: SearchResultType = .application
    private let logger = Logger.search

    // MARK: - Index State

    /// In-memory app index, sorted by normalized name for binary search.
    private var apps: [IndexedApp] = []

    /// Lock protecting the apps array.
    private let lock = NSLock()

    /// Whether the initial index build has completed.
    private var isReady = false

    /// Use count per bundle ID, persisted to UserDefaults.
    private let useCountKey = "app_search_use_counts"
    private var useCounts: [String: Int]

    /// Periodic refresh timer (every 5 minutes).
    private var refreshTimer: Timer?

    // MARK: - Init

    init() {
        // Load persisted use counts
        if let data = UserDefaults.standard.data(forKey: useCountKey),
           let counts = try? JSONDecoder().decode([String: Int].self, from: data) {
            useCounts = counts
        } else {
            useCounts = [:]
        }

        // Build initial index asynchronously
        buildIndexAsync()

        // Schedule periodic refresh every 5 minutes
        schedulePeriodicRefresh()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - SearchSource

    func search(query: String, limit: Int) async throws -> [UnifiedSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard isReady else {
            logger.warning("App index not ready yet, returning empty results for '\(trimmed, privacy: .public)'")
            return []
        }

        let queryNormalized = normalize(trimmed)
        var results: [UnifiedSearchResult] = []

        lock.lock()
        let snapshot = apps
        lock.unlock()

        // Strategy 1: Prefix match (highest priority, uses binary search)
        let prefixResults = prefixMatch(in: snapshot, query: queryNormalized, limit: limit)
        results.append(contentsOf: prefixResults.map { buildResult(app: $0, matchType: .prefix, queryNormalized: queryNormalized) })

        // Strategy 2: Contains match (medium priority)
        if results.count < limit {
            let containsResults = containsMatch(in: snapshot, query: queryNormalized, excluding: Set(prefixResults.map(\.bundleID)), limit: limit - results.count)
            results.append(contentsOf: containsResults.map { buildResult(app: $0, matchType: .contains, queryNormalized: queryNormalized) })
        }

        // Strategy 3: Pinyin matching for CJK app names (only relevant when the
        // query is plain ASCII — otherwise the literal text strategies above
        // already covered it). Three tiers:
        //   - Pinyin prefix (e.g. "weix" -> "微信" pinyin "weixin")
        //   - Initials match (e.g. "sf" -> "Safari" or "数符" initials)
        //   - Pinyin contains
        if results.count < limit && isASCIIQuery(queryNormalized) {
            let existingIDs = Set(results.compactMap { extractBundleID(from: $0.id) })
            let pinyinResults = pinyinMatch(in: snapshot, query: queryNormalized, excluding: existingIDs, limit: limit - results.count)
            results.append(contentsOf: pinyinResults)
        }

        // Strategy 4: Fuzzy match (Levenshtein distance <= 2, lowest priority)
        if results.count < limit {
            let existingIDs = Set(results.compactMap { extractBundleID(from: $0.id) })
            let fuzzyResults = fuzzyMatch(in: snapshot, query: queryNormalized, excluding: existingIDs, limit: limit - results.count)
            results.append(contentsOf: fuzzyResults.map { buildResult(app: $0, matchType: .fuzzy, queryNormalized: queryNormalized) })
        }

        // Sort: prefix > contains > fuzzy, then by useCount descending, then by name
        results.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            let lhsCount = extractUseCount(from: lhs.id)
            let rhsCount = extractUseCount(from: rhs.id)
            if lhsCount != rhsCount { return lhsCount > rhsCount }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        logger.info("App search '\(trimmed, privacy: .public)': \(results.count) results")
        return results
    }

    // MARK: - AppSearchSourceProtocol

    func rebuildIndex() async {
        logger.info("Rebuilding application index (forced)")
        await buildIndex()
    }

    func getAppInfo(bundleID: String) -> AppInfo? {
        lock.lock()
        defer { lock.unlock() }
        guard let app = apps.first(where: { $0.bundleID == bundleID }) else {
            return nil
        }
        return AppInfo(
            name: app.name,
            bundleID: app.bundleID,
            path: app.path,
            icon: app.icon,
            lastUsed: nil,
            useCount: useCounts[bundleID] ?? 0
        )
    }

    // MARK: - Index Building

    private func buildIndexAsync() {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            await self.buildIndex()
            self.lock.lock()
            self.isReady = true
            self.lock.unlock()
            self.logger.info("Initial application index build complete")
            NotificationCenter.default.post(name: .appSearchIndexReady, object: nil)
        }
    }

    private func buildIndex() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        let paths = scanApplicationPaths()
        let indexedApps = paths.compactMap { readAppInfo(from: $0) }

        lock.lock()
        apps = indexedApps.sorted { $0.normalizedName < $1.normalizedName }
        lock.unlock()

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.info("Indexed \(indexedApps.count) applications in \(String(format: "%.1f", elapsed))ms")
    }

    /// Scan /Applications and ~/Applications for .app bundles.
    private func scanApplicationPaths() -> [URL] {
        var paths: [URL] = []
        let fm = FileManager.default

        // System-wide /Applications
        if let systemApps = fm.urls(for: .applicationDirectory, in: .localDomainMask).first {
            paths.append(contentsOf: findAppBundles(in: systemApps))
        }

        // User ~/Applications
        if let userApps = fm.urls(for: .applicationDirectory, in: .userDomainMask).first {
            paths.append(contentsOf: findAppBundles(in: userApps))
        }

        return paths
    }

    /// Recursively find .app bundles in a directory.
    private func findAppBundles(in directory: URL) -> [URL] {
        let fm = FileManager.default
        var result: [URL] = []

        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return result
        }

        while let url = enumerator.nextObject() as? URL {
            if url.pathExtension == "app" {
                result.append(url)
                enumerator.skipDescendants()
            }
        }

        return result
    }

    /// Read app metadata from a .app bundle's Info.plist.
    private func readAppInfo(from appURL: URL) -> IndexedApp? {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let plistData = FileManager.default.contents(atPath: plistURL.path),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        else {
            return nil
        }

        // Get display name (prefer CFBundleDisplayName, fallback to CFBundleName)
        let name: String
        if let displayName = plist["CFBundleDisplayName"] as? String, !displayName.isEmpty {
            name = displayName
        } else if let bundleName = plist["CFBundleName"] as? String, !bundleName.isEmpty {
            name = bundleName
        } else {
            name = appURL.deletingPathExtension().lastPathComponent
        }

        // Get bundle ID
        guard let bundleID = plist["CFBundleIdentifier"] as? String, !bundleID.isEmpty else {
            return nil
        }

        // Get app icon from workspace
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 32, height: 32)

        return IndexedApp(
            name: name,
            bundleID: bundleID,
            path: appURL,
            icon: icon,
            normalizedName: normalize(name),
            pinyin: PinyinHelper.toPinyin(name),
            initials: PinyinHelper.toInitials(name)
        )
    }

    // MARK: - Search Strategies

    /// Prefix match using binary search on the sorted index.
    private func prefixMatch(in apps: [IndexedApp], query: String, limit: Int) -> [IndexedApp] {
        guard !apps.isEmpty else { return [] }

        // Binary search for the first app whose name starts with the query
        var low = 0
        var high = apps.count
        while low < high {
            let mid = (low + high) / 2
            if apps[mid].normalizedName < query {
                low = mid + 1
            } else {
                high = mid
            }
        }

        var results: [IndexedApp] = []
        var i = low
        while i < apps.count && results.count < limit {
            if apps[i].normalizedName.hasPrefix(query) {
                results.append(apps[i])
            } else {
                break // Sorted, so no more prefix matches possible
            }
            i += 1
        }

        return results
    }

    /// Contains match: linear scan excluding already-matched bundle IDs.
    private func containsMatch(in apps: [IndexedApp], query: String, excluding: Set<String>, limit: Int) -> [IndexedApp] {
        var results: [IndexedApp] = []
        for app in apps {
            if results.count >= limit { break }
            if excluding.contains(app.bundleID) { continue }
            if app.normalizedName.contains(query) {
                results.append(app)
            }
        }
        return results
    }

    /// Fuzzy match using Levenshtein distance.
    private func fuzzyMatch(in apps: [IndexedApp], query: String, excluding: Set<String>, limit: Int) -> [IndexedApp] {
        let maxDistance = min(2, max(0, query.count - 1))
        guard maxDistance > 0 else { return [] }

        var results: [IndexedApp] = []
        for app in apps {
            if results.count >= limit { break }
            if excluding.contains(app.bundleID) { continue }
            // Skip short names that are unlikely fuzzy matches
            guard app.normalizedName.count >= query.count - maxDistance else { continue }
            let distance = levenshteinDistance(query, app.normalizedName)
            if distance <= maxDistance {
                results.append(app)
            }
        }
        return results
    }

    /// Pinyin / initials match. Returns ranked UnifiedSearchResults directly so
    /// each app can carry its own match-tier score (prefix > initials > contains).
    private func pinyinMatch(in apps: [IndexedApp], query: String, excluding: Set<String>, limit: Int) -> [UnifiedSearchResult] {
        var matched: [(IndexedApp, MatchType)] = []
        var seenIDs = excluding

        // Pass 1: pinyin prefix (highest)
        for app in apps {
            if matched.count >= limit { break }
            if seenIDs.contains(app.bundleID) { continue }
            if app.pinyin == app.normalizedName { continue } // Latin-only, already covered
            if app.pinyin.hasPrefix(query) {
                matched.append((app, .pinyinPrefix))
                seenIDs.insert(app.bundleID)
            }
        }

        // Pass 2: initials match (whole query equals initials, or prefix of initials)
        if matched.count < limit {
            for app in apps {
                if matched.count >= limit { break }
                if seenIDs.contains(app.bundleID) { continue }
                if !app.initials.isEmpty && app.initials.hasPrefix(query) {
                    matched.append((app, .initials))
                    seenIDs.insert(app.bundleID)
                }
            }
        }

        // Pass 3: pinyin contains
        if matched.count < limit {
            for app in apps {
                if matched.count >= limit { break }
                if seenIDs.contains(app.bundleID) { continue }
                if app.pinyin == app.normalizedName { continue }
                if app.pinyin.contains(query) {
                    matched.append((app, .pinyinContains))
                    seenIDs.insert(app.bundleID)
                }
            }
        }

        return matched.map { buildResult(app: $0.0, matchType: $0.1, queryNormalized: query) }
    }

    // MARK: - Result Building

    /// Match type for ranking.
    private enum MatchType {
        case prefix
        case contains
        case pinyinPrefix
        case initials
        case pinyinContains
        case fuzzy

        var score: Double {
            switch self {
            case .prefix:         return 1.0
            case .contains:       return 0.7
            case .pinyinPrefix:   return 0.65 // below literal contains; above fuzzy
            case .initials:       return 0.55
            case .pinyinContains: return 0.5
            case .fuzzy:          return 0.4
            }
        }
    }

    /// Build a UnifiedSearchResult from an indexed app.
    private func buildResult(app: IndexedApp, matchType: MatchType, queryNormalized: String) -> UnifiedSearchResult {
        let count = useCounts[app.bundleID] ?? 0

        // Compute highlight range in the display name
        var highlightRanges: [NSRange] = []
        let nameNormalized = normalize(app.name)
        if let range = nameNormalized.range(of: queryNormalized) {
            let nsRange = NSRange(range, in: app.name)
            highlightRanges.append(nsRange)
        }

        // Encode useCount into the ID for sorting
        let resultID = "app:\(app.bundleID):\(count)"

        return UnifiedSearchResult(
            id: resultID,
            title: app.name,
            subtitle: app.bundleID,
            icon: app.icon,
            type: .application,
            score: matchType.score,
            highlightRanges: highlightRanges,
            action: .launchApp(bundleID: app.bundleID, path: app.path)
        )
    }

    /// Extract use count encoded in result ID.
    private func extractUseCount(from id: String) -> Int {
        let parts = id.split(separator: ":")
        if parts.count >= 3, let count = Int(parts[2]) {
            return count
        }
        return 0
    }

    /// Extract bundleID encoded in result ID format "app:<bundleID>:<count>".
    private func extractBundleID(from id: String) -> String? {
        let parts = id.split(separator: ":")
        return parts.count >= 2 ? String(parts[1]) : nil
    }

    /// True when the (normalized) query contains only ASCII characters, i.e.
    /// it could plausibly be a pinyin/initials prefix typed by the user.
    private func isASCIIQuery(_ query: String) -> Bool {
        for scalar in query.unicodeScalars where scalar.value > 127 {
            return false
        }
        return !query.isEmpty
    }

    // MARK: - String Helpers

    /// Normalize a string for matching: lowercase + strip diacritics.
    private func normalize(_ string: String) -> String {
        return string.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    }

    // MARK: - Levenshtein Distance

    /// Compute Levenshtein edit distance between two strings.
    private func levenshteinDistance(_ s: String, _ t: String) -> Int {
        let sChars = Array(s)
        let tChars = Array(t)
        let sCount = sChars.count
        let tCount = tChars.count

        guard sCount > 0 else { return tCount }
        guard tCount > 0 else { return sCount }

        // Use two-row optimization to save memory
        var prev = [Int](0...tCount)
        var curr = [Int](repeating: 0, count: tCount + 1)

        for i in 1...sCount {
            curr[0] = i
            for j in 1...tCount {
                let cost = sChars[i - 1] == tChars[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,       // deletion
                    curr[j - 1] + 1,   // insertion
                    prev[j - 1] + cost  // substitution
                )
            }
            swap(&prev, &curr)
        }

        return prev[tCount]
    }

    // MARK: - Periodic Refresh

    private func schedulePeriodicRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.logger.debug("Periodic app index refresh triggered")
            self?.refreshIndexAsync()
        }
    }

    /// Refresh the index in the background.
    private func refreshIndexAsync() {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            await self.buildIndex()
            self.logger.info("Application index refreshed")
        }
    }

    // MARK: - Use Count Tracking

    /// Record that an app was launched via search, incrementing its use count.
    func recordAppLaunch(bundleID: String) {
        useCounts[bundleID, default: 0] += 1
        if let data = try? JSONEncoder().encode(useCounts) {
            UserDefaults.standard.set(data, forKey: useCountKey)
        }
        logger.debug("Recorded app launch for '\(bundleID, privacy: .public)', count=\(self.useCounts[bundleID] ?? 0)")
    }
}

// MARK: - Indexed App (Internal)

/// Internal representation of an indexed application.
private struct IndexedApp {
    let name: String
    let bundleID: String
    let path: URL
    let icon: NSImage?
    let normalizedName: String
    /// Full pinyin (e.g. "weixin" for "微信"). Equals `normalizedName` when
    /// `name` is already Latin.
    let pinyin: String
    /// Pinyin initials (e.g. "wx" for "微信"; "sf" for "Safari" → "safari").
    let initials: String
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the application search index is first built.
    static let appSearchIndexReady = Notification.Name("com.assistant.appSearchIndexReady")
}
