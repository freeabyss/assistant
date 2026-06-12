import SwiftUI
import KeyboardShortcuts

struct OnboardingView: View {
    @StateObject var viewModel: OnboardingViewModel

    init(viewModel: OnboardingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 24) {
            header
            stepContent
            footer
        }
        .padding(32)
        .frame(width: 680, height: 520)
        .onAppear { viewModel.onAppear() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(.accentColor)
            Text(title)
                .font(.largeTitle.weight(.bold))
            Text(subtitle)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .welcome:
            bulletList([
                L10n.localized("onboarding.welcome.point.search"),
                L10n.localized("onboarding.welcome.point.clipboard"),
                L10n.localized("onboarding.welcome.point.screenshot")
            ])
        case .searchHotkey:
            VStack(spacing: 14) {
                Text(L10n.localized("onboarding.hotkey.description"))
                    .multilineTextAlignment(.center)
                KeyboardShortcuts.Recorder(for: .togglePanel)
                    .onChange(of: KeyboardShortcuts.getShortcut(for: .togglePanel)) { _ in
                        viewModel.validateHotkey()
                    }
                validationRow
                Button(L10n.localized("onboarding.hotkey.recheck")) {
                    viewModel.validateHotkey()
                }
            }
        case .clipboardPrivacy:
            VStack(alignment: .leading, spacing: 14) {
                bulletList([
                    L10n.localized("onboarding.clipboard.point.defaultOn"),
                    L10n.localized("onboarding.clipboard.point.localOnly"),
                    L10n.localized("onboarding.clipboard.point.control")
                ])
                Toggle(isOn: Binding(get: { viewModel.clipboardAcknowledged }, set: { if $0 { viewModel.acknowledgeClipboard() } })) {
                    Text(L10n.localized("onboarding.clipboard.acknowledge"))
                }
                .toggleStyle(.checkbox)
            }
        case .screenRecording:
            permissionStep(kind: .screenRecording)
        case .accessibility:
            permissionStep(kind: .accessibility)
        case .launchAtLogin:
            VStack(spacing: 12) {
                Text(L10n.localized("onboarding.launchAtLogin.description"))
                    .multilineTextAlignment(.center)
                Toggle(isOn: $viewModel.launchAtLoginEnabled) {
                    Text(L10n.localized("onboarding.launchAtLogin.toggle"))
                }
                .toggleStyle(.checkbox)
            }
        case .done:
            VStack(spacing: 12) {
                Text(L10n.localized("onboarding.done.description"))
                    .multilineTextAlignment(.center)
                if let message = viewModel.completionErrorMessage {
                    Text(message)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            ProgressView(value: Double(OnboardingStep.allCases.firstIndex(of: viewModel.step) ?? 0) + 1, total: Double(OnboardingStep.allCases.count))
                .frame(width: 360)
            HStack {
                Button(L10n.localized("onboarding.quit")) {
                    NSApp.terminate(nil)
                }
                Spacer()
                Button(primaryButtonTitle) {
                    viewModel.continueToNextStep()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canContinueCurrentStep)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var validationRow: some View {
        HStack(spacing: 8) {
            Image(systemName: viewModel.hotkeyValidation == .valid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(viewModel.hotkeyValidation == .valid ? .green : .orange)
            Text(hotkeyValidationText)
                .foregroundColor(viewModel.hotkeyValidation == .valid ? .secondary : .orange)
        }
        .font(.callout)
    }

    private func permissionStep(kind: PermissionKind) -> some View {
        VStack(spacing: 14) {
            Text(kind == .screenRecording ? L10n.localized("onboarding.screenRecording.description") : L10n.localized("onboarding.accessibility.description"))
                .multilineTextAlignment(.center)
            if kind == .accessibility {
                Text(L10n.localized("onboarding.accessibility.boundary"))
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            permissionStatusRow(kind: kind)
            HStack {
                Button(L10n.localized("onboarding.permission.openSettings")) {
                    viewModel.openPermissionSettings(kind)
                }
                Button(L10n.localized("onboarding.permission.recheck")) {
                    Task { await viewModel.refreshPermissions() }
                }
            }
            Text(L10n.localized("onboarding.permission.required"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func permissionStatusRow(kind: PermissionKind) -> some View {
        let authorized = viewModel.permissionStatuses[kind]?.isAuthorized == true
        return HStack(spacing: 8) {
            Image(systemName: authorized ? "checkmark.circle.fill" : "lock.fill")
                .foregroundColor(authorized ? .green : .orange)
            Text(authorized ? L10n.localized("onboarding.permission.authorized") : L10n.localized("onboarding.permission.notAuthorized"))
        }
        .font(.callout)
    }

    private func bulletList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.accentColor)
                    Text(item)
                }
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    private var iconName: String {
        switch viewModel.step {
        case .welcome: return "sparkles"
        case .searchHotkey: return "keyboard"
        case .clipboardPrivacy: return "clipboard"
        case .screenRecording: return "camera.viewfinder"
        case .accessibility: return "accessibility"
        case .launchAtLogin: return "power"
        case .done: return "checkmark.seal"
        }
    }

    private var title: String { L10n.localized("onboarding.\(viewModel.step.rawValue).title") }
    private var subtitle: String { L10n.localized("onboarding.\(viewModel.step.rawValue).subtitle") }
    private var primaryButtonTitle: String { viewModel.step == .done ? L10n.localized("onboarding.finish") : L10n.localized("onboarding.continue") }

    private var hotkeyValidationText: String {
        switch viewModel.hotkeyValidation {
        case .valid: return L10n.localized("onboarding.hotkey.valid")
        case .conflict: return L10n.localized("onboarding.hotkey.conflict")
        case .invalid: return L10n.localized("onboarding.hotkey.invalid")
        }
    }
}
