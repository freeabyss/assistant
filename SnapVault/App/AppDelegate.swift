import Cocoa
import SwiftUI
import KeyboardShortcuts
import Combine
import ServiceManagement
import os.log

/// A borderless floating panel that can become key window (for text input).
class FloatingSearchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// AppKit lifecycle delegate, bridges AppKit-specific setup that SwiftUI cannot handle.
class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger.app

    /// Status bar item showing the Assistant icon.
    private var statusItem: NSStatusItem!

    /// Menu shown from the status bar item.
    private var statusMenu: NSMenu!

    /// Floating panel that hosts the main SwiftUI view.
    private var panel: NSPanel?

    /// Cancellable for observing search state changes.
    private var searchStateCancellable: AnyCancellable?

    /// Local event monitor for detecting clicks outside the panel.
    private var localEventMonitor: Any?
    /// Flag to prevent double-close
    private var isClosingPanel = false

    /// Clipboard polling monitor.
    private let clipboardMonitor = ClipboardMonitor()

    /// Content store that persists new clipboard events.
    private let contentStore = ContentStore()

    /// Task that consumes clipboard events from the monitor stream.
    private var monitorTask: Task<Void, Never>?

    /// Periodic data cleanup service (expiry + storage limits).
    private let cleanupService = DataCleanupService()

    /// Auto-update service (Sparkle).
    private let updateService = UpdateService()

    /// Unified search service aggregating multiple search sources.
    private let unifiedSearchService = UnifiedSearchService()

    /// Clipboard search source (wraps FTS5 + Spotlight search).
    private let clipboardSearchSource = ClipboardSearchSource()

    /// Application search source (skeleton, full impl in US-014).
    private let appSearchSource = AppSearchSource()

    /// File search source (skeleton, full impl in US-015).
    private let fileSearchSource = FileSearchSource()

    /// System command search source (sleep/restart/shutdown/lock/...).
    private let systemCommandSource = SystemCommandSource()

    /// Calculator search source (math expression evaluator).
    private let calculatorSource = CalculatorSource()

    /// Unit / currency converter search source (Foundation Measurement + static FX table).
    private let unitConverterSource = UnitConverterSource()

    /// Unified search view model (created in applicationDidFinishLaunching on main actor).
    private var unifiedSearchViewModel: UnifiedSearchViewModel!

    /// Recent content center view model (US-023). Created on main actor in
    /// `applicationDidFinishLaunching` so it can observe `clipboardItemSaved`
    /// notifications and refresh its date-grouped sections.
    private var recentContentViewModel: RecentContentViewModel!

    /// Screenshot service for region and window capture (macOS 14+).
    private lazy var screenshotService: ScreenshotServiceProtocol? = {
        if #available(macOS 14.0, *) {
            return ScreenshotService()
        }
        return nil
    }()

    /// Post-capture floating toolbar (OCR / Copy / Save / Annotate / Discard).
    /// Created lazily on main actor in `applicationDidFinishLaunching`.
    private var screenshotToolbar: ScreenshotToolbarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Assistant launching")

        // Initialize database
        do {
            try DatabaseManager.shared.setup()
            logger.info("Database initialized successfully")
        } catch {
            logger.error("Database initialization failed: \(error.localizedDescription, privacy: .public)")
        }

        // Ensure Application Support directory exists
        createApplicationSupportDirectory()

        // Keep launch-at-login default aligned with the stored Assistant setting.
        syncLaunchAtLoginPreference()

        // Set up status bar item
        setupStatusItem()

        // Start clipboard monitoring
        startClipboardMonitoring()

        // Start data cleanup service (immediate + hourly)
        cleanupService.start()

        // Register global keyboard shortcut for panel toggle
        registerGlobalShortcuts()

        // Register unified search sources
        unifiedSearchService.registerSource(clipboardSearchSource)
        unifiedSearchService.registerSource(appSearchSource)
        unifiedSearchService.registerSource(fileSearchSource)
        unifiedSearchService.registerSource(systemCommandSource)
        unifiedSearchService.registerSource(calculatorSource)
        unifiedSearchService.registerSource(unitConverterSource)
        logger.info("Unified search service initialized with 6 sources")

        // Create unified search view model (must be on main actor)
        unifiedSearchViewModel = UnifiedSearchViewModel(unifiedSearchService: unifiedSearchService)

        // Create Recent Content Center view model (US-023, must be on main actor).
        // Built here rather than lazily so the .clipboardItemSaved observer is
        // wired up from app launch and the Recent panel is warm on first open.
        recentContentViewModel = RecentContentViewModel()

        // Screenshot post-capture toolbar (US-024). Constructed on main actor
        // so the @MainActor-annotated controller is happy; needs the shared
        // ContentStore so OCR re-recognition writes back to the same DB.
        screenshotToolbar = ScreenshotToolbarController(contentStore: contentStore)

        // Observe search state to resize panel dynamically
        searchStateCancellable = unifiedSearchViewModel.$searchText
            .map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .removeDuplicates()
            .sink { [weak self] isActive in
                self?.resizePanelForSearchState(isActive: isActive)
            }

        // Set up Sparkle auto-update (Sparkle handles launch delay + periodic checks internally)
        updateService.setup()

        // Listen for manual update check requests from MenuBarView
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCheckForUpdates),
            name: .checkForUpdates,
            object: nil
        )

        logger.info("Assistant launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("Assistant terminating")
        cleanupService.stop()
        clipboardMonitor.stop()
        monitorTask?.cancel()
        stopMonitoringEvents()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusMenu = makeStatusMenu()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Mac Super Assistant")
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked(_:))
            button.target = self
        }
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu(title: "Mac Super Assistant")
        menu.autoenablesItems = true

        let openSearch = NSMenuItem(title: "Open Search", action: #selector(openSearchFromMenu), keyEquivalent: "")
        openSearch.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        openSearch.target = self
        menu.addItem(openSearch)

        let clipboard = NSMenuItem(title: "Clipboard", action: #selector(openClipboardFromMenu), keyEquivalent: "")
        clipboard.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: nil)
        clipboard.target = self
        menu.addItem(clipboard)

        let screenshot = NSMenuItem(title: "Screenshot", action: #selector(startScreenshotFromMenu), keyEquivalent: "")
        screenshot.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: nil)
        screenshot.target = self
        menu.addItem(screenshot)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settings.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        settings.target = self
        menu.addItem(settings)

        let about = NSMenuItem(title: "About Mac Super Assistant", action: #selector(openAboutFromMenu), keyEquivalent: "")
        about.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quitFromMenu), keyEquivalent: "q")
        quit.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        logger.info("Status bar menu opened")
        statusItem.menu = statusMenu
        sender.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSearchFromMenu() {
        logger.info("Open Search selected from status menu")
        showPanel()
    }

    @objc private func openClipboardFromMenu() {
        logger.info("Clipboard selected from status menu")
        showPanel()
    }

    @objc private func startScreenshotFromMenu() {
        logger.info("Screenshot selected from status menu")
        performRegionCapture()
    }

    @objc private func openSettingsFromMenu() {
        logger.info("Settings selected from status menu")
        NSApp.sendAction(Selector("showSettingsWindow:"), to: nil, from: nil)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func openAboutFromMenu() {
        logger.info("About selected from status menu")
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Mac Super Assistant",
            .applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0",
            .version: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        ])
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func quitFromMenu() {
        logger.info("Quit selected from status menu")
        NSApp.terminate(nil)
    }

    // MARK: - Panel Management

    func togglePanel() {
        let panelExists = panel != nil
        let panelVisible = panel?.isVisible ?? false
        logger.info("togglePanel called, panel exists: \(panelExists), isVisible: \(panelVisible)")
        if let panel = panel, panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        logger.info("showPanel called")
        // Always recreate the panel for fresh focus state
        closePanel(animate: false)
        panel = nil
        createPanel()

        guard let panel = panel else {
            logger.error("Panel is still nil after createPanel()")
            return
        }

        // Center panel on screen (Alfred-style)
        let panelWidth: CGFloat = 400
        // Recent mode is the default display mode in MenuBarView, which renders
        // at the expanded 500pt height. Open the panel pre-sized so the
        // browse list is visible immediately without a resize animation.
        let panelHeight: CGFloat = 500

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelX = screenFrame.midX - panelWidth / 2
            let panelY = screenFrame.midY + 100 - (panelHeight - 72)  // Anchor on top edge

            panel.setFrame(NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight), display: true)
        }

        // Reset search text when showing panel
        DispatchQueue.main.async { [weak self] in
            self?.unifiedSearchViewModel.searchText = ""
        }

        // Activate the app and show the panel
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        panel.makeKeyAndOrderFront(nil)
        logger.info("Panel made key and front")
        startMonitoringEvents()

        // Focus the text field when the panel becomes key
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(name: .focusSearchField, object: nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationCenter.default.post(name: .focusSearchField, object: nil)
        }

        logger.info("Panel shown")
    }

    func closePanel(animate: Bool = true) {
        guard !isClosingPanel else { return }
        isClosingPanel = true
        stopMonitoringEvents()
        if animate {
            panel?.orderOut(nil)
        } else {
            panel?.close()
        }
        panel = nil
        logger.info("Panel closed")
    }

    /// Resize the panel when search state changes.
    ///
    /// Historically (US-016) this collapsed to 72pt when the search box was
    /// empty. After US-023 the default browse mode (Recent) is also rendered
    /// at the full 500pt height, so the panel stays expanded as long as it's
    /// visible. We keep this hook in case a future "compact" mode reintroduces
    /// the 72pt layout, but the current behaviour is a no-op when expanded.
    private func resizePanelForSearchState(isActive: Bool) {
        guard let panel = panel, panel.isVisible else { return }

        // Always 500pt — Recent (default) and Search both use the expanded layout.
        let targetHeight: CGFloat = 500
        let panelWidth: CGFloat = 400

        // Keep panel centered on screen
        var newFrame: NSRect
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelX = screenFrame.midX - panelWidth / 2
            let panelY = screenFrame.midY + 100 - (targetHeight - 72) / 2  // Adjust for growth
            newFrame = NSRect(x: panelX, y: panelY, width: panelWidth, height: targetHeight)
        } else {
            let currentFrame = panel.frame
            let newY = currentFrame.origin.y + currentFrame.height - targetHeight
            newFrame = NSRect(x: currentFrame.origin.x, y: newY, width: panelWidth, height: targetHeight)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(newFrame, display: true)
        }
    }

    private func createPanel() {
        let panel = FloatingSearchPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.isMovableByWindowBackground = false
        panel.level = .floating
        panel.hidesOnDeactivate = false  // Don't auto-close, we'll handle it manually
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        // Round corners on the window
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 12
        panel.contentView?.layer?.masksToBounds = true

        // Set the SwiftUI content
        let menuBarView = MenuBarView(
            searchViewModel: unifiedSearchViewModel,
            recentViewModel: recentContentViewModel
        )
        let hostingView = NSHostingView(rootView: menuBarView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        panel.contentView?.addSubview(hostingView)
        if let contentView = panel.contentView {
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }

        // Observe when the panel loses key status (user clicked outside our app)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: panel
        )

        self.panel = panel
        logger.info("Panel created successfully")
    }

    @objc private func panelDidResignKey(_ notification: Notification) {
        logger.info("Panel lost key status, closing")
        closePanel()
    }

    // MARK: - Event Monitoring

    private func startMonitoringEvents() {
        guard localEventMonitor == nil else { return }
        isClosingPanel = false

        // Local monitor for clicks that reach our app but are outside the panel
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.panel, panel.isVisible, !self.isClosingPanel else {
                return event
            }
            if !panel.frame.contains(NSEvent.mouseLocation) {
                self.closePanel()
            }
            return event
        }
    }

    private func stopMonitoringEvents() {
        if localEventMonitor != nil {
            NSEvent.removeMonitor(localEventMonitor!)
            localEventMonitor = nil
        }
    }

    // MARK: - Keyboard Shortcuts

    private func registerGlobalShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak self] in
            self?.togglePanel()
        }

        KeyboardShortcuts.onKeyUp(for: .captureRegion) { [weak self] in
            self?.performRegionCapture()
        }

        KeyboardShortcuts.onKeyUp(for: .captureWindow) { [weak self] in
            self?.performWindowCapture()
        }

        logger.info("Global shortcuts registered: togglePanel, captureRegion, captureWindow")
    }

    // MARK: - Screenshot Capture

    /// Perform a region capture.
    /// Hides the panel first, then shows the overlay, and restores the panel after capture.
    private func performRegionCapture() {
        logger.info("Region capture triggered by shortcut")

        // Hide the panel so it doesn't appear in the screenshot
        let wasPanelVisible = panel?.isVisible ?? false
        if wasPanelVisible {
            closePanel()
        }

        Task {
            var shouldRestorePanel = wasPanelVisible
            do {
                guard let screenshotService else {
                    logger.warning("Screenshot service not available (requires macOS 14+)")
                    return
                }
                let result = try await screenshotService.captureRegion()
                // Persist first so the toolbar has a stable itemId for Discard/OCR;
                // ContentStore.processScreenshot is idempotent on duplicate hashes
                // and returns the existing/new row id (US-024).
                let itemId = try await contentStore.processScreenshot(result)
                await MainActor.run { [weak self] in
                    self?.screenshotToolbar.show(
                        itemId: itemId,
                        imageData: result.imageData,
                        sourceType: result.sourceType,
                        anchorRect: result.selectionRect
                    )
                }
                // Keep the app panel hidden because the screenshot overlay remains active.
                shouldRestorePanel = false
                logger.info("Region capture completed and saved, toolbar shown")
            } catch {
                // Don't log user cancellation as an error
                if case SnapVaultError.screenshotFailed(let reason) = error, reason == SnapVaultError.userCancelledReason {
                    logger.debug("Region capture cancelled")
                } else {
                    logger.error("Region capture failed: \(error.localizedDescription, privacy: .public)")
                }
            }

            // Restore panel only when capture mode did not remain active.
            if shouldRestorePanel {
                DispatchQueue.main.async { [weak self] in
                    self?.showPanel()
                }
            }
        }
    }

    /// Perform a window capture.
    /// Hides the panel first, then captures the window under the cursor.
    private func performWindowCapture() {
        logger.info("Window capture triggered by shortcut")

        // Hide the panel so it doesn't appear in the screenshot
        let wasPanelVisible = panel?.isVisible ?? false
        if wasPanelVisible {
            closePanel()
        }

        Task {
            do {
                guard let screenshotService else {
                    logger.warning("Screenshot service not available (requires macOS 14+)")
                    return
                }
                let result = try await screenshotService.captureWindow()
                let itemId = try await contentStore.processScreenshot(result)
                await MainActor.run { [weak self] in
                    self?.screenshotToolbar.show(
                        itemId: itemId,
                        imageData: result.imageData,
                        sourceType: result.sourceType,
                        anchorRect: result.selectionRect
                    )
                }
                logger.info("Window capture completed and saved, toolbar shown")
            } catch {
                // Don't log user cancellation as an error
                if case SnapVaultError.screenshotFailed(let reason) = error, reason == SnapVaultError.userCancelledReason {
                    logger.debug("Window capture cancelled")
                } else {
                    logger.error("Window capture failed: \(error.localizedDescription, privacy: .public)")
                }
            }

            // Restore panel if it was visible before
            if wasPanelVisible {
                DispatchQueue.main.async { [weak self] in
                    self?.showPanel()
                }
            }
        }
    }

    // MARK: - Clipboard Monitoring

    private func startClipboardMonitoring() {
        // Start the monitor (begins polling).
        clipboardMonitor.start()

        // Consume the event stream and forward to ContentStore.
        monitorTask = Task { [weak self] in
            guard let self else { return }
            for await event in self.clipboardMonitor.onNewContent {
                do {
                    let id = try await self.contentStore.processEvent(event)
                    self.logger.debug("Processed clipboard event -> item id=\(id)")
                } catch {
                    self.logger.error("Failed to process clipboard event: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        logger.info("Clipboard monitoring started")
    }

    // MARK: - Update

    @objc private func handleCheckForUpdates() {
        logger.info("Manual update check triggered from UI")
        updateService.checkNow()
    }

    // MARK: - Private

    private func createApplicationSupportDirectory() {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let appDir = appSupport.appendingPathComponent("Assistant")
        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
            logger.debug("Created Application Support directory at \(appDir.path, privacy: .public)")
        }
    }

    private func syncLaunchAtLoginPreference() {
        let repository = ContentRepository()
        let shouldEnable: Bool

        do {
            if let stored = try repository.readSetting(key: SettingKey.launchAtLoginEnabled) {
                shouldEnable = stored == "1"
            } else {
                shouldEnable = true
                try repository.updateSetting(key: SettingKey.launchAtLoginEnabled, value: "1")
            }

            if shouldEnable, SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
                logger.info("Launch at login registered from Assistant default setting")
            } else if !shouldEnable, SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                logger.info("Launch at login unregistered from Assistant user setting")
            }
        } catch {
            logger.error("Failed to sync launch-at-login preference: \(error.localizedDescription, privacy: .public)")
        }
    }
}
