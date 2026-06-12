import Foundation
import AppKit
import os.log

/// Search source for built-in system commands (sleep, restart, shutdown, lock, ...).
///
/// Holds a fixed in-memory catalog of commands with English primary keywords
/// and bilingual (Chinese / English) aliases. Matching strategy: prefix > contains > alias.
final class SystemCommandSource: UnifiedSearchSource {
    let sourceType: SearchResultType = .systemCommand
    private let logger = Logger.search

    // MARK: - Catalog Entry

    /// Internal catalog entry for a system command.
    private struct CommandEntry {
        let command: SystemCommand
        /// Primary English keyword used for prefix matching ("sleep", "restart"...).
        let primaryKeyword: String
        /// Alternate keywords / Chinese names ("睡眠", "重启", ...). Match is case + diacritic insensitive.
        let aliases: [String]
        /// Localized display title shown in the result row.
        let title: String
        /// Short description shown as subtitle.
        let subtitle: String
        /// SF Symbol icon name.
        let iconName: String
    }

    private let catalog: [CommandEntry]

    // MARK: - Init

    init() {
        self.catalog = [
            CommandEntry(
                command: .sleep,
                primaryKeyword: "sleep",
                aliases: ["睡眠", "休眠", "sleep", "zzz"],
                title: L10n.localized("system.sleep.title"),
                subtitle: L10n.localized("system.sleep.subtitle"),
                iconName: "moon.fill"
            ),
            CommandEntry(
                command: .restart,
                primaryKeyword: "restart",
                aliases: ["重启", "重新启动", "restart", "reboot"],
                title: L10n.localized("system.restart.title"),
                subtitle: L10n.localized("system.restart.subtitle"),
                iconName: "arrow.clockwise.circle.fill"
            ),
            CommandEntry(
                command: .shutdown,
                primaryKeyword: "shutdown",
                aliases: ["关机", "关闭", "shutdown", "shut down", "power off", "poweroff"],
                title: L10n.localized("system.shutdown.title"),
                subtitle: L10n.localized("system.shutdown.subtitle"),
                iconName: "power"
            ),
            CommandEntry(
                command: .lock,
                primaryKeyword: "lock",
                aliases: ["锁定", "锁屏", "lock", "lock screen"],
                title: L10n.localized("system.lock.title"),
                subtitle: L10n.localized("system.lock.subtitle"),
                iconName: "lock.fill"
            ),
            CommandEntry(
                command: .lockScreen,
                primaryKeyword: "lockscreen",
                aliases: ["锁屏", "lockscreen", "lock screen"],
                title: L10n.localized("system.lockScreen.title"),
                subtitle: L10n.localized("system.lockScreen.subtitle"),
                iconName: "lock.display"
            ),
            CommandEntry(
                command: .emptyTrash,
                primaryKeyword: "emptytrash",
                aliases: ["清空废纸篓", "清空垃圾桶", "empty trash", "emptytrash", "trash"],
                title: L10n.localized("system.emptyTrash.title"),
                subtitle: L10n.localized("system.emptyTrash.subtitle"),
                iconName: "trash.fill"
            ),
            CommandEntry(
                command: .showDesktop,
                primaryKeyword: "showdesktop",
                aliases: ["显示桌面", "桌面", "show desktop", "showdesktop", "desktop"],
                title: L10n.localized("system.showDesktop.title"),
                subtitle: L10n.localized("system.showDesktop.subtitle"),
                iconName: "macwindow.on.rectangle"
            )
        ]
    }

    // MARK: - SearchSource

    func search(query: String, limit: Int) async throws -> [UnifiedSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let normalizedQuery = normalize(trimmed)

        var scored: [Scored] = []

        for entry in catalog {
            let candidate = SearchTextCandidate(
                text: entry.primaryKeyword,
                aliases: entry.aliases + [entry.title],
                pinyin: PinyinHelper.toPinyin(entry.title),
                initials: PinyinHelper.toInitials(entry.title)
            )
            if let matchKind = SearchTextMatcher.match(query: normalizedQuery, candidate: candidate) {
                let range = highlightRange(in: entry.title, queryNormalized: normalizedQuery)
                scored.append(Scored(entry: entry, matchKind: matchKind, highlightRange: range))
            }
        }

        // Sort by match quality first, then alphabetically by title.
        scored.sort { lhs, rhs in
            if lhs.matchKind != rhs.matchKind {
                return lhs.matchKind < rhs.matchKind
            }
            return lhs.entry.title.localizedCaseInsensitiveCompare(rhs.entry.title) == .orderedAscending
        }

        let truncated = Array(scored.prefix(limit))
        let results = truncated.map { buildResult(scored: $0) }

        logger.info("System command search '\(trimmed, privacy: .public)': \(results.count) results")
        return results
    }

    // MARK: - Result Building

    /// Scored entry shared between `search()` and `buildResult()`.
    private struct Scored {
        let entry: CommandEntry
        let matchKind: SearchTextMatcher.MatchKind
        let highlightRange: NSRange?
    }

    private func buildResult(scored: Scored) -> UnifiedSearchResult {
        let entry = scored.entry
        let icon = NSImage(systemSymbolName: entry.iconName, accessibilityDescription: entry.title)
        icon?.size = NSSize(width: 24, height: 24)

        // Normalize the shared match-kind score into the legacy 0...1 unified result range.
        let relevance = scored.matchKind.score / SearchTextMatcher.MatchKind.exact.score

        return UnifiedSearchResult(
            id: "system:\(entry.command.rawValue)",
            title: entry.title,
            subtitle: entry.subtitle,
            icon: icon,
            type: .systemCommand,
            score: relevance,
            highlightRanges: scored.highlightRange.map { [$0] } ?? [],
            action: .runSystemCommand(entry.command)
        )
    }

    // MARK: - Helpers

    /// Lowercase + strip diacritics for case- and accent-insensitive matching.
    private func normalize(_ string: String) -> String {
        return string.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    }

    /// Compute the highlight NSRange in the display title for the matched query, if any.
    private func highlightRange(in title: String, queryNormalized: String) -> NSRange? {
        let titleNormalized = normalize(title)
        guard let range = titleNormalized.range(of: queryNormalized) else {
            return nil
        }
        return NSRange(range, in: title)
    }
}
