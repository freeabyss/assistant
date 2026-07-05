import AppKit
import Foundation

/// Supplies the command bar's *empty-query* home content (T-011 / PRD §9.3 / D-120):
/// a "最近使用" section (recently launched apps / executed commands, ordered by
/// `UsageStat.lastUsedAt`) and a "收藏" section (pinned / favorited clipboard
/// records).
///
/// This is deliberately a thin read-only aggregator: it reuses the existing
/// `UsageStatRepository` (Core Data usage stats), the live `AppSource` index (to
/// resolve an app's current path / display name), the closed command catalog, and
/// the clipboard repository. It produces plain `SearchResult` values so the view
/// layer renders home rows exactly like search-result rows.
protocol CommandBarHomeProviding {
    func recentResults(limit: Int) async -> [SearchResult]
    func favoriteResults(limit: Int) async -> [SearchResult]
}

@MainActor
final class CommandBarHomeProvider: CommandBarHomeProviding {
    private let usageRepository: UsageStatRepositoryProtocol
    private let appSource: AppSourceProtocol
    private let clipboardRepository: ClipboardRepositoryProtocol
    private let commandLookup: [CommandID: AssistantCommandDefinition]

    init(
        usageRepository: UsageStatRepositoryProtocol,
        appSource: AppSourceProtocol,
        clipboardRepository: ClipboardRepositoryProtocol,
        commands: [AssistantCommandDefinition] = AssistantCommandCatalog.commands
    ) {
        self.usageRepository = usageRepository
        self.appSource = appSource
        self.clipboardRepository = clipboardRepository
        self.commandLookup = Dictionary(uniqueKeysWithValues: commands.map { ($0.id, $0) })
    }

    // MARK: - Recent

    func recentResults(limit: Int) async -> [SearchResult] {
        guard limit > 0 else { return [] }
        // Over-fetch a little so stale IDs (uninstalled apps / unknown commands)
        // that no longer resolve don't shrink the visible list below `limit`.
        let stats = await usageRepository.recentlyUsed(limit: limit * 3)
        var results: [SearchResult] = []
        for stat in stats {
            guard let result = recentResult(for: stat) else { continue }
            results.append(result)
            if results.count >= limit { break }
        }
        return results
    }

    private func recentResult(for stat: UsageStatSnapshot) -> SearchResult? {
        switch stat.targetType {
        case UsageStatRepository.applicationTargetType:
            let appID = ApplicationID(rawValue: stat.targetID)
            guard let item = appSource.application(for: appID) else { return nil }
            let title = item.localizedName ?? item.displayName
            return SearchResult(
                id: SearchResultID(rawValue: "app:\(item.targetID)"),
                sourceID: .app,
                title: title,
                subtitle: item.path.path,
                icon: .appIcon(item.path),
                typeLabel: L10n.localized("searchPanel.type.application"),
                baseScore: SourcePriority.application,
                matchScore: 0,
                usageScore: 0,
                primaryAction: .openApplication(item.id),
                secondaryActions: []
            )
        case UsageStatRepository.commandTargetType:
            guard let command = commandLookup[CommandID(rawValue: stat.targetID)] else { return nil }
            return SearchResult(
                id: SearchResultID(rawValue: "command:\(command.id.rawValue)"),
                sourceID: .command,
                title: command.chineseName,
                subtitle: command.englishName,
                icon: .systemSymbol(command.iconSystemName),
                typeLabel: L10n.localized("searchPanel.type.command"),
                baseScore: SourcePriority.command,
                matchScore: 0,
                usageScore: 0,
                primaryAction: .runCommand(command.id),
                secondaryActions: []
            )
        default:
            return nil
        }
    }

    // MARK: - Favorites

    func favoriteResults(limit: Int) async -> [SearchResult] {
        guard limit > 0 else { return [] }
        let history: [ClipboardRecordSnapshot]
        do {
            history = try await clipboardRepository.fetchHistory(filter: ClipboardHistoryFilter(includePinned: true))
        } catch {
            return []
        }
        return history
            .filter { $0.isPinned }
            .prefix(limit)
            .map { snapshot in
                SearchResult(
                    id: SearchResultID(rawValue: "clipboard:\(snapshot.id.uuidString)"),
                    sourceID: .clipboard,
                    title: favoriteTitle(for: snapshot),
                    subtitle: favoriteSubtitle(for: snapshot),
                    icon: icon(for: snapshot.contentType),
                    typeLabel: L10n.localized("searchPanel.type.clipboard"),
                    baseScore: SourcePriority.clipboard,
                    matchScore: 0,
                    usageScore: 0,
                    primaryAction: .copyClipboardRecord(snapshot.id),
                    secondaryActions: []
                )
            }
    }

    private func favoriteTitle(for snapshot: ClipboardRecordSnapshot) -> String {
        let raw = snapshot.summary
            ?? snapshot.plainText
            ?? snapshot.fileDisplayName
            ?? L10n.localized("searchPanel.type.clipboard")
        let collapsed = raw
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.isEmpty ? L10n.localized("searchPanel.type.clipboard") : collapsed
    }

    private func favoriteSubtitle(for snapshot: ClipboardRecordSnapshot) -> String {
        "\(label(for: snapshot.contentType)) · \(L10n.relativeTime(from: snapshot.updatedAt))"
    }

    private func label(for type: ClipboardContentType) -> String {
        switch type {
        case .text: return L10n.localized("content.text")
        case .richText: return L10n.localized("content.rtf")
        case .image: return L10n.localized("content.image")
        case .file: return L10n.localized("content.file")
        }
    }

    private func icon(for type: ClipboardContentType) -> SearchResultIcon {
        switch type {
        case .text: return .systemSymbol("doc.text")
        case .richText: return .systemSymbol("doc.richtext")
        case .image: return .systemSymbol("photo")
        case .file: return .systemSymbol("doc")
        }
    }
}
