import Cocoa
import SwiftUI
import os.log

/// AppKit lifecycle delegate, bridges AppKit-specific setup that SwiftUI cannot handle.
class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger.app

    /// Status bar item showing the clipboard icon.
    private var statusItem: NSStatusItem!

    /// Floating panel that hosts the main SwiftUI view.
    private var panel: NSPanel?

    /// Local event monitor to detect clicks outside the panel.
    private var localEventMonitor: Any?

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

        logger.info("SnapVault launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("SnapVault terminating")
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
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
        togglePanel()
    }

    // MARK: - Panel Management

    func togglePanel() {
        if let panel = panel, panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        if panel == nil {
            createPanel()
        }

        guard let panel = panel, let statusButton = statusItem.button else { return }

        // Position panel below the status bar icon
        if let buttonWindow = statusButton.window {
            let buttonRect = buttonWindow.convertToScreen(statusButton.frame)
            let panelWidth: CGFloat = 400
            let panelHeight: CGFloat = 500

            let panelX = buttonRect.midX - panelWidth / 2
            let panelY = buttonRect.minY - panelHeight - 4

            panel.setFrame(NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight), display: true)
        }

        panel.makeKeyAndOrderFront(nil)
        startMonitoringEvents()

        logger.info("Panel shown")
    }

    func closePanel() {
        stopMonitoringEvents()
        panel?.orderOut(nil)
        logger.info("Panel closed")
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear

        // Set the SwiftUI content
        let menuBarView = MenuBarView()
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

        self.panel = panel
    }

    // MARK: - Event Monitoring

    private func startMonitoringEvents() {
        guard localEventMonitor == nil else { return }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.panel, panel.isVisible else {
                return event
            }

            // If click is inside the panel, let it through
            if panel.frame.contains(NSEvent.mouseLocation) {
                return event
            }

            // If click is on the status bar button, let it through (toggle will handle it)
            if let statusButton = self.statusItem.button,
               let buttonWindow = statusButton.window {
                let buttonFrame = buttonWindow.convertToScreen(statusButton.frame)
                if buttonFrame.contains(NSEvent.mouseLocation) {
                    return event
                }
            }

            // Click is outside panel and not on status bar - close panel
            self.closePanel()
            return event
        }
    }

    private func stopMonitoringEvents() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
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
