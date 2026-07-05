import XCTest
import KeyboardShortcuts
@testable import Qingniao

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    private var settings: InMemorySettingsService!
    private var permissions: MockPermissionService!
    private var hotkeys: MockHotkeyValidationService!
    private var launchAtLogin: MockLaunchAtLoginService!
    private var didComplete = false

    override func setUp() async throws {
        settings = InMemorySettingsService()
        permissions = MockPermissionService()
        hotkeys = MockHotkeyValidationService()
        launchAtLogin = MockLaunchAtLoginService()
        didComplete = false
    }

    func testCannotPassClipboardStepUntilAcknowledged() async throws {
        let viewModel = makeViewModel()
        viewModel.step = .clipboardPrivacy

        XCTAssertFalse(viewModel.canContinueCurrentStep)
        viewModel.continueToNextStep()
        XCTAssertEqual(viewModel.step, .clipboardPrivacy)

        viewModel.acknowledgeClipboard()
        XCTAssertTrue(viewModel.canContinueCurrentStep)
        viewModel.continueToNextStep()
        XCTAssertEqual(viewModel.step, .screenRecording)
    }

    func testHotkeyConflictBlocksSearchHotkeyStep() async throws {
        let viewModel = makeViewModel()
        viewModel.step = .searchHotkey
        hotkeys.result = .conflict
        viewModel.validateHotkey()

        XCTAssertFalse(viewModel.canContinueCurrentStep)
        viewModel.continueToNextStep()
        XCTAssertEqual(viewModel.step, .searchHotkey)

        hotkeys.result = .valid
        viewModel.validateHotkey()
        XCTAssertTrue(viewModel.canContinueCurrentStep)
    }

    func testRequiredPermissionsBlockCompletionAndStayOnPermissionStep() async throws {
        let viewModel = makeReadyViewModel()
        permissions.statuses[.screenRecording] = .denied
        viewModel.step = .done

        await viewModel.completeIfPossible()

        XCTAssertFalse(didComplete)
        XCTAssertEqual(viewModel.step, .screenRecording)
        let completed = try await settings.value(for: .onboardingCompleted, as: Bool.self)
        XCTAssertFalse(completed)
    }

    func testCompletingWritesSettingsAndEnablesLaunchAtLogin() async throws {
        let viewModel = makeReadyViewModel()
        viewModel.step = .done

        await viewModel.completeIfPossible()

        let onboardingCompleted = try await settings.value(for: .onboardingCompleted, as: Bool.self)
        let clipboardEnabled = try await settings.value(for: .clipboardEnabled, as: Bool.self)
        let searchHotkey = try await settings.stringValue(for: .searchHotkey)
        let launchSetting = try await settings.value(for: .launchAtLoginEnabled, as: Bool.self)
        let languageMode = try await settings.value(for: .languageMode, as: LanguageMode.self)

        XCTAssertTrue(didComplete)
        XCTAssertTrue(onboardingCompleted)
        XCTAssertTrue(clipboardEnabled)
        XCTAssertEqual(searchHotkey, "option+space")
        XCTAssertTrue(launchSetting)
        XCTAssertTrue(launchAtLogin.enabled)
        XCTAssertEqual(languageMode, .followSystem)
    }

    func testPermissionSettingsAndRefreshAreDelegated() async throws {
        let viewModel = makeViewModel()
        viewModel.openPermissionSettings(.accessibility)
        await viewModel.refreshPermissions()

        XCTAssertEqual(permissions.opened, [.accessibility])
        XCTAssertEqual(viewModel.permissionStatuses[.screenRecording], .authorized)
        XCTAssertEqual(viewModel.permissionStatuses[.accessibility], .authorized)
    }

    // TC-U-002: continueToNextStep 进入 .screenRecording 时触发 request 恰好一次
    func test_continueToNextStep_intoScreenRecording_triggersRequestPromptOnce() async throws {
        let viewModel = makeViewModel()
        viewModel.step = .clipboardPrivacy
        viewModel.acknowledgeClipboard()

        XCTAssertEqual(permissions.requestScreenRecordingCallCount, 0)
        viewModel.continueToNextStep()

        XCTAssertEqual(permissions.requestScreenRecordingCallCount, 1)
        XCTAssertEqual(viewModel.step, .screenRecording)
    }

    // TC-U-003: openPermissionSettings(.screenRecording) 调用顺序 [request, openSettings]
    func test_openPermissionSettings_screenRecording_callsRequestBeforeOpenSettings() async throws {
        let viewModel = makeViewModel()

        viewModel.openPermissionSettings(.screenRecording)

        XCTAssertEqual(permissions.callLog, [
            .request(kind: .screenRecording),
            .openSettings(kind: .screenRecording)
        ])
        XCTAssertEqual(permissions.opened, [.screenRecording])
    }

    // TC-U-003 反向: openPermissionSettings(.accessibility) 不应触发 request
    func test_openPermissionSettings_accessibility_doesNotTriggerRequest() async throws {
        let viewModel = makeViewModel()

        viewModel.openPermissionSettings(.accessibility)

        XCTAssertEqual(permissions.requestScreenRecordingCallCount, 0)
        XCTAssertEqual(permissions.opened, [.accessibility])
    }

    // TC-U-004: skipOnboarding 写 flag、显式 clipboardEnabled=false、回调 onComplete
    func test_skipOnboarding_writesFlagsAndInvokesCompletion() async throws {
        // 前置断言：默认 clipboardEnabled 为 true（PersistenceController.swift:307）
        let defaultClipboard = try await settings.value(for: .clipboardEnabled, as: Bool.self)
        XCTAssertTrue(defaultClipboard)

        let viewModel = makeViewModel()

        await viewModel.skipOnboarding()

        let onboardingCompleted = try await settings.value(for: .onboardingCompleted, as: Bool.self)
        let clipboardEnabled = try await settings.value(for: .clipboardEnabled, as: Bool.self)

        XCTAssertTrue(onboardingCompleted)
        XCTAssertFalse(clipboardEnabled)
        XCTAssertTrue(didComplete)
    }

    // TC-U-005: 7 步参数化（每步新构造 VM）
    func test_skipOnboarding_worksFromAnyStep() async throws {
        XCTAssertEqual(OnboardingStep.allCases.count, 7)

        for step in OnboardingStep.allCases {
            let localSettings = InMemorySettingsService()
            var localDidComplete = false
            let viewModel = OnboardingViewModel(
                permissionService: MockPermissionService(),
                hotkeyService: MockHotkeyValidationService(),
                settingsService: localSettings,
                launchAtLoginService: MockLaunchAtLoginService()
            ) {
                localDidComplete = true
            }
            viewModel.step = step

            await viewModel.skipOnboarding()

            let onboardingCompleted = try await localSettings.value(for: .onboardingCompleted, as: Bool.self)
            let clipboardEnabled = try await localSettings.value(for: .clipboardEnabled, as: Bool.self)
            XCTAssertTrue(onboardingCompleted, "onboardingCompleted false at step \(step)")
            XCTAssertFalse(clipboardEnabled, "clipboardEnabled true at step \(step)")
            XCTAssertTrue(localDidComplete, "onComplete not called at step \(step)")
        }
    }

    // TC-U-006: hotkey 已录入分支验证持久化
    func test_skipOnboarding_persistsHotkeyWhenRecorded() async throws {
        hotkeys.persisted = "option+space"
        let viewModel = makeViewModel()
        viewModel.step = .searchHotkey

        await viewModel.skipOnboarding()

        let searchHotkey = try await settings.stringValue(for: .searchHotkey)
        XCTAssertEqual(searchHotkey, "option+space")
    }

    private func makeReadyViewModel() -> OnboardingViewModel {
        let viewModel = makeViewModel()
        viewModel.clipboardAcknowledged = true
        viewModel.hotkeyValidation = .valid
        viewModel.permissionStatuses = [.screenRecording: .authorized, .accessibility: .authorized]
        return viewModel
    }

    private func makeViewModel() -> OnboardingViewModel {
        OnboardingViewModel(
            permissionService: permissions,
            hotkeyService: hotkeys,
            settingsService: settings,
            launchAtLoginService: launchAtLogin
        ) { [weak self] in
            self?.didComplete = true
        }
    }
}

final class MockPermissionService: PermissionServiceProtocol {
    enum PermissionCall: Equatable {
        case request(kind: PermissionKind)
        case openSettings(kind: PermissionKind)
    }

    var statuses: [PermissionKind: PermissionStatus] = [.screenRecording: .authorized, .accessibility: .authorized]
    var opened: [PermissionKind] = []
    private(set) var callLog: [PermissionCall] = []

    var requestScreenRecordingResult: Bool = false
    private(set) var requestScreenRecordingCallCount: Int = 0

    var onDemandAccessibilityResult: Bool = false
    private(set) var onDemandAccessibilityCallCount: Int = 0

    func status(for permission: PermissionKind) -> PermissionStatus {
        statuses[permission] ?? .unknown
    }

    func openSystemSettings(for permission: PermissionKind) {
        opened.append(permission)
        callLog.append(.openSettings(kind: permission))
    }

    func refreshStatuses() async -> [PermissionKind: PermissionStatus] {
        statuses
    }

    func requestScreenRecordingPrompt() -> Bool {
        callLog.append(.request(kind: .screenRecording))
        requestScreenRecordingCallCount += 1
        return requestScreenRecordingResult
    }

    func onDemandAccessibilityCheck() -> Bool {
        onDemandAccessibilityCallCount += 1
        return onDemandAccessibilityResult
    }
}

private final class MockHotkeyValidationService: HotkeyValidationServiceProtocol {
    var result: HotkeyValidationResult = .valid
    var persisted = "option+space"

    func currentShortcut() -> KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.Shortcut(.space, modifiers: [.option])
    }

    func validateCurrentShortcut() -> HotkeyValidationResult {
        result
    }

    func persistCurrentShortcutString() -> String {
        persisted
    }
}

private final class MockLaunchAtLoginService: LaunchAtLoginServiceProtocol {
    var enabled = false

    func isEnabled() -> Bool { enabled }

    func setEnabled(_ enabled: Bool) throws {
        self.enabled = enabled
    }
}

private actor InMemorySettingsService: SettingsServiceProtocol {
    private var values = AssistantSettingDefaults.values

    func value<T: Decodable>(for key: SettingKey, as type: T.Type) async throws -> T {
        let raw = try await stringValue(for: key)
        if type == Bool.self, let bool = (["true", "1", "yes", "on"].contains(raw.lowercased())) as? T { return bool }
        if type == String.self, let string = raw as? T { return string }
        if type == ClipboardRetention.self, let value = ClipboardRetention(rawValue: raw) as? T { return value }
        if type == LanguageMode.self, let value = LanguageMode(rawValue: raw) as? T { return value }
        return try JSONDecoder().decode(type, from: Data(raw.utf8))
    }

    func set<T: Encodable>(_ value: T, for key: SettingKey) async throws {
        switch value {
        case let bool as Bool:
            values[key.rawValue] = bool ? "true" : "false"
        case let string as String:
            values[key.rawValue] = string
        default:
            let data = try JSONEncoder().encode(value)
            values[key.rawValue] = String(data: data, encoding: .utf8)
        }
    }

    func reset(key: SettingKey) async throws {
        values[key.rawValue] = AssistantSettingDefaults.values[key.rawValue]
    }

    func stringValue(for key: SettingKey) async throws -> String {
        values[key.rawValue] ?? ""
    }
}
