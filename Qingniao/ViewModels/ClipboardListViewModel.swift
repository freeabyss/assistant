import AppKit
import Combine
import Foundation
import os.log

/// ViewModel for the Qingniao clipboard history window (P-02).
///
/// This implementation uses the Core Data + file-resource + in-memory index chain
/// introduced by US-002~US-012 and reworked in v1.2 (T-005). It intentionally does
/// not depend on the legacy GRDB/FTS5 path.
@MainActor
final class ClipboardListViewModel: ObservableObject {

    /// P-02 sidebar selection. A single selection drives the visible list:
    /// content-type segment, special segment (pinned / favorite) and time segment
    /// (today / yesterday / earlier).
    enum SidebarSelection: String, CaseIterable, Identifiable, Hashable {
        // Type segment
        case all
        case text
        case image
        case richText
        case file
        // Special segment
        case pinned
        case favorite
        // Time segment
        case today
        case yesterday
        case earlier

        var id: String { rawValue }

        /// Content type passed to the index query (nil = no type constraint).
        var contentType: ClipboardContentType? {
            switch self {
            case .text: return .text
            case .richText: return .richText
            case .image: return .image
            case .file: return .file
            default: return nil
            }
        }

        var title: String {
            switch self {
            case .all: return L10n.localized("clipboard.filter.all")
            case .text: return L10n.localized("clipboard.filter.text")
            case .image: return L10n.localized("clipboard.filter.image")
            case .richText: return L10n.localized("clipboard.filter.rtf")
            case .file: return L10n.localized("clipboard.filter.file")
            case .pinned: return L10n.localized("clipboard.filter.pinned")
            case .favorite: return L10n.localized("clipboard.filter.favorite")
            case .today: return L10n.localized("clipboard.filter.today")
            case .yesterday: return L10n.localized("clipboard.filter.yesterday")
            case .earlier: return L10n.localized("clipboard.filter.earlier")
            }
        }

        var iconName: String {
            switch self {
            case .all: return "tray.full"
            case .text: return "doc.text"
            case .image: return "photo"
            case .richText: return "doc.richtext"
            case .file: return "doc"
            case .pinned: return "pin"
            case .favorite: return "star"
            case .today: return "sun.max"
            case .yesterday: return "clock.arrow.circlepath"
            case .earlier: return "calendar"
            }
        }

        /// Sidebar segment grouping (for rendering + separators).
        static let typeCases: [SidebarSelection] = [.all, .text, .image, .richText, .file]
        static let specialCases: [SidebarSelection] = [.pinned, .favorite]
        static let timeCases: [SidebarSelection] = [.today, .yesterday, .earlier]

        /// Post-filter applied to loaded snapshots.
        func includes(_ snapshot: ClipboardRecordSnapshot, calendar: Calendar = .current, now: Date = Date()) -> Bool {
            switch self {
            case .all:
                return true
            case .text:
                return snapshot.contentType == .text
            case .richText:
                return snapshot.contentType == .richText
            case .image:
                return snapshot.contentType == .image
            case .file:
                return snapshot.contentType == .file
            case .pinned:
                return snapshot.isPinned
            case .favorite:
                return snapshot.isFavorite
            case .today:
                return calendar.isDateInToday(snapshot.updatedAt)
            case .yesterday:
                return calendar.isDateInYesterday(snapshot.updatedAt)
            case .earlier:
                return !calendar.isDateInToday(snapshot.updatedAt) && !calendar.isDateInYesterday(snapshot.updatedAt)
            }
        }
    }

    @Published var query: String = ""
    @Published var selection: SidebarSelection = .all
    @Published private(set) var items: [ClipboardRecordSnapshot] = []
    @Published private(set) var selectedIndex: Int = 0
    /// Multi-selection set (⌘A / click). Highlight + batch delete.
    @Published var selectedIDs: Set<UUID> = []
    @Published private(set) var storageUsage: StorageUsage?
    @Published private(set) var retentionDays: Int?
    @Published private(set) var isLoading = false
    @Published private(set) var isClearing = false
    @Published private(set) var clipboardEnabled = true
    @Published var showClearAllConfirmation = false
    @Published var showToast = false
    @Published var toastMessage = ""
    /// Item to preview in the sheet (nil = no sheet).
    @Published var previewItem: ClipboardRecordSnapshot?

    private let queryService: ClipboardIndexQueryServiceProtocol
    private let repository: ClipboardRepositoryProtocol
    private let historyService: ClipboardHistoryServiceProtocol
    private let actionExecutor: SearchActionExecutorProtocol
    private let resourceStore: FileResourceStoreProtocol
    private let settingsService: SettingsServiceProtocol
    private let logger = Logger.ui
    private var cancellables = Set<AnyCancellable>()
    private var savedObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?

    var selectedItem: ClipboardRecordSnapshot? {
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex]
    }

    var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var formattedStorageUsage: String {
        guard let storageUsage else { return ByteCountFormatter.string(fromByteCount: 0, countStyle: .file) }
        return ByteCountFormatter.string(fromByteCount: storageUsage.totalBytes, countStyle: .file)
    }

    init(
        queryService: ClipboardIndexQueryServiceProtocol? = nil,
        repository: ClipboardRepositoryProtocol? = nil,
        historyService: ClipboardHistoryServiceProtocol? = nil,
        actionExecutor: SearchActionExecutorProtocol? = nil,
        resourceStore: FileResourceStoreProtocol? = nil,
        settingsService: SettingsServiceProtocol? = nil
    ) {
        let defaultIndex = InMemorySearchIndex()
        let defaultResourceStore = resourceStore ?? FileResourceStore(fileSystem: PersistenceController.shared.fileSystem)
        let defaultRepository = repository ?? ClipboardRepository(persistence: .shared, resourceStore: defaultResourceStore)

        self.repository = defaultRepository
        self.resourceStore = defaultResourceStore
        self.queryService = queryService ?? ClipboardIndexQueryService(index: defaultIndex, repository: defaultRepository)
        self.historyService = historyService ?? ClipboardHistoryService(repository: defaultRepository)
        self.settingsService = settingsService ?? SettingsService(persistence: .shared)
        self.actionExecutor = actionExecutor ?? SearchPanelActionExecutor(
            appExecutor: NoopSearchActionExecutor(),
            commandExecutor: NoopSearchActionExecutor(),
            clipboardRepository: defaultRepository,
            resourceStore: defaultResourceStore
        )

        if queryService == nil {
            Task {
                do {
                    let loader = ClipboardSearchIndexLoader(persistence: .shared, index: defaultIndex)
                    try await loader.rebuildFromPersistentStore()
                    await load()
                } catch {
                    logger.error("Failed to initialize clipboard history index: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        setupDebounce()
        setupFilterSubscription()
        setupNewContentObserver()
        setupSettingsObserver()
    }

    deinit {
        if let savedObserver {
            NotificationCenter.default.removeObserver(savedObserver)
        }
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        await refreshRuntimeSettings()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Content-type selections constrain the index query; special/time
        // selections load all and are post-filtered on the loaded snapshots.
        let indexFilter = selection.contentType
        let indexedItems: [SearchIndexItem]
        if trimmedQuery.isEmpty {
            indexedItems = queryService.historyIndex(filter: indexFilter, limit: nil, offset: 0)
        } else {
            indexedItems = queryService.searchIndex(query: trimmedQuery, filter: indexFilter, limit: nil)
        }

        var loaded: [ClipboardRecordSnapshot] = []
        loaded.reserveCapacity(indexedItems.count)

        for item in indexedItems {
            do {
                if let snapshot = try await queryService.loadDetails(for: item), selection.includes(snapshot) {
                    loaded.append(snapshot)
                }
            } catch {
                logger.error("Failed to load clipboard record detail: \(error.localizedDescription, privacy: .public)")
            }
        }

        items = loaded
        // Preserve selection where possible.
        selectedIDs = selectedIDs.intersection(Set(loaded.map(\.id)))
        selectedIndex = items.isEmpty ? 0 : min(selectedIndex, items.count - 1)
        await refreshStorageUsage()
    }

    func refresh() async {
        await load()
    }

    // MARK: - Selection

    func moveSelectionUp() {
        guard !items.isEmpty else { return }
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : items.count - 1
        syncCursorSelection()
    }

    func moveSelectionDown() {
        guard !items.isEmpty else { return }
        selectedIndex = selectedIndex < items.count - 1 ? selectedIndex + 1 : 0
        syncCursorSelection()
    }

    func select(_ item: ClipboardRecordSnapshot) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        selectedIndex = index
        syncCursorSelection()
    }

    func selectAll() {
        selectedIDs = Set(items.map(\.id))
    }

    private func syncCursorSelection() {
        if let selectedItem {
            selectedIDs = [selectedItem.id]
        }
    }

    // MARK: - Actions

    func copySelectedToPasteboard() {
        guard let selectedItem else { return }
        Task { await copyToPasteboard(selectedItem) }
    }

    func copyToPasteboard(_ item: ClipboardRecordSnapshot) async {
        do {
            try await actionExecutor.execute(.copyClipboardRecord(item.id))
            showToast(message: L10n.localized("toast.copied"))
        } catch {
            logger.error("Failed to copy clipboard record: \(error.localizedDescription, privacy: .public)")
            showToast(message: item.failureReason ?? error.localizedDescription)
        }
    }

    func togglePin(_ item: ClipboardRecordSnapshot) async {
        do {
            _ = try await repository.togglePin(id: item.id)
            await load()
        } catch {
            logger.error("Failed to toggle clipboard pin: \(error.localizedDescription, privacy: .public)")
            showToast(message: error.localizedDescription)
        }
    }

    func toggleFavorite(_ item: ClipboardRecordSnapshot) async {
        do {
            _ = try await repository.toggleFavorite(id: item.id)
            await load()
        } catch {
            logger.error("Failed to toggle clipboard favorite: \(error.localizedDescription, privacy: .public)")
            showToast(message: error.localizedDescription)
        }
    }

    func delete(_ item: ClipboardRecordSnapshot) async {
        do {
            try await repository.delete(id: item.id)
            items.removeAll { $0.id == item.id }
            selectedIDs.remove(item.id)
            selectedIndex = items.isEmpty ? 0 : min(selectedIndex, items.count - 1)
            await refreshStorageUsage()
        } catch {
            logger.error("Failed to delete clipboard record: \(error.localizedDescription, privacy: .public)")
            showToast(message: error.localizedDescription)
        }
    }

    /// Deletes the current multi-selection, or the cursor item if nothing is selected.
    func deleteSelected() async {
        let targets: [UUID]
        if selectedIDs.isEmpty {
            targets = selectedItem.map { [$0.id] } ?? []
        } else {
            targets = Array(selectedIDs)
        }
        guard !targets.isEmpty else { return }
        for id in targets {
            do {
                try await repository.delete(id: id)
            } catch {
                logger.error("Failed to delete clipboard record: \(error.localizedDescription, privacy: .public)")
            }
        }
        items.removeAll { targets.contains($0.id) }
        selectedIDs.subtract(targets)
        selectedIndex = items.isEmpty ? 0 : min(selectedIndex, items.count - 1)
        await refreshStorageUsage()
    }

    func clearAllConfirmed() async {
        isClearing = true
        defer { isClearing = false }

        do {
            try await historyService.clearAll(confirmed: true)
            items = []
            selectedIDs = []
            selectedIndex = 0
            await refreshStorageUsage()
            showToast(message: L10n.localized("clipboard.clearAll.success"))
        } catch {
            logger.error("Failed to clear clipboard history: \(error.localizedDescription, privacy: .public)")
            showToast(message: error.localizedDescription)
        }
    }

    /// Re-enables clipboard recording from the disabled empty state.
    func enableClipboard() async {
        do {
            try await settingsService.set(true, for: .clipboardEnabled)
            clipboardEnabled = true
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
            await load()
        } catch {
            logger.error("Failed to enable clipboard recording: \(error.localizedDescription, privacy: .public)")
            showToast(message: error.localizedDescription)
        }
    }

    func thumbnailData(for item: ClipboardRecordSnapshot) async -> Data? {
        guard let thumbnail = item.resources.first(where: { $0.type == .imageThumbnail && !$0.isMissing }) else { return nil }
        return try? await resourceStore.read(relativePath: thumbnail.relativePath)
    }

    func originalImageData(for item: ClipboardRecordSnapshot) async -> Data? {
        guard let original = item.resources.first(where: { $0.type == .imageOriginal && !$0.isMissing }) else { return nil }
        return try? await resourceStore.read(relativePath: original.relativePath)
    }

    func richTextData(for item: ClipboardRecordSnapshot) async -> Data? {
        guard let rtf = item.resources.first(where: { $0.type == .richTextRTF && !$0.isMissing }) else { return nil }
        return try? await resourceStore.read(relativePath: rtf.relativePath)
    }

    private func refreshStorageUsage() async {
        do {
            storageUsage = try await repository.storageUsage()
        } catch {
            logger.error("Failed to refresh clipboard storage usage: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func refreshRuntimeSettings() async {
        clipboardEnabled = (try? await settingsService.value(for: .clipboardEnabled, as: Bool.self)) ?? true
        let retentionRaw = (try? await settingsService.stringValue(for: .clipboardRetention)) ?? "30d"
        retentionDays = ClipboardRetention(rawValue: retentionRaw)?.days
    }

    private func setupDebounce() {
        $query
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { await self?.load() }
            }
            .store(in: &cancellables)
    }

    private func setupFilterSubscription() {
        $selection
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { await self?.load() }
            }
            .store(in: &cancellables)
    }

    private func setupNewContentObserver() {
        savedObserver = NotificationCenter.default.addObserver(
            forName: .clipboardItemSaved,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.load() }
        }
    }

    private func setupSettingsObserver() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.refreshRuntimeSettings() }
        }
    }

    private func showToast(message: String) {
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            self?.showToast = false
        }
    }
}
