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
            // 触发 TCC 注册，让本 App 出现在系统设置屏幕录制列表（design §4.2，Issue #3）。
            // 返回值不参与前进判定：canContinueCurrentStep 仍由 refreshPermissions 的 preflight 决定。
            _ = permissionService.requestScreenRecordingPrompt()
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
        if kind == .screenRecording {
            // 防止用户绕过 continueToNextStep 直接点“打开设置”仍能触发 TCC 注册（design §4.2）。
            _ = permissionService.requestScreenRecordingPrompt()
        }
        permissionService.openSystemSettings(for: kind)
    }

    func refreshPermissions() async {
        permissionStatuses = await permissionService.refreshStatuses()
    }

    /// 跳过 onboarding：不校验权限、任意步骤均可调用（design §4.2 差异表、PRD P-2.3）。
    func skipOnboarding() async {
        completionErrorMessage = nil
        do {
            // hotkey：持久化当前录入值；未录入时 persistCurrentShortcutString 返回默认 option+space。
            try await settingsService.set(hotkeyService.persistCurrentShortcutString(), for: .searchHotkey)
            // 关键：clipboard.enabled 默认为 "true"（PersistenceController.swift:307）。
            // PRD P-2.3 要求跳过后剪贴板默认关闭（保留用户选择权 / 延后启用），
            // 因此必须显式写 false —— 不能像 design §4.2 差异表所述“不写”，否则读回为 true。
            try await settingsService.set(false, for: .clipboardEnabled)
            try await settingsService.set(true, for: .onboardingCompleted)
            // 不强制 launchAtLogin、不校验任何权限（与 completeIfPossible 的差异）。
            onComplete()
        } catch {
            completionErrorMessage = error.localizedDescription
        }
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
