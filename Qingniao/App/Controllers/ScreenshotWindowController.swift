import AppKit
import os.log

/// Thin wrapper around the screenshot capture + preview flow (design §2.5).
///
/// Owns the existing `ScreenshotToolbarController` (which in turn hosts the
/// preview window + annotation editor) and moves the region/window/full-screen
/// capture orchestration out of AppDelegate. The capture UI itself is not
/// rewritten here — that is T-014.
@MainActor
final class ScreenshotWindowController {
    private let logger = Logger.screenshot
    private unowned let container: AppContainer

    /// Created lazily so the toolbar controller is only built on first capture.
    private lazy var toolbar = ScreenshotToolbarController()

    init(container: AppContainer) {
        self.container = container
    }

    func captureRegion() {
        performCapture(kind: "region") { try await self.container.screenshotService.captureRegion() }
    }

    func captureWindow() {
        performCapture(kind: "window") { try await self.container.screenshotService.captureWindow() }
    }

    func captureFullScreen() {
        performCapture(kind: "full screen") { try await self.container.screenshotService.captureScreen() }
    }

    // MARK: - Shared capture flow

    private func performCapture(kind: String, _ capture: @escaping () async throws -> ScreenshotResult) {
        guard container.ensureOnboardingReady() else { return }
        logger.info("\(kind, privacy: .public) capture triggered")
        guard ensureScreenRecordingPermission() else { return }

        // Hide the command bar so it doesn't appear in the screenshot.
        let wasCommandBarVisible = container.commandBarController.isVisible
        if wasCommandBarVisible {
            container.commandBarController.hide()
        }

        Task {
            var shouldRestoreCommandBar = wasCommandBarVisible
            do {
                let result = try await capture()
                await MainActor.run { [weak self] in
                    self?.toolbar.show(result: result)
                }
                // Keep the command bar hidden while the preview is active.
                shouldRestoreCommandBar = false
                logger.info("\(kind, privacy: .public) capture completed, preview shown")
            } catch {
                if case SnapVaultError.screenshotFailed(let reason) = error, reason == SnapVaultError.userCancelledReason {
                    logger.debug("\(kind, privacy: .public) capture cancelled")
                } else {
                    logger.error("\(kind, privacy: .public) capture failed: \(error.localizedDescription, privacy: .public)")
                }
            }

            if shouldRestoreCommandBar {
                DispatchQueue.main.async { [weak self] in
                    self?.container.commandBarController.show()
                }
            }
        }
    }

    private func ensureScreenRecordingPermission() -> Bool {
        let permissionService = PermissionService()
        guard permissionService.status(for: .screenRecording).isAuthorized else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = L10n.localized("screenshot.permission.title")
            alert.informativeText = L10n.localized("screenshot.permission.message")
            alert.addButton(withTitle: L10n.localized("screenshot.permission.openSettings"))
            alert.addButton(withTitle: L10n.localized("screenshot.permission.cancel"))
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                _ = permissionService.requestScreenRecordingPrompt()
                permissionService.openSystemSettings(for: .screenRecording)
            }
            return false
        }
        return true
    }
}
