import AppKit
import Combine
import Foundation
import os.log

/// ViewModel for the Assistant MVP clipboard history page.
///
/// This implementation uses the Core Data + file-resource + in-memory index chain
/// introduced by US-002~US-012. It intentionally does not depend on the legacy
/// GRDB/FTS5 ClipboardListViewModel path.
@MainActor
final class ClipboardListViewModel: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable {
        case all
        case text
        case image
        case file

        var id: String { rawValue }

        var contentType: ClipboardContentType? {
            switch self {
            case .all:
                return nil
            case .text:
                return nil
            case .image:
                return .image
            case .file:
                return .file
            }
        }

        var title: String {
            switch self {
            case .all:
                return L10n.localized("clipboard.filter.all")
            case .text:
                return L10n.localized("clipboard.filter.text")
            case .image:
                return L10n.localized("clipboard.filter.image")
            case .file:
                return L10n.localized("clipboard.filter.file")
            }
        }

        var iconName: String {
            switch self {
            case .all:
                return "tray.full"
            case .text:
                return "doc.text"
            case .image:
                return "photo"
            case .file:
                return "doc"
            }
        }

        func includes(_ type: ClipboardContentType?) -> Bool {
            switch self {
            case .all:
                return true
            case .text:
                return type == .text || type == .richText
            case .image:
                return type == .image
            case .file:
                return type == .file
            }
        }
    }

    @Published var query: String = ""
    @Published var filter: Filter = .all
    @Published private(set) var items: [ClipboardRecordSnapshot] = []
    @Published private(set) var selectedIndex: Int = 0
    @Published private(set) var storageUsage: StorageUsage?
    @Published private(set) var isLoading = false
    @Published private(set) var isClearing = false
    @Published var showClearAllConfirmation = false
    @Published var showToast = false
    @Published var toastMessage = ""

    private let queryService: ClipboardIndexQueryServiceProtocol
    private let repository: ClipboardRepositoryProtocol
    private let historyService: ClipboardHistoryServiceProtocol
    private let actionExecutor: SearchActionExecutorProtocol
    private let resourceStore: FileResourceStoreProtocol
    private let logger = Logger.ui
    private var cancellables = Set<AnyCancellable>()
    private var savedObserver: NSObjectProtocol?

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
        resourceStore: FileResourceStoreProtocol? = nil
    ) {
        let defaultIndex = InMemorySearchIndex()
        let defaultResourceStore = resourceStore ?? FileResourceStore(fileSystem: PersistenceController.shared.fileSystem)
        let defaultRepository = repository ?? ClipboardRepository(persistence: .shared, resourceStore: defaultResourceStore)

        self.repository = defaultRepository
        self.resourceStore = defaultResourceStore
        self.queryService = queryService ?? ClipboardIndexQueryService(index: defaultIndex, repository: defaultRepository)
        self.historyService = historyService ?? ClipboardHistoryService(repository: defaultRepository)
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
    }

    deinit {
        if let savedObserver {
            NotificationCenter.default.removeObserver(savedObserver)
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let indexedItems: [SearchIndexItem]
        if trimmedQuery.isEmpty {
            indexedItems = queryService.historyIndex(filter: filter.contentType, limit: nil, offset: 0)
        } else {
            indexedItems = queryService.searchIndex(query: trimmedQuery, filter: filter.contentType, limit: nil)
        }

        let visibleIndexItems = indexedItems.filter { filter.includes($0.contentType) }
        var loaded: [ClipboardRecordSnapshot] = []
        loaded.reserveCapacity(visibleIndexItems.count)

        for item in visibleIndexItems {
            do {
                if let snapshot = try await queryService.loadDetails(for: item) {
                    loaded.append(snapshot)
                }
            } catch {
                logger.error("Failed to load clipboard record detail: \(error.localizedDescription, privacy: .public)")
            }
        }

        items = loaded
        selectedIndex = items.isEmpty ? 0 : min(selectedIndex, items.count - 1)
        await refreshStorageUsage()
    }

    func refresh() async {
        await load()
    }

    func moveSelectionUp() {
        guard !items.isEmpty else { return }
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : items.count - 1
    }

    func moveSelectionDown() {
        guard !items.isEmpty else { return }
        selectedIndex = selectedIndex < items.count - 1 ? selectedIndex + 1 : 0
    }

    func select(_ item: ClipboardRecordSnapshot) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        selectedIndex = index
    }

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

    func delete(_ item: ClipboardRecordSnapshot) async {
        do {
            try await repository.delete(id: item.id)
            items.removeAll { $0.id == item.id }
            selectedIndex = items.isEmpty ? 0 : min(selectedIndex, items.count - 1)
            await refreshStorageUsage()
        } catch {
            logger.error("Failed to delete clipboard record: \(error.localizedDescription, privacy: .public)")
            showToast(message: error.localizedDescription)
        }
    }

    func clearAllConfirmed() async {
        isClearing = true
        defer { isClearing = false }

        do {
            try await historyService.clearAll(confirmed: true)
            items = []
            selectedIndex = 0
            await refreshStorageUsage()
            showToast(message: L10n.localized("clipboard.clearAll.success"))
        } catch {
            logger.error("Failed to clear clipboard history: \(error.localizedDescription, privacy: .public)")
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

    private func refreshStorageUsage() async {
        do {
            storageUsage = try await repository.storageUsage()
        } catch {
            logger.error("Failed to refresh clipboard storage usage: \(error.localizedDescription, privacy: .public)")
        }
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
        $filter
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

    private func showToast(message: String) {
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            self?.showToast = false
        }
    }
}
