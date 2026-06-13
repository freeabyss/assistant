import XCTest
import KeyboardShortcuts
@testable import SnapVault

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

private final class MockPermissionService: PermissionServiceProtocol {
    var statuses: [PermissionKind: PermissionStatus] = [.screenRecording: .authorized, .accessibility: .authorized]
    var opened: [PermissionKind] = []

    func status(for permission: PermissionKind) -> PermissionStatus {
        statuses[permission] ?? .unknown
    }

    func openSystemSettings(for permission: PermissionKind) {
        opened.append(permission)
    }

    func refreshStatuses() async -> [PermissionKind: PermissionStatus] {
        statuses
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
