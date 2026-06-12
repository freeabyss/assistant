import Foundation
import KeyboardShortcuts

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var step: OnboardingStep = .welcome
    @Published var permissionStatuses: [PermissionKind: PermissionStatus] = [:]
    @Published var hotkeyValidation: HotkeyValidationResult = .invalid
    @Published var clipboardAcknowledged: Bool = false
    @Published var launchAtLoginEnabled: Bool = true
    @Published var completionErrorMessage: String?

    private let permissionService: PermissionServiceProtocol
    private let hotkeyService: HotkeyValidationServiceProtocol
    private let settingsService: SettingsServiceProtocol
    private let launchAtLoginService: LaunchAtLoginServiceProtocol
    private let onComplete: () -> Void

    init(
        permissionService: PermissionServiceProtocol = PermissionService(),
        hotkeyService: HotkeyValidationServiceProtocol = HotkeyValidationService(),
        settingsService: SettingsServiceProtocol = SettingsService(persistence: .shared),
        launchAtLoginService: LaunchAtLoginServiceProtocol = LaunchAtLoginService(),
        onComplete: @escaping () -> Void = {}
    ) {
        self.permissionService = permissionService
        self.hotkeyService = hotkeyService
        self.settingsService = settingsService
        self.launchAtLoginService = launchAtLoginService
        self.onComplete = onComplete
    }

    var canContinueCurrentStep: Bool {
        switch step {
        case .welcome, .launchAtLogin, .done:
            return true
        case .searchHotkey:
            return hotkeyValidation == .valid
        case .clipboardPrivacy:
            return clipboardAcknowledged
        case .screenRecording:
            return permissionStatuses[.screenRecording]?.isAuthorized == true
        case .accessibility:
            return permissionStatuses[.accessibility]?.isAuthorized == true
        }
    }

    var isCompleteReady: Bool {
        clipboardAcknowledged
            && hotkeyValidation == .valid
            && permissionStatuses[.screenRecording]?.isAuthorized == true
            && permissionStatuses[.accessibility]?.isAuthorized == true
    }

    func onAppear() {
        validateHotkey()
        Task { await refreshPermissions() }
    }

    func continueToNextStep() {
        completionErrorMessage = nil
        switch step {
        case .welcome:
            step = .searchHotkey
            validateHotkey()
        case .searchHotkey:
            guard hotkeyValidation == .valid else { return }
            step = .clipboardPrivacy
        case .clipboardPrivacy:
            guard clipboardAcknowledged else { return }
            step = .screenRecording
            Task { await refreshPermissions() }
        case .screenRecording:
            guard permissionStatuses[.screenRecording]?.isAuthorized == true else { return }
            step = .accessibility
            Task { await refreshPermissions() }
        case .accessibility:
            guard permissionStatuses[.accessibility]?.isAuthorized == true else { return }
            step = .launchAtLogin
        case .launchAtLogin:
            step = .done
        case .done:
            Task { await completeIfPossible() }
        }
    }

    func validateHotkey() {
        hotkeyValidation = hotkeyService.validateCurrentShortcut()
    }

    func acknowledgeClipboard() {
        clipboardAcknowledged = true
    }

    func openPermissionSettings(_ kind: PermissionKind) {
        permissionService.openSystemSettings(for: kind)
    }

    func refreshPermissions() async {
        permissionStatuses = await permissionService.refreshStatuses()
    }

    func completeIfPossible() async {
        validateHotkey()
        await refreshPermissions()
        guard isCompleteReady else {
            completionErrorMessage = L10n.localized("onboarding.error.permissionsRequired")
            if permissionStatuses[.screenRecording]?.isAuthorized != true {
                step = .screenRecording
            } else if permissionStatuses[.accessibility]?.isAuthorized != true {
                step = .accessibility
            } else if hotkeyValidation != .valid {
                step = .searchHotkey
            } else if !clipboardAcknowledged {
                step = .clipboardPrivacy
            }
            return
        }

        do {
            try await settingsService.set(true, for: .onboardingCompleted)
            try await settingsService.set(true, for: .clipboardEnabled)
            try await settingsService.set(hotkeyService.persistCurrentShortcutString(), for: .searchHotkey)
            try await settingsService.set(launchAtLoginEnabled, for: .launchAtLoginEnabled)
            try launchAtLoginService.setEnabled(launchAtLoginEnabled)
            onComplete()
        } catch {
            completionErrorMessage = error.localizedDescription
        }
    }
}

enum OnboardingStep: String, CaseIterable, Hashable {
    case welcome
    case searchHotkey
    case clipboardPrivacy
    case screenRecording
    case accessibility
    case launchAtLogin
    case done
}
