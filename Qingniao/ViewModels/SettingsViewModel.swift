import AppKit
import Foundation
import KeyboardShortcuts
import ServiceManagement
import os.log

/// Notification posted when Assistant MVP settings change so long-running services
/// can reload their runtime state without waiting for app restart.
extension Notification.Name {
    static let settingsDidChange = Notification.Name("com.assistant.settingsDidChange")
    static let openManagementCenter = Notification.Name("com.assistant.openManagementCenter")
}

enum ManagementCenterPage: String, CaseIterable, Identifiable, Hashable {
    case overview
    case clipboard
    case settings
    case permissions
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return L10n.localized("management.page.overview")
        case .clipboard: return L10n.localized("management.page.clipboard")
        case .settings: return L10n.localized("management.page.settings")
        case .permissions: return L10n.localized("management.page.permissions")
        case .about: return L10n.localized("management.page.about")
        }
    }

    var iconName: String {
        switch self {
        case .overview: return "sparkles"
        case .clipboard: return "clipboard"
        case .settings: return "slider.horizontal.3"
        case .permissions: return "lock.shield"
        case .about: return "info.circle"
        }
    }
}

@MainActor
struct SearchSourceToggle: Identifiable, Hashable {
    let id: SearchSourceID
    let settingKey: SettingKey
    let title: String
    let subtitle: String
    let iconName: String
    var isEnabled: Bool
}

/// ViewModel for US-015 Management Center.
///
/// Uses the Assistant MVP Core Data `SettingsService`, `PermissionService`, and
/// `SearchBlacklistRepository`; legacy GRDB settings are intentionally not used
/// for new management-center settings.
@MainActor
final class SettingsViewModel: ObservableObject {
    private let settingsService: SettingsServiceProtocol
    private let blacklistRepository: SearchBlacklistRepositoryProtocol
    private let permissionService: PermissionServiceProtocol
    private let launchAtLoginService: LaunchAtLoginServiceProtocol
    private let notificationCenter: NotificationCenter
    private let userDefaults: UserDefaults
    private let dataManagementService: DataManagementService
    private let conflictDetector: HotkeyConflictDetector
    private let logger = Logger.app

    @Published var selectedPage: ManagementCenterPage = .overview
    @Published var sourceToggles: [SearchSourceToggle] = SettingsViewModel.defaultSearchSourceToggles
    @Published var clipboardEnabled = true
    @Published var clipboardRetention: ClipboardRetention = .thirtyDays
    @Published var screenshotSaveDirectory: URL = URL(fileURLWithPath: ("~/Pictures/Screenshots" as NSString).expandingTildeInPath)
    @Published var launchAtLoginEnabled = true
    @Published var languageMode: LanguageMode = .followSystem
    @Published var blacklistItems: [SearchBlacklistItemSnapshot] = []
    @Published var permissionStatuses: [PermissionKind: PermissionStatus] = Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0, .unknown) })

    @Published var newBlacklistSourceID = SearchSourceID.app.rawValue
    @Published var newBlacklistResultID = ""
    @Published var newBlacklistTitle = ""
    @Published var newBlacklistType = "application"

    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var showDirectoryImporter = false
    @Published var showLanguageRestartAlert = false

    /// v1.2 (T-003): drives the "清空所有数据" confirmation + post-reset restart prompt
    /// on the settings Data page (T-013 UI binds to these).
    @Published var showResetAllDataConfirmation = false
    @Published var showResetAllDataRestartAlert = false
    @Published var isResettingAllData = false

    /// v1.2 (T-008): per-shortcut conflict warnings surfaced to the settings
    /// shortcut rows (T-013 UI binds to these). Empty when no conflicts. Keyed by
    /// the `KeyboardShortcuts.Name`; the value is a localized, user-facing message.
    @Published var conflictWarnings: [KeyboardShortcuts.Name: String] = [:]

    var enabledSourceNames: String {
        let names = sourceToggles.filter(\.isEnabled).map(\.title)
        return names.isEmpty ? L10n.localized("management.overview.noSources") : names.joined(separator: ", ")
    }

    var searchHotkeyDescription: String {
        KeyboardShortcuts.Shortcut(name: .togglePanel)?.description ?? "⌥ Space"
    }

    var permissionSummary: String {
        let authorized = PermissionKind.allCases.filter { permissionStatuses[$0]?.isAuthorized == true }.count
        return L10n.localized("management.overview.permissionsCount", authorized, PermissionKind.allCases.count)
    }

    static let retentionOptions: [ClipboardRetention] = [.sevenDays, .thirtyDays, .ninetyDays, .forever]
    static let languageOptions: [LanguageMode] = [.followSystem, .simplifiedChinese, .english]

    static let sourceOptions: [(id: SearchSourceID, label: String)] = [
        (.app, "AppSource"),
        (.command, "CommandSource"),
        (.calculator, "CalculatorSource"),
        (.settings, "SettingsSource"),
        (.clipboard, "ClipboardSource")
    ]

    private static let defaultSearchSourceToggles: [SearchSourceToggle] = [
        SearchSourceToggle(id: .app, settingKey: .appSourceEnabled, title: L10n.localized("management.source.app"), subtitle: L10n.localized("management.source.app.subtitle"), iconName: "app", isEnabled: true),
        SearchSourceToggle(id: .command, settingKey: .commandSourceEnabled, title: L10n.localized("management.source.command"), subtitle: L10n.localized("management.source.command.subtitle"), iconName: "terminal", isEnabled: true),
        SearchSourceToggle(id: .calculator, settingKey: .calculatorSourceEnabled, title: L10n.localized("management.source.calculator"), subtitle: L10n.localized("management.source.calculator.subtitle"), iconName: "function", isEnabled: true),
        SearchSourceToggle(id: .settings, settingKey: .settingsSourceEnabled, title: L10n.localized("management.source.settings"), subtitle: L10n.localized("management.source.settings.subtitle"), iconName: "gearshape", isEnabled: true),
        SearchSourceToggle(id: .file, settingKey: .fileSourceEnabled, title: L10n.localized("management.source.file"), subtitle: L10n.localized("management.source.file.subtitle"), iconName: "doc", isEnabled: true),
        SearchSourceToggle(id: .clipboard, settingKey: .clipboardShowInSearch, title: L10n.localized("management.source.clipboard"), subtitle: L10n.localized("management.source.clipboard.subtitle"), iconName: "clipboard", isEnabled: true)
    ]

    init(
        settingsService: SettingsServiceProtocol = SettingsService(persistence: .shared),
        blacklistRepository: SearchBlacklistRepositoryProtocol = SearchBlacklistRepository(persistence: .shared),
        permissionService: PermissionServiceProtocol = PermissionService(),
        launchAtLoginService: LaunchAtLoginServiceProtocol = LaunchAtLoginService(),
        notificationCenter: NotificationCenter = .default,
        userDefaults: UserDefaults = .standard,
        dataManagementService: DataManagementService = DataManagementService(),
        conflictDetector: HotkeyConflictDetector = HotkeyConflictDetector()
    ) {
        self.settingsService = settingsService
        self.blacklistRepository = blacklistRepository
        self.permissionService = permissionService
        self.launchAtLoginService = launchAtLoginService
        self.notificationCenter = notificationCenter
        self.userDefaults = userDefaults
        self.dataManagementService = dataManagementService
        self.conflictDetector = conflictDetector
    }

    func load() async {
        await loadSettings()
        await reloadBlacklist()
        await refreshPermissions()
        refreshShortcutConflicts()
    }

    func select(route: SettingsRoute) {
        switch route {
        case .settings, .searchSources, .hotkey, .screenshot:
            selectedPage = .settings
        case .permissions:
            selectedPage = .permissions
        case .clipboardHistory:
            selectedPage = .clipboard
        case .about:
            selectedPage = .about
        }
    }

    func select(page: ManagementCenterPage) {
        selectedPage = page
    }

    func saveSettings() async {
        do {
            for toggle in sourceToggles {
                try await settingsService.set(toggle.isEnabled, for: toggle.settingKey)
            }
            try await settingsService.set(clipboardEnabled, for: .clipboardEnabled)
            try await settingsService.set(clipboardRetention, for: .clipboardRetention)
            try await settingsService.set(screenshotSaveDirectory, for: .screenshotSaveDirectory)
            try await settingsService.set(launchAtLoginEnabled, for: .launchAtLoginEnabled)
            try await settingsService.set(languageMode, for: .languageMode)
            try launchAtLoginService.setEnabled(launchAtLoginEnabled)
            applyLanguagePreference()
            notificationCenter.post(name: .settingsDidChange, object: nil)
            statusMessage = L10n.localized("management.settings.saved")
        } catch {
            logger.error("Failed to save management center settings: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    func resetSettingsToDefaults() async {
        do {
            for key in [
                SettingKey.appSourceEnabled,
                .commandSourceEnabled,
                .calculatorSourceEnabled,
                .settingsSourceEnabled,
                .fileSourceEnabled,
                .clipboardShowInSearch,
                .clipboardEnabled,
                .clipboardRetention,
                .screenshotSaveDirectory,
                .launchAtLoginEnabled,
                .languageMode
            ] {
                try await settingsService.reset(key: key)
            }
            await loadSettings()
            notificationCenter.post(name: .settingsDidChange, object: nil)
            statusMessage = L10n.localized("management.settings.reset")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateScreenshotDirectory(_ directory: URL) {
        screenshotSaveDirectory = directory
    }

    // MARK: - Shortcut conflict detection (T-008)

    /// Re-scan all managed global shortcuts and publish per-name conflict
    /// warnings. Call after `load()`, after a recorder change, or after reset.
    func refreshShortcutConflicts() {
        conflictDetector.scan()
        conflictWarnings = conflictDetector.conflictMessages
    }

    /// Whether the given shortcut currently conflicts with a system or internal
    /// binding. T-013 uses this to color the row red / show a warning.
    func isShortcutConflict(_ name: KeyboardShortcuts.Name) -> Bool {
        conflictDetector.conflictingNames.contains(name)
    }

    /// Localized conflict message for a shortcut, or `nil` when there is none.
    func conflictMessage(for name: KeyboardShortcuts.Name) -> String? {
        conflictWarnings[name]
    }

    /// "重置为默认": reset every managed global shortcut to its default binding,
    /// then refresh conflict state.
    func resetAllShortcutsToDefaults() {
        KeyboardShortcuts.reset(KeyboardShortcuts.Name.managedGlobalShortcuts)
        refreshShortcutConflicts()
        statusMessage = L10n.localized("management.shortcuts.reset")
    }

    // MARK: - Data page actions (T-003 / T-013)

    /// User tapped "清空所有数据" — request the two-step confirmation before wiping.
    func requestResetAllData() {
        showResetAllDataConfirmation = true
    }

    /// Confirmed "清空所有数据": deletes the store, resource files, and UserDefaults
    /// domain, then surfaces the restart prompt. On failure sets `errorMessage`.
    func confirmResetAllData() async {
        showResetAllDataConfirmation = false
        isResettingAllData = true
        defer { isResettingAllData = false }
        do {
            try await dataManagementService.resetAllData()
            showResetAllDataRestartAlert = true
            statusMessage = L10n.localized("management.data.reset.done")
        } catch {
            logger.error("Reset all data failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    /// "打开数据目录": reveal the Qingniao data directory in Finder.
    func openDataDirectory() {
        dataManagementService.openDataDirectory()
    }

    /// "导出数据": v1.3 placeholder. UI keeps the button disabled with a tooltip;
    /// this exists so the binding compiles and logs if ever triggered.
    func exportData() {
        try? dataManagementService.exportData()
    }

    func refreshPermissions() async {
        permissionStatuses = await permissionService.refreshStatuses()
    }

    func openSystemSettings(for permission: PermissionKind) {
        permissionService.openSystemSettings(for: permission)
    }

    func reloadBlacklist() async {
        do {
            blacklistItems = try await blacklistRepository.list()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addBlacklistItem() async {
        let sourceID = newBlacklistSourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let resultID = newBlacklistResultID.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = newBlacklistTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let type = newBlacklistType.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sourceID.isEmpty, !resultID.isEmpty, !title.isEmpty else {
            errorMessage = L10n.localized("management.blacklist.validation")
            return
        }

        do {
            _ = try await blacklistRepository.add(SearchBlacklistDraft(
                resultID: SearchResultID(rawValue: resultID),
                sourceID: SearchSourceID(rawValue: sourceID),
                title: title,
                resultType: type.isEmpty ? sourceID : type
            ))
            newBlacklistResultID = ""
            newBlacklistTitle = ""
            await reloadBlacklist()
            statusMessage = L10n.localized("management.blacklist.added")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeBlacklistItem(_ item: SearchBlacklistItemSnapshot) async {
        do {
            try await blacklistRepository.remove(id: item.id)
            await reloadBlacklist()
            statusMessage = L10n.localized("management.blacklist.removed")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func retentionTitle(_ retention: ClipboardRetention) -> String {
        switch retention {
        case .sevenDays: return L10n.localized("management.retention.7d")
        case .thirtyDays: return L10n.localized("management.retention.30d")
        case .ninetyDays: return L10n.localized("management.retention.90d")
        case .forever: return L10n.localized("management.retention.forever")
        }
    }

    func languageTitle(_ language: LanguageMode) -> String {
        switch language {
        case .followSystem: return L10n.localized("management.language.system")
        case .simplifiedChinese: return L10n.localized("management.language.zh")
        case .english: return L10n.localized("management.language.en")
        }
    }

    func permissionTitle(_ kind: PermissionKind) -> String {
        switch kind {
        case .screenRecording: return L10n.localized("management.permission.screenRecording")
        case .accessibility: return L10n.localized("management.permission.accessibility")
        }
    }

    func permissionDescription(_ kind: PermissionKind) -> String {
        switch kind {
        case .screenRecording: return L10n.localized("management.permission.screenRecording.description")
        case .accessibility: return L10n.localized("management.permission.accessibility.description")
        }
    }

    func statusTitle(_ status: PermissionStatus) -> String {
        switch status {
        case .authorized: return L10n.localized("management.permission.authorized")
        case .denied: return L10n.localized("management.permission.denied")
        case .notDetermined: return L10n.localized("management.permission.notDetermined")
        case .unknown: return L10n.localized("management.permission.unknown")
        }
    }

    private func loadSettings() async {
        do {
            for index in sourceToggles.indices {
                let enabled = try await settingsService.value(for: sourceToggles[index].settingKey, as: Bool.self)
                sourceToggles[index].isEnabled = enabled
            }
            clipboardEnabled = try await settingsService.value(for: .clipboardEnabled, as: Bool.self)
            clipboardRetention = try await settingsService.value(for: .clipboardRetention, as: ClipboardRetention.self)
            screenshotSaveDirectory = try await settingsService.value(for: .screenshotSaveDirectory, as: URL.self)
            launchAtLoginEnabled = try await settingsService.value(for: .launchAtLoginEnabled, as: Bool.self)
            languageMode = try await settingsService.value(for: .languageMode, as: LanguageMode.self)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyLanguagePreference() {
        switch languageMode {
        case .followSystem:
            userDefaults.removeObject(forKey: "AppleLanguages")
        case .simplifiedChinese:
            userDefaults.set(["zh-Hans"], forKey: "AppleLanguages")
        case .english:
            userDefaults.set(["en"], forKey: "AppleLanguages")
        }
        showLanguageRestartAlert = true
    }
}
