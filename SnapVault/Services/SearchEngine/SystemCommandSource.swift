import Foundation
import AppKit
import os.log

/// Search source for built-in system commands (sleep, restart, shutdown, lock, ...).
///
/// Holds a fixed in-memory catalog of commands with English primary keywords
/// and bilingual (Chinese / English) aliases. Matching strategy: prefix > contains > alias.
final class SystemCommandSource: SearchSource {
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

        // matchPriority: 0 = prefix on primary, 1 = contains on primary, 2 = alias match
        var scored: [Scored] = []

        for entry in catalog {
            let primaryNormalized = normalize(entry.primaryKeyword)

            // 1. Prefix match on primary keyword (highest priority)
            if primaryNormalized.hasPrefix(normalizedQuery) {
                let range = highlightRange(in: entry.title, queryNormalized: normalizedQuery)
                scored.append(Scored(entry: entry, priority: 0, highlightRange: range))
                continue
            }

            // 2. Contains match on primary keyword
            if primaryNormalized.contains(normalizedQuery) {
                let range = highlightRange(in: entry.title, queryNormalized: normalizedQuery)
                scored.append(Scored(entry: entry, priority: 1, highlightRange: range))
                continue
            }

            // 3. Alias match (any alias has prefix OR contains the query)
            var aliasMatched = false
            for alias in entry.aliases {
                let aliasNormalized = normalize(alias)
                if aliasNormalized.hasPrefix(normalizedQuery) || aliasNormalized.contains(normalizedQuery) {
                    aliasMatched = true
                    break
                }
            }
            if aliasMatched {
                let range = highlightRange(in: entry.title, queryNormalized: normalizedQuery)
                scored.append(Scored(entry: entry, priority: 2, highlightRange: range))
            }
        }

        // Sort by priority ascending (prefix first), then alphabetically by title
        scored.sort { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
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
        let priority: Int
        let highlightRange: NSRange?
    }

    private func buildResult(scored: Scored) -> UnifiedSearchResult {
        let entry = scored.entry
        let icon = NSImage(systemSymbolName: entry.iconName, accessibilityDescription: entry.title)
        icon?.size = NSSize(width: 24, height: 24)

        // Score: prefix 1.0, contains 0.75, alias 0.6
        let relevance: Double
        switch scored.priority {
        case 0: relevance = 1.0
        case 1: relevance = 0.75
        default: relevance = 0.6
        }

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
