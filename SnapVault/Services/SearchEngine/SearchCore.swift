import Foundation

// MARK: - Assistant MVP Search Core Models

struct SearchResultID: RawRepresentable, Hashable, Codable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

enum SearchResultIcon: Hashable {
    case systemSymbol(String)
    case appIcon(URL)
    case thumbnail(UUID)
    case none
}

struct ApplicationID: RawRepresentable, Hashable, Codable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

struct CommandID: RawRepresentable, Hashable, Codable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

enum SettingsRoute: String, Codable, Hashable {
    case settings
    case permissions
    case clipboardHistory
    case searchSources
    case hotkey
    case screenshot
    case about
}

enum AssistantScreenshotMode: String, Codable, Hashable {
    case region
    case fullScreen
    case window
}

enum SearchAction: Hashable {
    case openApplication(ApplicationID)
    case copyClipboardRecord(UUID)
    case copyText(String)
    case runCommand(CommandID)
    case openSettings(SettingsRoute)
    case startScreenshot(AssistantScreenshotMode)
}

struct SearchResult: Identifiable, Hashable {
    let id: SearchResultID
    let sourceID: SearchSourceID
    let title: String
    let subtitle: String?
    let icon: SearchResultIcon
    let typeLabel: String
    let baseScore: Double
    let matchScore: Double
    let usageScore: Double
    let primaryAction: SearchAction
    let secondaryActions: [SearchAction]

    var finalScore: Double {
        baseScore + matchScore + usageScore
    }
}

struct SearchResponse: Hashable {
    let query: String
    let results: [SearchResult]
    let elapsed: TimeInterval
    let shouldCloseSearchPanel: Bool

    init(query: String, results: [SearchResult], elapsed: TimeInterval, shouldCloseSearchPanel: Bool = false) {
        self.query = query
        self.results = results
        self.elapsed = elapsed
        self.shouldCloseSearchPanel = shouldCloseSearchPanel
    }
}

protocol SearchSource {
    var id: SearchSourceID { get }
    var displayName: String { get }
    var isEnabledInSearch: Bool { get }

    func canSearch(query: String) -> Bool
    func search(query: String) async -> [SearchResult]
}

protocol SearchServiceProtocol {
    func search(query: String) async -> SearchResponse
    func execute(_ action: SearchAction) async throws -> SearchResponse
    func recordSelection(_ result: SearchResult) async
}

protocol SearchActionExecutorProtocol {
    func execute(_ action: SearchAction) async throws
}

protocol SearchUsageStoreProtocol {
    func usageBoost(for resultID: SearchResultID, sourceID: SearchSourceID) async -> Double
    func recordSelection(resultID: SearchResultID, sourceID: SearchSourceID) async
}

protocol SearchScoringProtocol {
    func score(result: SearchResult, query: String) -> Double
}

struct SourcePriority {
    static let application: Double = 100
    static let command: Double = 90
    static let calculator: Double = 85
    static let settings: Double = 80
    static let clipboard: Double = 70

    static func value(for sourceID: SearchSourceID) -> Double {
        switch sourceID {
        case .app:
            return application
        case .command:
            return command
        case .calculator:
            return calculator
        case .settings:
            return settings
        case .clipboard:
            return clipboard
        default:
            return 0
        }
    }
}

struct DefaultSearchScoring: SearchScoringProtocol {
    func score(result: SearchResult, query: String) -> Double {
        result.baseScore + textMatchScore(for: result, query: query) + result.usageScore
    }

    func textMatchScore(for result: SearchResult, query: String) -> Double {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return 0 }

        let title = normalize(result.title)
        let subtitle = normalize(result.subtitle ?? "")

        if title == normalizedQuery { return 30 }
        if title.hasPrefix(normalizedQuery) { return 24 }
        if title.contains(normalizedQuery) { return 18 }
        if subtitle.contains(normalizedQuery) { return 8 }

        let terms = normalizedQuery.split(separator: " ").map(String.init)
        guard !terms.isEmpty else { return 0 }
        let combined = title + "\n" + subtitle
        let matched = terms.filter { combined.contains($0) }.count
        return Double(matched) / Double(terms.count) * 10
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

actor InMemorySearchUsageStore: SearchUsageStoreProtocol {
    private var counts: [SearchResultID: Int] = [:]
    private var lastUsed: [SearchResultID: Date] = [:]
    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    func usageBoost(for resultID: SearchResultID, sourceID: SearchSourceID) async -> Double {
        guard sourceID == .app || sourceID == .command else { return 0 }
        let count = counts[resultID] ?? 0
        let frequencyBoost = min(12.0, log(Double(count) + 1.0) / log(21.0) * 12.0)

        guard let last = lastUsed[resultID] else { return frequencyBoost }
        let age = max(0, now().timeIntervalSince(last))
        let day: TimeInterval = 24 * 60 * 60
        let recencyBoost: Double
        if age <= day {
            recencyBoost = 8
        } else if age <= 7 * day {
            recencyBoost = 5
        } else if age <= 30 * day {
            recencyBoost = 2
        } else {
            recencyBoost = 0
        }
        return frequencyBoost + recencyBoost
    }

    func recordSelection(resultID: SearchResultID, sourceID: SearchSourceID) async {
        guard sourceID == .app || sourceID == .command else { return }
        counts[resultID, default: 0] += 1
        lastUsed[resultID] = now()
    }
}

final class NoopSearchActionExecutor: SearchActionExecutorProtocol {
    func execute(_ action: SearchAction) async throws {
        // The UI/system integration layer supplies a real executor in later tasks.
    }
}

final class SearchService: SearchServiceProtocol {
    static let defaultResultLimit = 12

    private let sources: [SearchSource]
    private let resultLimit: Int
    private let scorer: SearchScoringProtocol
    private let usageStore: SearchUsageStoreProtocol
    private let actionExecutor: SearchActionExecutorProtocol

    init(
        sources: [SearchSource],
        resultLimit: Int = SearchService.defaultResultLimit,
        scorer: SearchScoringProtocol = DefaultSearchScoring(),
        usageStore: SearchUsageStoreProtocol = InMemorySearchUsageStore(),
        actionExecutor: SearchActionExecutorProtocol = NoopSearchActionExecutor()
    ) {
        self.sources = sources
        self.resultLimit = resultLimit
        self.scorer = scorer
        self.usageStore = usageStore
        self.actionExecutor = actionExecutor
    }

    func search(query: String) async -> SearchResponse {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SearchResponse(query: trimmed, results: [], elapsed: 0)
        }

        let start = CFAbsoluteTimeGetCurrent()
        let eligibleSources = sources.filter { $0.isEnabledInSearch && $0.canSearch(query: trimmed) }
        let rawResults = await collectResults(from: eligibleSources, query: trimmed)
        let ranked = await rank(rawResults, query: trimmed)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        return SearchResponse(query: trimmed, results: Array(ranked.prefix(resultLimit)), elapsed: elapsed)
    }

    func execute(_ action: SearchAction) async throws -> SearchResponse {
        try await actionExecutor.execute(action)
        return SearchResponse(query: "", results: [], elapsed: 0, shouldCloseSearchPanel: true)
    }

    func recordSelection(_ result: SearchResult) async {
        await usageStore.recordSelection(resultID: result.id, sourceID: result.sourceID)
    }

    private func collectResults(from sources: [SearchSource], query: String) async -> [SearchResult] {
        await withTaskGroup(of: [SearchResult].self) { group in
            for source in sources {
                group.addTask {
                    await source.search(query: query)
                }
            }

            var all: [SearchResult] = []
            for await results in group {
                all.append(contentsOf: results)
            }
            return all
        }
    }

    private func rank(_ results: [SearchResult], query: String) async -> [SearchResult] {
        var adjusted: [SearchResult] = []
        adjusted.reserveCapacity(results.count)

        for result in results {
            let sourceBase = SourcePriority.value(for: result.sourceID)
            let base = result.baseScore > 0 ? result.baseScore : sourceBase
            let match = result.matchScore > 0 ? result.matchScore : scorer.score(result: result, query: query) - result.baseScore - result.usageScore
            let usage = result.usageScore + (await usageStore.usageBoost(for: result.id, sourceID: result.sourceID))
            adjusted.append(SearchResult(
                id: result.id,
                sourceID: result.sourceID,
                title: result.title,
                subtitle: result.subtitle,
                icon: result.icon,
                typeLabel: result.typeLabel,
                baseScore: base,
                matchScore: max(0, match),
                usageScore: usage,
                primaryAction: result.primaryAction,
                secondaryActions: result.secondaryActions
            ))
        }

        return adjusted.sorted { lhs, rhs in
            if lhs.finalScore != rhs.finalScore { return lhs.finalScore > rhs.finalScore }
            if lhs.baseScore != rhs.baseScore { return lhs.baseScore > rhs.baseScore }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

// MARK: - Default trigger rule helpers

extension SearchSource where Self: AnyObject {
    func isNonEmptyQuery(_ query: String) -> Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum SearchTriggerRules {
    static func standardMinimumLength(sourceID: SearchSourceID, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        switch sourceID {
        case .app, .command, .settings:
            return trimmed.count >= 1
        case .clipboard:
            return trimmed.count >= 2
        default:
            return false
        }
    }
}
