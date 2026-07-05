import AppKit
import Combine
import SwiftUI
import os.log

/// A borderless floating panel that can become key window (for text input).
final class FloatingCommandPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Owns the Command Bar floating `NSPanel` (design §2.5 / §16).
///
/// Behaviour preserved from the original AppDelegate implementation:
/// ⌥Space toggles, ⎋ / click-outside / app-switch dismisses (via resign-key +
/// local event monitor). The hosted SwiftUI content is the existing
/// `SearchPanelView`; the Jade-styled rewrite is deferred to T-011.
@MainActor
final class CommandBarController: NSObject {
    private let logger = Logger.app
    private unowned let container: AppContainer

    private var panel: NSPanel?
    private var viewModel: SearchPanelViewModel?
    private var searchStateCancellable: AnyCancellable?
    private var localEventMonitor: Any?
    private var isClosingPanel = false

    init(container: AppContainer) {
        self.container = container
        super.init()
    }

    // MARK: - Public API

    func toggle() {
        guard container.ensureOnboardingReady() else { return }
        if let panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard container.ensureOnboardingReady() else { return }
        logger.info("CommandBar show")
        // Always recreate the panel for fresh focus state.
        hide(animate: false)
        panel = nil
        createPanel()

        guard let panel else {
            logger.error("Panel is still nil after createPanel()")
            return
        }

        let panelWidth: CGFloat = 640
        let panelHeight: CGFloat = 156
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let x = frame.midX - panelWidth / 2
            let y = frame.midY + 120
            panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        }

        let viewModel = self.viewModel
        DispatchQueue.main.async { viewModel?.open() }

        activateApp()
        panel.makeKeyAndOrderFront(nil)
        startMonitoringEvents()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(name: .focusSearchField, object: nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationCenter.default.post(name: .focusSearchField, object: nil)
        }
        logger.info("CommandBar shown")
    }

    func hide(animate: Bool = true) {
        guard !isClosingPanel else { return }
        isClosingPanel = true
        stopMonitoringEvents()
        if animate {
            panel?.orderOut(nil)
        } else {
            panel?.close()
        }
        panel = nil
        logger.info("CommandBar hidden")
    }

    /// Whether the panel is currently on screen.
    var isVisible: Bool { panel?.isVisible ?? false }

    // MARK: - Panel construction

    private func createPanel() {
        let panel = FloatingCommandPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 156),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.isMovableByWindowBackground = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 12
        panel.contentView?.layer?.masksToBounds = true

        let viewModel = container.makeSearchPanelViewModel { [weak self] in
            self?.hide()
        }
        self.viewModel = viewModel

        searchStateCancellable = viewModel.$query
            .map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .removeDuplicates()
            .sink { [weak self] isActive in
                self?.resizePanel(isActive: isActive)
            }

        let searchPanelView = SearchPanelView(viewModel: viewModel)
            .tint(JadeColor.primary) // 全局主色注入（Design Token T-004）
        let hostingView = NSHostingView(rootView: searchPanelView)
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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: panel
        )

        self.panel = panel
        logger.info("CommandBar panel created")
    }

    private func resizePanel(isActive: Bool) {
        guard let panel, panel.isVisible else { return }
        let targetHeight: CGFloat = isActive ? 560 : 156
        let panelWidth: CGFloat = 640

        let newFrame: NSRect
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let x = frame.midX - panelWidth / 2
            let y = frame.midY + 120 - (isActive ? 180 : 0)
            newFrame = NSRect(x: x, y: y, width: panelWidth, height: targetHeight)
        } else {
            let current = panel.frame
            let newY = current.origin.y + current.height - targetHeight
            newFrame = NSRect(x: current.origin.x, y: newY, width: panelWidth, height: targetHeight)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(newFrame, display: true)
        }
    }

    @objc private func panelDidResignKey(_ notification: Notification) {
        logger.info("CommandBar lost key status, closing")
        hide()
    }

    // MARK: - Event monitoring

    private func startMonitoringEvents() {
        guard localEventMonitor == nil else { return }
        isClosingPanel = false
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel = self.panel, panel.isVisible, !self.isClosingPanel else {
                return event
            }
            if !panel.frame.contains(NSEvent.mouseLocation) {
                self.hide()
            }
            return event
        }
    }

    private func stopMonitoringEvents() {
        guard let monitor = localEventMonitor else { return }
        NSEvent.removeMonitor(monitor)
        localEventMonitor = nil
    }

    private func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
