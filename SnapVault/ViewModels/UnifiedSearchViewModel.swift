import Foundation
import AppKit
import Combine
import os.log

/// ViewModel for the unified search interface (Spotlight-style).
///
/// Manages search input with 300ms debounce, dispatches queries to
/// UnifiedSearchService, and handles keyboard navigation and result actions.
@MainActor
final class UnifiedSearchViewModel: ObservableObject {
    // MARK: - Published State

    @Published var searchText: String = ""
    @Published var applications: [UnifiedSearchResult] = []
    @Published var files: [UnifiedSearchResult] = []
    @Published var clipboard: [UnifiedSearchResult] = []
    @Published var systemCommands: [UnifiedSearchResult] = []
    @Published var isLoading: Bool = false
    @Published var selectedResult: UnifiedSearchResult?
    @Published var elapsed: TimeInterval = 0
    @Published var selectedGroup: SearchResultType? = nil  // nil = "All" tab

    // MARK: - Private

    private let unifiedSearchService: UnifiedSearchServiceProtocol
    private let logger = Logger.search
    private let maxResultsPerSource = 10
    private var cancellables = Set<AnyCancellable>()
    private var debounceSetUp = false

    /// Flattened list of all visible results for keyboard navigation.
    /// Built from the current group filter.
    private var flatResults: [UnifiedSearchResult] {
        if let group = selectedGroup {
            return resultsForGroup(group)
        }
        // "All" mode: apps -> system commands -> files -> clipboard, each max 10
        var all: [UnifiedSearchResult] = []
        all.append(contentsOf: applications.prefix(maxResultsPerSource))
        all.append(contentsOf: systemCommands.prefix(maxResultsPerSource))
        all.append(contentsOf: files.prefix(maxResultsPerSource))
        all.append(contentsOf: clipboard.prefix(maxResultsPerSource))
        return all
    }

    // MARK: - Init

    init(unifiedSearchService: UnifiedSearchServiceProtocol) {
        self.unifiedSearchService = unifiedSearchService
        setupSearchDebounce()
    }

    // MARK: - Public API

    /// Ensure debounce is set up (call on first use if init was nonisolated).
    func ensureDebounceSetUp() {
        guard !debounceSetUp else { return }
        debounceSetUp = true
        setupSearchDebounce()
    }

    /// Execute a search query against all registered sources.
    func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clearResults()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await unifiedSearchService.search(query: trimmed, limit: maxResultsPerSource)
            applications = response.applications
            files = response.files
            clipboard = response.clipboard
            systemCommands = response.systemCommands
            elapsed = response.elapsed
            selectedResult = flatResults.first
            logger.info("Search completed: \(response.totalCount) results (apps:\(response.applications.count), files:\(response.files.count), clipboard:\(response.clipboard.count), system:\(response.systemCommands.count)) in \(String(format: "%.1f", response.elapsed))ms")
            // Refocus the text field after results appear
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .focusSearchField, object: nil)
            }
        } catch {
            logger.error("Unified search failed: \(error.localizedDescription, privacy: .public)")
            clearResults()
        }
    }

    /// Select a result and execute its action.
    func select(_ result: UnifiedSearchResult) {
        selectedResult = result
    }

    /// Execute the action associated with the currently selected search result.
    func confirmSelection() {
        guard let result = selectedResult else { return }
        executeAction(for: result)
    }

    /// Execute the action for a specific result.
    func executeAction(for result: UnifiedSearchResult) {
        // Record the selection for ranking improvement
        unifiedSearchService.recordSelection(resultID: result.id)

        switch result.action {
        case .launchApp(let bundleID, let path):
            logger.info("Launching app: \(bundleID, privacy: .public)")
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(
                at: path,
                configuration: configuration
            ) { [weak self] _, error in
                if let error {
                    Logger.search.error("Failed to launch app: \(error.localizedDescription, privacy: .public)")
                } else {
                    // Record app launch for AppSearchSource ranking
                    DispatchQueue.main.async {
                        self?.recordAppLaunch(bundleID: bundleID)
                    }
                }
            }

        case .openFile(let path):
            logger.info("Opening file: \(path.path, privacy: .public)")
            NSWorkspace.shared.open(path)

        case .openInFinder(let path):
            logger.info("Revealing in Finder: \(path.path, privacy: .public)")
            NSWorkspace.shared.activateFileViewerSelecting([path])

        case .copyToClipboard(let itemID):
            logger.info("Copying clipboard item: \(itemID)")
            copyClipboardItem(itemID: itemID)

        case .runSystemCommand(let command):
            logger.info("Running system command: \(command.rawValue, privacy: .public)")
            runSystemCommand(command)
        }
    }

    /// Move keyboard selection up in the flat results list.
    func moveSelectionUp() {
        let results = flatResults
        guard !results.isEmpty else { return }

        if let current = selectedResult, let index = results.firstIndex(where: { $0.id == current.id }) {
            let newIndex = index > 0 ? index - 1 : results.count - 1
            selectedResult = results[newIndex]
        } else {
            selectedResult = results.last
        }
    }

    /// Move keyboard selection down in the flat results list.
    func moveSelectionDown() {
        let results = flatResults
        guard !results.isEmpty else { return }

        if let current = selectedResult, let index = results.firstIndex(where: { $0.id == current.id }) {
            let newIndex = index < results.count - 1 ? index + 1 : 0
            selectedResult = results[newIndex]
        } else {
            selectedResult = results.first
        }
    }

    /// Cycle through group tabs: All -> Applications -> System -> Files -> Clipboard -> All.
    func cycleGroupForward() {
        switch selectedGroup {
        case nil:
            selectedGroup = .application
        case .application:
            selectedGroup = .systemCommand
        case .systemCommand:
            selectedGroup = .file
        case .file:
            selectedGroup = .clipboard
        case .clipboard:
            selectedGroup = nil
        }
        selectedResult = flatResults.first
    }

    /// Cycle through group tabs in reverse.
    func cycleGroupBackward() {
        switch selectedGroup {
        case nil:
            selectedGroup = .clipboard
        case .clipboard:
            selectedGroup = .file
        case .file:
            selectedGroup = .systemCommand
        case .systemCommand:
            selectedGroup = .application
        case .application:
            selectedGroup = nil
        }
        selectedResult = flatResults.first
    }

    /// Get results for a specific group, capped at maxResultsPerSource.
    func resultsForGroup(_ type: SearchResultType) -> [UnifiedSearchResult] {
        switch type {
        case .application: return Array(applications.prefix(maxResultsPerSource))
        case .file: return Array(files.prefix(maxResultsPerSource))
        case .clipboard: return Array(clipboard.prefix(maxResultsPerSource))
        case .systemCommand: return Array(systemCommands.prefix(maxResultsPerSource))
        }
    }

    /// Total result count across all groups.
    var totalCount: Int {
        applications.count + files.count + clipboard.count + systemCommands.count
    }

    /// Whether there are any search results.
    var hasResults: Bool {
        totalCount > 0
    }

    /// Whether the search text is empty (used to switch between search mode and history mode).
    var isSearchActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Private

    private func setupSearchDebounce() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task { [weak self] in
                    await self?.search(query: query)
                }
            }
            .store(in: &cancellables)
    }

    private func clearResults() {
        applications = []
        files = []
        clipboard = []
        systemCommands = []
        elapsed = 0
        selectedResult = nil
        // Refocus when clearing (search text emptied)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .focusSearchField, object: nil)
        }
    }

    /// Copy a clipboard item to the system clipboard by fetching from the database.
    private func copyClipboardItem(itemID: Int64) {
        let repository = ContentRepository()
        do {
            guard let item = try repository.fetch(id: itemID) else {
                logger.warning("Clipboard item \(itemID) not found for copy")
                return
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()

            switch item.contentType {
            case .text:
                if let text = item.textContent {
                    pasteboard.setString(text, forType: .string)
                }
            case .rtf:
                if let rtf = item.rtfContent, let rtfData = rtf.data(using: .utf8) {
                    pasteboard.setData(rtfData, forType: .rtf)
                }
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
                    pasteboard.writeObjects([url as NSPasteboardWriting])
                }
            }
            logger.debug("Copied clipboard item \(itemID) to pasteboard")
        } catch {
            logger.error("Failed to copy clipboard item: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Record app launch via AppSearchSource for ranking.
    private func recordAppLaunch(bundleID: String) {
        // Use UserDefaults directly (mirrors AppSearchSource's persistence)
        let key = "app_search_use_counts"
        var counts: [String: Int] = [:]
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            counts = decoded
        }
        counts[bundleID, default: 0] += 1
        if let data = try? JSONEncoder().encode(counts) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - System Commands

    /// Dispatch a system command. Destructive commands (restart / shutdown / empty trash)
    /// show a confirmation NSAlert before execution.
    private func runSystemCommand(_ command: SystemCommand) {
        if command.requiresConfirmation {
            let alert = NSAlert()
            switch command {
            case .restart:
                alert.messageText = "Restart your Mac?"
                alert.informativeText = "All open applications will be closed and the computer will restart."
            case .shutdown:
                alert.messageText = "Shut down your Mac?"
                alert.informativeText = "All open applications will be closed and the computer will turn off."
            case .emptyTrash:
                alert.messageText = "Empty the Trash?"
                alert.informativeText = "Items in the Trash will be permanently deleted."
            default:
                alert.messageText = "Run \(command.rawValue)?"
            }
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else {
                logger.info("User cancelled system command: \(command.rawValue, privacy: .public)")
                return
            }
        }

        switch command {
        case .sleep:
            runAppleScript(#"tell application "System Events" to sleep"#)
        case .restart:
            runAppleScript(#"tell application "System Events" to restart"#)
        case .shutdown:
            runAppleScript(#"tell application "System Events" to shut down"#)
        case .lock:
            lockScreenViaCGSession()
        case .lockScreen:
            // Turn off the display (pmset displaysleepnow)
            runProcess(launchPath: "/usr/bin/pmset", arguments: ["displaysleepnow"])
        case .emptyTrash:
            runAppleScript(#"tell application "Finder" to empty the trash"#)
        case .showDesktop:
            runAppleScript(#"tell application "System Events" to key code 103 using {fn down}"#)
        }
    }

    /// Execute an AppleScript snippet via NSAppleScript on a background queue.
    private func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var errorInfo: NSDictionary?
            if let script = NSAppleScript(source: source) {
                script.executeAndReturnError(&errorInfo)
                if let errorInfo = errorInfo {
                    Logger.search.error("AppleScript error: \(errorInfo, privacy: .public)")
                } else {
                    Logger.search.info("AppleScript executed successfully")
                }
            } else {
                Logger.search.error("Failed to create NSAppleScript from source")
            }
        }
    }

    /// Lock the screen using the legacy CGSession suspend command. This is the
    /// canonical way to lock immediately without sleeping the display.
    private func lockScreenViaCGSession() {
        let path = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
        if FileManager.default.isExecutableFile(atPath: path) {
            runProcess(launchPath: path, arguments: ["-suspend"])
        } else {
            // Fallback: trigger display sleep (still effectively locks if Login is required after sleep)
            runProcess(launchPath: "/usr/bin/pmset", arguments: ["displaysleepnow"])
        }
    }

    /// Spawn an external process on a background queue.
    private func runProcess(launchPath: String, arguments: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.launchPath = launchPath
            process.arguments = arguments
            do {
                try process.run()
                process.waitUntilExit()
                Logger.search.info("Process \(launchPath, privacy: .public) exited with status \(process.terminationStatus)")
            } catch {
                Logger.search.error("Failed to run \(launchPath, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
