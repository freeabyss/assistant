import Foundation
import Combine
import Sparkle
import os.log

/// Protocol for update service operations.
protocol UpdateServiceProtocol {
    /// Check for updates and return update info if available.
    func checkForUpdates() async throws -> UpdateInfo?

    /// Trigger an immediate update check via Sparkle UI.
    func checkNow()
}

/// Describes an available update returned by the appcast feed.
struct UpdateInfo {
    let version: String
    let releaseNotes: String
    let downloadURL: URL
    let isCritical: Bool
}

/// Auto-update service powered by Sparkle 2.x.
///
/// Responsibilities:
/// - Creates and owns an `SPUStandardUpdaterController` (which manages the `SPUUpdater` lifecycle).
/// - Implements `SPUUpdaterDelegate` to react to update events.
/// - Exposes `checkNow()` for manual update checks triggered by the user.
///
/// Automatic checks:
/// - Sparkle's built-in scheduler handles "check on launch (with delay)" and
///   periodic checks based on `SUScheduledCheckInterval` in Info.plist (default 86400s = 24h).
/// - No custom timer is needed; Sparkle manages this internally.
///
/// Info.plist keys required:
/// - `SUFeedURL` – URL to the appcast.xml feed
/// - `SUPublicEDKey` – EdDSA public key for verifying update signatures
/// - `SUEnableAutomaticChecks` – true
/// - `SUScheduledCheckInterval` – 86400 (seconds)
final class UpdateService: NSObject, UpdateServiceProtocol, SPUUpdaterDelegate {
    private let logger = Logger.update

    /// Sparkle updater controller. Created once in `setup()`.
    private var updaterController: SPUStandardUpdaterController?

    /// Whether the user can initiate a manual check right now.
    @objc dynamic var canCheckForUpdates: Bool = false

    // MARK: - Setup

    /// Initialize the Sparkle updater controller.
    /// Must be called once during app launch (from `AppDelegate.applicationDidFinishLaunching`).
    func setup() {
        logger.info("Setting up Sparkle updater controller")

        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
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

        logger.info("Sparkle updater controller initialized (automatic checks enabled)")
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
        logger.info("Manual update check requested")
        updaterController?.checkForUpdates(nil)
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
