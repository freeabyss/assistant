import Cocoa
import SwiftUI
import os.log

/// AppKit lifecycle delegate. In v1.2 (T-006) this is reduced to lifecycle
/// callbacks plus first-run onboarding; all data bootstrap, service lifecycle
/// and window/status/command/screenshot management is delegated to
/// `AppContainer` and its controllers.
class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger.app

    /// Dependency injection root — owns services and window controllers.
    private let container = AppContainer()

    /// First-run onboarding window. While visible, full product entry points remain gated.
    private var onboardingWindow: NSWindow?

    /// Whether the user completed the required first-run onboarding flow.
    private var isOnboardingCompleted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Qingniao launching")

        container.bootstrapDataStack { [weak self] backupURL in
            self?.presentMigrationFallbackAlert(backupURL: backupURL)
        }

        isOnboardingCompleted = container.loadOnboardingCompletionState()
        container.syncLaunchAtLoginPreference()

        // Gate all controller entry points behind first-run onboarding.
        container.onboardingGate = { [weak self] in self?.ensureOnboardingGate() ?? true }
        container.statusItemController.onStartScreenshot = { [weak self] in
            self?.container.screenshotWindowController.captureRegion()
        }
        container.statusItemController.install()

        if isOnboardingCompleted {
            startFullExperienceServices()
        } else {
            showOnboardingWindow()
        }

        container.updateService.setup()
        container.registerCommandObservers()

        logger.info("Qingniao launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("Qingniao terminating")
        container.stopRuntimeServices()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - Startup wiring

    @MainActor
    private func startFullExperienceServices() {
        container.startFullExperienceServices()
        container.globalShortcutManager.setupShortcuts()
    }

    // MARK: - Onboarding

    @MainActor
    private func showOnboardingWindow() {
        guard onboardingWindow == nil else {
            onboardingWindow?.makeKeyAndOrderFront(nil)
            activateApp()
            return
        }

        let settingsService = SettingsService(persistence: .shared)
        let viewModel = OnboardingViewModel(settingsService: settingsService) { [weak self] in
            guard let self else { return }
            self.isOnboardingCompleted = true
            self.onboardingWindow?.close()
            self.onboardingWindow = nil
            self.startFullExperienceServices()
        }
        let view = OnboardingView(viewModel: viewModel)
            .tint(JadeColor.primary) // 全局主色注入（Design Token T-004）
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.localized("onboarding.welcome.title")
        window.center()
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        activateApp()
    }

    @MainActor
    private func ensureOnboardingGate() -> Bool {
        if isOnboardingCompleted { return true }
        if onboardingWindow == nil {
            showOnboardingWindow()
        } else {
            onboardingWindow?.makeKeyAndOrderFront(nil)
            activateApp()
        }
        return false
    }

    // MARK: - Helpers

    @MainActor
    private func presentMigrationFallbackAlert(backupURL: URL) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.localized("data.migration.failed.title")
        alert.informativeText = L10n.localized("data.migration.failed.message", backupURL.path)
        alert.addButton(withTitle: L10n.localized("data.migration.failed.reveal"))
        alert.addButton(withTitle: L10n.localized("data.migration.failed.dismiss"))
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([backupURL])
        }
    }

    private func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
