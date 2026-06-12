import AppKit
import Combine
import Foundation
import os.log

@MainActor
final class SearchPanelViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var results: [SearchResult] = []
    @Published private(set) var selectedIndex: Int = 0
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""

    private let searchService: SearchServiceProtocol
    private let onClose: () -> Void
    private let logger = Logger.search
    private var cancellables = Set<AnyCancellable>()

    var hasQuery: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var selectedResult: SearchResult? {
        guard results.indices.contains(selectedIndex) else { return nil }
        return results[selectedIndex]
    }

    init(searchService: SearchServiceProtocol, onClose: @escaping () -> Void = {}) {
        self.searchService = searchService
        self.onClose = onClose
        setupDebounce()
    }

    func open() {
        query = ""
        clearResults()
    }

    func close() {
        onClose()
    }

    func moveUp() {
        guard !results.isEmpty else { return }
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : results.count - 1
    }

    func moveDown() {
        guard !results.isEmpty else { return }
        selectedIndex = selectedIndex < results.count - 1 ? selectedIndex + 1 : 0
    }

    func select(_ result: SearchResult) {
        guard let index = results.firstIndex(where: { $0.id == result.id }) else { return }
        selectedIndex = index
    }

    func confirmSelection() {
        guard let result = selectedResult else { return }
        Task { await execute(result) }
    }

    func execute(_ result: SearchResult) async {
        await searchService.recordSelection(result)
        do {
            let response = try await searchService.execute(result.primaryAction)
            if response.shouldCloseSearchPanel {
                onClose()
            }
        } catch {
            logger.error("Search action failed: \(error.localizedDescription, privacy: .public)")
            showToast(message: error.localizedDescription)
        }
    }

    func searchNow() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clearResults()
            return
        }

        isLoading = true
        defer { isLoading = false }

        let response = await searchService.search(query: trimmed)
        results = Array(response.results.prefix(SearchService.defaultResultLimit))
        selectedIndex = results.isEmpty ? 0 : min(selectedIndex, results.count - 1)
        elapsed = response.elapsed * 1000
        logger.info("SearchPanel query returned \(self.results.count) results in \(String(format: "%.1f", self.elapsed))ms")
    }

    private func setupDebounce() {
        $query
            .debounce(for: .milliseconds(180), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { await self?.searchNow() }
            }
            .store(in: &cancellables)
    }

    private func clearResults() {
        results = []
        selectedIndex = 0
        elapsed = 0
        isLoading = false
    }

    private func showToast(message: String) {
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            self?.showToast = false
        }
    }
}

/// Composite executor used by US-011 search panel to route all MVP primary actions.
final class SearchPanelActionExecutor: SearchActionExecutorProtocol {
    private let appExecutor: SearchActionExecutorProtocol
    private let commandExecutor: SearchActionExecutorProtocol
    private let clipboardRepository: ClipboardRepositoryProtocol
    private let resourceStore: FileResourceStoreProtocol

    init(
        appExecutor: SearchActionExecutorProtocol,
        commandExecutor: SearchActionExecutorProtocol,
        clipboardRepository: ClipboardRepositoryProtocol,
        resourceStore: FileResourceStoreProtocol
    ) {
        self.appExecutor = appExecutor
        self.commandExecutor = commandExecutor
        self.clipboardRepository = clipboardRepository
        self.resourceStore = resourceStore
    }

    func execute(_ action: SearchAction) async throws {
        switch action {
        case .openApplication:
            try await appExecutor.execute(action)
        case .runCommand:
            try await commandExecutor.execute(action)
        case .copyClipboardRecord(let id):
            try await copyClipboardRecord(id)
        case .copyText(let text):
            await MainActor.run {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
            }
        case .openSettings(let route):
            await openSettings(route)
        case .startScreenshot(let mode):
            await startScreenshot(mode)
        }
    }

    private func copyClipboardRecord(_ id: UUID) async throws {
        guard let snapshot = try await clipboardRepository.fetch(id: id) else {
            throw NSError(domain: "com.assistant.searchPanel", code: 404, userInfo: [NSLocalizedDescriptionKey: L10n.localized("searchPanel.error.recordNotFound")])
        }

        await MainActor.run {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            switch snapshot.contentType {
            case .text:
                if let text = snapshot.plainText {
                    pasteboard.setString(text, forType: .string)
                }
            case .richText:
                if let text = snapshot.plainText {
                    pasteboard.setString(text, forType: .string)
                }
            case .image:
                // The image data is read off-main below; this case is filled by the async path.
                break
            case .file:
                if let url = snapshot.filePath {
                    pasteboard.writeObjects([url as NSPasteboardWriting])
                }
            }
        }

        if snapshot.contentType == .richText || snapshot.contentType == .image {
            try await writeResources(snapshot)
        }
    }

    private func writeResources(_ snapshot: ClipboardRecordSnapshot) async throws {
        let resources = snapshot.resources
        switch snapshot.contentType {
        case .richText:
            for resource in resources {
                switch resource.type {
                case .richTextRTF:
                    let data = try await resourceStore.read(relativePath: resource.relativePath)
                    await MainActor.run { _ = NSPasteboard.general.setData(data, forType: .rtf) }
                case .richTextHTML:
                    let data = try await resourceStore.read(relativePath: resource.relativePath)
                    await MainActor.run { _ = NSPasteboard.general.setData(data, forType: NSPasteboard.PasteboardType("public.html")) }
                default:
                    break
                }
            }
        case .image:
            if let original = resources.first(where: { $0.type == .imageOriginal }) {
                let data = try await resourceStore.read(relativePath: original.relativePath)
                await MainActor.run {
                    let pasteboard = NSPasteboard.general
                    pasteboard.setData(data, forType: NSPasteboard.PasteboardType("public.png"))
                    if let image = NSImage(data: data), let tiff = image.tiffRepresentation {
                        pasteboard.setData(tiff, forType: .tiff)
                    }
                }
            }
        case .text, .file:
            break
        }
    }

    @MainActor
    private func openSettings(_ route: SettingsRoute) {
        _ = route
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @MainActor
    private func startScreenshot(_ mode: AssistantScreenshotMode) {
        switch mode {
        case .region:
            NotificationCenter.default.post(name: .commandCaptureRegion, object: nil)
        case .fullScreen:
            NotificationCenter.default.post(name: .commandCaptureFullScreen, object: nil)
        case .window:
            NotificationCenter.default.post(name: .commandCaptureWindow, object: nil)
        }
    }
}

@MainActor
final class SearchPanelCommandConfirmationProvider: CommandConfirmationProviding {
    func confirm(command: AssistantCommandDefinition) async -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = command.chineseName
        alert.informativeText = L10n.localized("searchPanel.confirm.destructive")
        alert.addButton(withTitle: L10n.localized("settings.alert.ok"))
        alert.addButton(withTitle: L10n.localized("settings.alert.cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }
}
