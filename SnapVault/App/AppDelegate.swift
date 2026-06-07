import Cocoa
import SwiftUI
import KeyboardShortcuts
import Combine
import os.log

/// A borderless floating panel that can become key window (for text input).
class FloatingSearchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// AppKit lifecycle delegate, bridges AppKit-specific setup that SwiftUI cannot handle.
class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger.app

    /// Status bar item showing the clipboard icon.
    private var statusItem: NSStatusItem!

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

    /// Unified search view model (created in applicationDidFinishLaunching on main actor).
    private var unifiedSearchViewModel: UnifiedSearchViewModel!

    /// Screenshot service for region and window capture (macOS 14+).
    private lazy var screenshotService: ScreenshotServiceProtocol? = {
        if #available(macOS 14.0, *) {
            return ScreenshotService()
        }
        return nil
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("SnapVault launching")

        // Initialize database
        do {
            try DatabaseManager.shared.setup()
            logger.info("Database initialized successfully")
        } catch {
            logger.error("Database initialization failed: \(error.localizedDescription, privacy: .public)")
        }

        // Ensure Application Support directory exists
        createApplicationSupportDirectory()

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
        logger.info("Unified search service initialized with 3 sources")

        // Create unified search view model (must be on main actor)
        unifiedSearchViewModel = UnifiedSearchViewModel(unifiedSearchService: unifiedSearchService)

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

        logger.info("SnapVault launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("SnapVault terminating")
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

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "SnapVault")
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked(_:))
            button.target = self
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        logger.info("Status bar button clicked")
        togglePanel()
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
        let panelHeight: CGFloat = 72  // Just enough for search bar

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelX = screenFrame.midX - panelWidth / 2
            let panelY = screenFrame.midY + 100  // Slightly above center

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

    /// Resize the panel when search state changes (empty -> results, results -> empty).
    private func resizePanelForSearchState(isActive: Bool) {
        guard let panel = panel, panel.isVisible else { return }

        let targetHeight: CGFloat = isActive ? 500 : 72
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
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 72),
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
        let menuBarView = MenuBarView(searchViewModel: unifiedSearchViewModel)
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
            do {
                guard let screenshotService else {
                    logger.warning("Screenshot service not available (requires macOS 14+)")
                    return
                }
                let result = try await screenshotService.captureRegion()
                try await contentStore.processScreenshot(result)
                logger.info("Region capture completed and saved")
            } catch {
                // Don't log user cancellation as an error
                if case SnapVaultError.screenshotFailed(let reason) = error, reason == "User cancelled" {
                    logger.debug("Region capture cancelled")
                } else {
                    logger.error("Region capture failed: \(error.localizedDescription, privacy: .public)")
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
                try await contentStore.processScreenshot(result)
                logger.info("Window capture completed and saved")
            } catch {
                logger.error("Window capture failed: \(error.localizedDescription, privacy: .public)")
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
        let appDir = appSupport.appendingPathComponent("SnapVault")
        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
            logger.debug("Created Application Support directory at \(appDir.path, privacy: .public)")
        }
    }
}
