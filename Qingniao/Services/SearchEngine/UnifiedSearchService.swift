import Foundation
import os.log

// MARK: - Protocol

/// Protocol for the unified search service.
protocol UnifiedSearchServiceProtocol {
    /// Register a search source.
    func registerSource(_ source: UnifiedSearchSource)

    /// Search all registered sources in parallel.
    /// - Parameters:
    ///   - query: Search query string
    ///   - limit: Maximum results per source
    /// - Returns: Unified response with results grouped by type
    func search(query: String, limit: Int) async throws -> UnifiedSearchResponse

    /// Record a user selection for ranking improvement.
    func recordSelection(resultID: String)
}

// MARK: - Implementation

/// Unified search service that aggregates results from multiple sources.
///
/// Searches all registered sources in parallel using TaskGroup,
/// merges results with a weighted scoring algorithm, and returns
/// results grouped by type.
final class UnifiedSearchService: UnifiedSearchServiceProtocol {
    private let logger = Logger.search
    private var sources: [UnifiedSearchSource] = []
    private let sourcesLock = NSLock()

    /// User selection frequency for ranking boost.
    /// Keyed by result ID, stores selection count.
    private let selectionKey = "unified_search_selections"
    private var selectionCounts: [String: Int] = [:]

    // MARK: - Scoring Weights

    /// Weight for source type priority (application > file > clipboard).
    private let typeWeight: Double = 0.3
    /// Weight for source relevance score.
    private let relevanceWeight: Double = 0.4
    /// Weight for user selection frequency.
    private let frequencyWeight: Double = 0.3

    // MARK: - Init

    init() {
        loadSelectionCounts()
    }

    // MARK: - UnifiedSearchServiceProtocol

    func registerSource(_ source: UnifiedSearchSource) {
        sourcesLock.lock()
        defer { sourcesLock.unlock() }
        sources.append(source)
        logger.info("Registered search source: \(String(describing: source.sourceType))")
    }

    func search(query: String, limit: Int) async throws -> UnifiedSearchResponse {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return UnifiedSearchResponse(applications: [], files: [], clipboard: [], systemCommands: [], calculations: [], conversions: [], totalCount: 0, elapsed: 0)
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        // Capture sources snapshot
        sourcesLock.lock()
        let currentSources = sources
        sourcesLock.unlock()

        // Search all sources in parallel
        var allResults: [UnifiedSearchResult] = []
        try await withThrowingTaskGroup(of: [UnifiedSearchResult].self) { group in
            for source in currentSources {
                group.addTask {
                    do {
                        let results = try await source.search(query: trimmed, limit: limit)
                        Logger.search.info("Source \(String(describing: source.sourceType)) returned \(results.count) results")
                        return results
                    } catch {
                        // Log but don't fail the entire search if one source fails
                        Logger.search.error("Search source \(String(describing: source.sourceType)) failed: \(error.localizedDescription, privacy: .public)")
                        return []
                    }
                }
            }
            for try await results in group {
                allResults.append(contentsOf: results)
            }
        }

        // Apply score aggregation
        let scoredResults = allResults.map { result -> UnifiedSearchResult in
            let aggregatedScore = aggregateScore(for: result)
            return UnifiedSearchResult(
                id: result.id,
                title: result.title,
                subtitle: result.subtitle,
                icon: result.icon,
                type: result.type,
                score: aggregatedScore,
                highlightRanges: result.highlightRanges,
                action: result.action
            )
        }

        // Sort by aggregated score descending
        let sorted = scoredResults.sorted { $0.score > $1.score }

        // Group by type
        let applications = sorted.filter { $0.type == .application }
        let files = sorted.filter { $0.type == .file }
        let clipboard = sorted.filter { $0.type == .clipboard }
        let systemCommands = sorted.filter { $0.type == .systemCommand }
        let calculations = sorted.filter { $0.type == .calculator }
        let conversions = sorted.filter { $0.type == .unitConversion }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // Convert to ms

        logger.info("Unified search '\(trimmed, privacy: .public)': \(applications.count) apps, \(files.count) files, \(clipboard.count) clipboard, \(systemCommands.count) system, \(calculations.count) calc, \(conversions.count) convert in \(String(format: "%.1f", elapsed))ms")

        return UnifiedSearchResponse(
            applications: applications,
            files: files,
            clipboard: clipboard,
            systemCommands: systemCommands,
            calculations: calculations,
            conversions: conversions,
            totalCount: sorted.count,
            elapsed: elapsed
        )
    }

    func recordSelection(resultID: String) {
        selectionCounts[resultID, default: 0] += 1
        saveSelectionCounts()
        logger.debug("Recorded selection for '\(resultID, privacy: .public)', count=\(self.selectionCounts[resultID] ?? 0)")
    }

    // MARK: - Score Aggregation

    /// Compute aggregated score: typeWeight * typePriority + relevanceWeight * sourceScore + frequencyWeight * frequencyBoost
    private func aggregateScore(for result: UnifiedSearchResult) -> Double {
        let typePriority = typePriorityScore(for: result.type)
        let relevance = result.score
        let frequency = frequencyBoost(for: result.id)

        return typeWeight * typePriority + relevanceWeight * relevance + frequencyWeight * frequency
    }

    /// Type priority: calculator pinned to the top, then apps, system commands, files, clipboard.
    private func typePriorityScore(for type: SearchResultType) -> Double {
        switch type {
        case .calculator: return 1.0
        case .application: return 1.0
        case .unitConversion: return 0.95
        case .systemCommand: return 0.8
        case .file: return 0.7
        case .clipboard: return 0.5
        }
    }

    /// Frequency boost based on user selection history.
    /// Returns a value between 0 and 1, with diminishing returns.
    private func frequencyBoost(for resultID: String) -> Double {
        let count = selectionCounts[resultID] ?? 0
        guard count > 0 else { return 0 }
        // Logarithmic scaling: 1 selection = 0.3, 5 = 0.6, 20 = 0.85, 100 = 1.0
        return min(1.0, log(Double(count) + 1) / log(101))
    }

    // MARK: - Persistence

    private func loadSelectionCounts() {
        if let data = UserDefaults.standard.data(forKey: selectionKey),
           let counts = try? JSONDecoder().decode([String: Int].self, from: data) {
            selectionCounts = counts
        }
    }

    private func saveSelectionCounts() {
        if let data = try? JSONEncoder().encode(selectionCounts) {
            UserDefaults.standard.set(data, forKey: selectionKey)
        }
    }
}
