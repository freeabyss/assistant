import Foundation

struct SettingsSearchRoute: Identifiable, Hashable {
    let id: SettingsRoute
    let title: String
    let aliases: [String]
    let pinyin: String
    let initials: String
    let subtitle: String
    let iconSystemName: String
}

final class SettingsSource: SearchSource {
    let id = SearchSourceID.settings
    let displayName = "Settings"

    private let staticIsEnabledInSearch: Bool
    private let settingsService: SettingsServiceProtocol?

    var isEnabledInSearch: Bool {
        staticIsEnabledInSearch
    }

    let routes: [SettingsSearchRoute]

    init(
        isEnabledInSearch: Bool = true,
        settingsService: SettingsServiceProtocol? = nil,
        routes: [SettingsSearchRoute] = SettingsSource.defaultRoutes
    ) {
        self.staticIsEnabledInSearch = isEnabledInSearch
        self.settingsService = settingsService
        self.routes = routes
    }

    func canSearch(query: String) -> Bool {
        SearchTriggerRules.standardMinimumLength(sourceID: id, query: query)
    }

    func search(query: String) async -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard await resolvedIsEnabledInSearch() else { return [] }

        return routes.compactMap { route -> (SettingsSearchRoute, SearchTextMatcher.MatchKind)? in
            let candidate = SearchTextCandidate(
                text: route.title,
                aliases: route.aliases,
                pinyin: route.pinyin,
                initials: route.initials
            )
            guard let kind = SearchTextMatcher.match(query: trimmed, candidate: candidate) else { return nil }
            return (route, kind)
        }
        .sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            return lhs.0.title.localizedCaseInsensitiveCompare(rhs.0.title) == .orderedAscending
        }
        .map { route, matchKind in
            SearchResult(
                id: SearchResultID(rawValue: "setting:\(route.id.rawValue)"),
                sourceID: id,
                title: route.title,
                subtitle: route.subtitle,
                icon: .systemSymbol(route.iconSystemName),
                typeLabel: "Settings",
                baseScore: SourcePriority.settings,
                matchScore: matchKind.score,
                usageScore: 0,
                primaryAction: .openSettings(route.id),
                secondaryActions: []
            )
        }
    }

    private func resolvedIsEnabledInSearch() async -> Bool {
        guard let settingsService else { return staticIsEnabledInSearch }
        return (try? await settingsService.value(for: .settingsSourceEnabled, as: Bool.self)) ?? true
    }

    static let defaultRoutes: [SettingsSearchRoute] = [
        .make(.settings, title: "设置", english: "Settings", aliases: ["偏好设置", "preferences", "prefs", "配置", "configuration"], icon: "gearshape"),
        .make(.permissions, title: "权限", english: "Permissions", aliases: ["授权", "privacy", "screen recording", "accessibility", "系统权限", "隐私"], icon: "lock.shield"),
        .make(.clipboardHistory, title: "剪贴板历史", english: "Clipboard History", aliases: ["剪贴板", "clipboard", "history", "剪贴板记录", "clipboard records"], icon: "clipboard"),
        .make(.searchSources, title: "搜索源设置", english: "Search Sources", aliases: ["搜索来源", "provider", "providers", "sources", "show in search", "搜索源开关"], icon: "magnifyingglass"),
        .make(.hotkey, title: "快捷键设置", english: "Hotkey Settings", aliases: ["快捷键", "shortcut", "shortcuts", "keyboard", "hotkey"], icon: "keyboard"),
        .make(.screenshot, title: "截图设置", english: "Screenshot Settings", aliases: ["截图", "screen capture", "capture", "保存目录", "save directory", "screenshots"], icon: "camera.viewfinder"),
        .make(.about, title: "关于", english: "About", aliases: ["版本", "隐私政策", "about", "privacy", "license", "许可证"], icon: "info.circle")
    ]
}

private extension SettingsSearchRoute {
    static func make(_ route: SettingsRoute, title: String, english: String, aliases: [String], icon: String) -> SettingsSearchRoute {
        let allAliases = [english] + aliases
        return SettingsSearchRoute(
            id: route,
            title: title,
            aliases: allAliases,
            pinyin: PinyinHelper.toPinyin(title),
            initials: PinyinHelper.toInitials(title),
            subtitle: english,
            iconSystemName: icon
        )
    }
}
