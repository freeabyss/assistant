import Foundation
import Combine
import Sparkle
import os.log

/// Protocol for update service operations.
protocol UpdateServiceProtocol {
    /// Check for updates and return update info if available.
    func checkForUpdates() async throws -> UpdateInfo?

    /// Trigger a user-facing MVP update check.
    func checkNow()
}

/// Describes an available update returned by the appcast feed.
struct UpdateInfo {
    let version: String
    let releaseNotes: String
    let downloadURL: URL
    let isCritical: Bool
}

/// Update service for the MVP release flow.
///
/// Responsibilities:
/// - Creates and owns an `SPUStandardUpdaterController` only for future-compatible Sparkle setup.
/// - Implements `SPUUpdaterDelegate` to react to any Sparkle events if the legacy feed is enabled later.
/// - Exposes `checkNow()` for the MVP user-facing update action, which opens GitHub Releases manually.
///
/// MVP update policy:
/// - User-facing update checks open the project download page / GitHub Releases.
/// - The MVP does not auto-download, auto-install, or restart to update.
/// - Sparkle automatic checks are disabled in Info.plist for the MVP.
///
/// Info.plist keys retained for future release channels:
/// - `SUFeedURL` – URL to the appcast.xml feed
/// - `SUPublicEDKey` – EdDSA public key for verifying update signatures
/// - `SUEnableAutomaticChecks` – false for MVP
/// - `SUScheduledCheckInterval` – 86400 (seconds)
final class UpdateService: NSObject, UpdateServiceProtocol, SPUUpdaterDelegate {
    private let logger = Logger.update
    private let updateCheckService: UpdateCheckServiceProtocol

    /// 启动期是否自动启动 Sparkle updater。
    /// MVP 阶段"检查更新"通过 checkNow() 跳转 GitHub Releases，不依赖 Sparkle 自动流程；
    /// Sparkle 2 在 SUPublicEDKey 未配置时启动会弹出"无法启动更新程序"错误（Issue #1）。
    /// 一旦启用真自动更新（生成 EdDSA 密钥并补齐 appcast 签名），改为 true 即可。
    static let startsUpdaterAutomatically: Bool = false

    /// Sparkle updater controller. Created once in `setup()`.
    private var updaterController: SPUStandardUpdaterController?

    init(updateCheckService: UpdateCheckServiceProtocol = WebUpdateCheckService()) {
        self.updateCheckService = updateCheckService
        super.init()
    }

    /// Whether the user can initiate a manual check right now.
    @objc dynamic var canCheckForUpdates: Bool = false

    // MARK: - Setup

    /// Initialize the Sparkle updater controller.
    /// Must be called once during app launch (from `AppDelegate.applicationDidFinishLaunching`).
    func setup() {
        logger.info("Setting up Sparkle updater controller")

        let controller = SPUStandardUpdaterController(
            startingUpdater: Self.startsUpdaterAutomatically,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        self.updaterController = controller

        // Bind canCheckForUpdates so the UI can react.
        // SPUStandardUpdaterController already exposes this via KVO.
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] canCheck in
                self?.canCheckForUpdates = canCheck
                self?.logger.debug("canCheckForUpdates changed to \(canCheck)")
            }
            .store(in: &cancellables)

        logger.info("Sparkle updater controller initialized (automatic checks disabled for MVP)")
    }

    /// Combine cancellables for KVO subscriptions.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UpdateServiceProtocol

    func checkForUpdates() async throws -> UpdateInfo? {
        guard let updater = updaterController?.updater else {
            logger.error("checkForUpdates: updater not initialized")
            return nil
        }

        // Trigger Sparkle's check; the updater will present its own UI if an update is found.
        // We use the delegate callbacks (updaterDidNotFindUpdate / updater:didFindValidUpdate:)
        // to track state, but from the caller's perspective this is fire-and-forget.
        await MainActor.run {
            updater.checkForUpdates()
        }

        logger.info("checkForUpdates triggered via Sparkle")
        return nil
    }

    func checkNow() {
        logger.info("Manual update check requested; opening releases page for MVP")
        updateCheckService.openDownloadPage()
    }

    // MARK: - SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        logger.error("Sparkle updater aborted with error: \(error.localizedDescription, privacy: .public)")
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        logger.info("Sparkle found update: \(version, privacy: .public)")
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        logger.debug("Sparkle: no update available")
    }

    func updaterDidFinishLoading(_ updater: SPUUpdater) {
        logger.debug("Sparkle updater finished loading")
    }

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        // No beta/alpha channels by default.
        return []
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        // Use the SUFeedURL from Info.plist (default behavior).
        return nil
    }

    /// Allows Sparkle to handle the "what's new" URL if defined in the appcast.
    func updater(_ updater: SPUUpdater, userDidMake choice: SPUUserUpdateChoice, forUpdate item: SUAppcastItem) {
        logger.debug("User made update choice: \(choice.rawValue) for version \(item.displayVersionString, privacy: .public)")
    }
}
