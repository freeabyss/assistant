import Foundation
import AppKit
import Combine
import os.log

/// ViewModel for the clipboard history list.
@MainActor
final class ClipboardListViewModel: ObservableObject {
    // MARK: - Published State

    @Published var items: [ClipboardItem] = []
    @Published var searchText: String = ""
    @Published var selectedContentType: ContentType? = nil
    @Published var isLoading: Bool = false
    @Published var hasMore: Bool = true
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""

    /// Highlight ranges for search results, keyed by item id.
    /// Views use this to render keyword highlighting.
    @Published var searchHighlights: [Int64: [NSRange]] = [:]

    // MARK: - Private

    private let repository = ContentRepository()
    private let searchService: SearchServiceProtocol = SearchService()
    private let logger = Logger.ui
    private let pageSize = 50
    private var currentPage = 0
    private var cancellables = Set<AnyCancellable>()

    /// Observer token for clipboardItemSaved notifications.
    private var savedObserver: NSObjectProtocol?

    // MARK: - Init

    init() {
        setupSearchDebounce()
        setupFilterSubscription()
        setupNewContentObserver()
    }

    deinit {
        if let observer = savedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    /// Load the next page of items (or first page if items is empty).
    func loadMore() async {
        guard !isLoading else { return }
        guard hasMore else { return }

        isLoading = true
        defer { isLoading = false }

        // If searching, use FTS search
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            await performSearch(query: trimmedSearch)
            return
        }

        // Otherwise, fetch history with pagination
        do {
            let newItems = try repository.fetchHistory(
                page: currentPage,
                pageSize: pageSize,
                contentType: selectedContentType,
                pinnedOnly: false
            )

            if currentPage == 0 {
                items = newItems
            } else {
                items.append(contentsOf: newItems)
            }

            hasMore = newItems.count >= pageSize
            currentPage += 1

            logger.debug("Loaded page \(self.currentPage - 1), got \(newItems.count) items, hasMore=\(self.hasMore)")
        } catch {
            logger.error("Failed to load items: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Refresh the list from the beginning.
    func refresh() async {
        currentPage = 0
        hasMore = true
        items = []
        searchHighlights = [:]
        await loadMore()
    }

    /// Delete an item by id.
    func deleteItem(_ item: ClipboardItem) async {
        guard let id = item.id else { return }
        do {
            try repository.delete(id: id)
            items.removeAll { $0.id == id }
            logger.debug("Deleted item id=\(id)")
        } catch {
            logger.error("Failed to delete item: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Toggle pinned state of an item.
    func togglePin(_ item: ClipboardItem) async {
        guard let id = item.id else { return }
        do {
            try repository.togglePin(id: id)
            // Update local state
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index].isPinned.toggle()
                items[index].updatedAt = Date()
            }
            logger.debug("Toggled pin for item id=\(id)")
        } catch {
            logger.error("Failed to toggle pin: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Copy item content to clipboard with proper type handling.
    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.contentType {
        case .text:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }

        case .rtf:
            // Write both RTF data and plain text fallback
            if let rtf = item.rtfContent, let rtfData = rtf.data(using: .utf8) {
                pasteboard.setData(rtfData, forType: .rtf)
            }
            // Always provide plain text fallback
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }

        case .image:
            if let data = item.imageData {
                pasteboard.setData(data, forType: .tiff)
            }

        case .file:
            if let path = item.filePath {
                let url = URL(fileURLWithPath: path)
                pasteboard.clearContents()
                pasteboard.writeObjects([url as NSPasteboardWriting])
            }
        }

        // Show toast feedback
        showCopyToast()

        logger.debug("Copied item id=\(String(describing: item.id)) to clipboard")
    }

    /// Show a brief "已复制" toast notification.
    private func showCopyToast() {
        toastMessage = "已复制"
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showToast = false
        }
    }

    // MARK: - Private

    private func performSearch(query: String) async {
        do {
            // Map selectedContentType to SearchScope
            let scope: SearchScope
            switch selectedContentType {
            case .image:
                scope = .imageOCR
            case .text, .rtf:
                scope = .textOnly
            case .none:
                scope = .all
            case .file:
                scope = .all
            }

            let results = try await searchService.search(query: query, limit: pageSize, scope: scope)

            items = results.map { $0.item }
            searchHighlights = [:]
            for result in results {
                if let id = result.item.id, !result.highlightRanges.isEmpty {
                    searchHighlights[id] = result.highlightRanges
                }
            }
            hasMore = false // Search results don't paginate in this version
            logger.debug("Search '\(query, privacy: .public)' returned \(results.count) results via SearchService")
        } catch {
            logger.error("Search failed: \(error.localizedDescription, privacy: .public)")
            items = []
            searchHighlights = [:]
        }
    }

    private func setupSearchDebounce() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.refresh()
                }
            }
            .store(in: &cancellables)
    }

    private func setupFilterSubscription() {
        $selectedContentType
            .dropFirst() // Skip initial value
            .removeDuplicates { $0?.rawValue == $1?.rawValue }
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.refresh()
                }
            }
            .store(in: &cancellables)
    }

    /// Listen for new clipboard items saved by ContentStore and auto-refresh the list.
    private func setupNewContentObserver() {
        savedObserver = NotificationCenter.default.addObserver(
            forName: .clipboardItemSaved,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.refresh()
            }
        }
    }
}
