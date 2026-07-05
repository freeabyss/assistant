import AppKit
import KeyboardShortcuts
import SwiftUI
import UniformTypeIdentifiers

/// US-015 Management Center: overview, clipboard history, settings, permissions.
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var clipboardViewModel = ClipboardListViewModel()

    var body: some View {
        ManagementCenterView(viewModel: viewModel, clipboardViewModel: clipboardViewModel)
            .frame(minWidth: 920, minHeight: 640)
    }
}

struct ManagementCenterView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var clipboardViewModel: ClipboardListViewModel

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .task { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .openManagementCenter)) { notification in
            if let route = notification.object as? SettingsRoute {
                viewModel.select(route: route)
            } else if let page = notification.object as? ManagementCenterPage {
                viewModel.select(page: page)
            } else {
                viewModel.select(page: .overview)
            }
        }
        .alert(L10n.localized("management.error.title"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(L10n.localized("settings.alert.ok")) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert(L10n.localized("management.language.restart.title"), isPresented: $viewModel.showLanguageRestartAlert) {
            Button(L10n.localized("settings.alert.ok"), role: .cancel) {}
        } message: {
            Text(L10n.localized("management.language.restart.message"))
        }
    }

    private var sidebar: some View {
        List(selection: $viewModel.selectedPage) {
            Section(L10n.localized("management.title")) {
                ForEach(ManagementCenterPage.allCases) { page in
                    Label(page.title, systemImage: page.iconName)
                        .tag(page)
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 240)
    }

    @ViewBuilder
    private var detail: some View {
        switch viewModel.selectedPage {
        case .overview:
            ManagementOverviewView(viewModel: viewModel)
        case .clipboard:
            ClipboardListView(viewModel: clipboardViewModel)
        case .settings:
            ManagementSettingsPage(viewModel: viewModel)
        case .permissions:
            PermissionsManagementPage(viewModel: viewModel)
        case .about:
            AboutManagementPage()
        }
    }
}

struct ManagementOverviewView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pageHeader(
                    title: L10n.localized("management.overview.title"),
                    subtitle: L10n.localized("management.overview.subtitle"),
                    icon: "sparkles"
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 14)], spacing: 14) {
                    OverviewCard(
                        title: L10n.localized("management.overview.quickEntries"),
                        value: L10n.localized("management.overview.quickEntries.value"),
                        subtitle: L10n.localized("management.overview.quickEntries.subtitle"),
                        icon: "square.grid.2x2"
                    )
                    OverviewCard(
                        title: L10n.localized("management.overview.permissions"),
                        value: viewModel.permissionSummary,
                        subtitle: L10n.localized("management.overview.permissions.subtitle"),
                        icon: "lock.shield"
                    )
                    OverviewCard(
                        title: L10n.localized("management.overview.sources"),
                        value: viewModel.enabledSourceNames,
                        subtitle: L10n.localized("management.overview.sources.subtitle"),
                        icon: "magnifyingglass"
                    )
                    OverviewCard(
                        title: L10n.localized("management.overview.hotkey"),
                        value: viewModel.searchHotkeyDescription,
                        subtitle: L10n.localized("management.overview.hotkey.subtitle"),
                        icon: "keyboard"
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.localized("management.overview.actions"))
                        .font(.headline)
                    HStack(spacing: 10) {
                        quickButton(.clipboard)
                        quickButton(.settings)
                        quickButton(.permissions)
                    }
                }
            }
            .padding(24)
        }
    }

    private func quickButton(_ page: ManagementCenterPage) -> some View {
        Button {
            viewModel.select(page: page)
        } label: {
            Label(page.title, systemImage: page.iconName)
        }
    }
}

struct OverviewCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                Spacer()
            }
            Text(title)
                .font(.headline)
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .lineLimit(2)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ManagementSettingsPage: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pageHeader(
                    title: L10n.localized("management.settings.title"),
                    subtitle: L10n.localized("management.settings.subtitle"),
                    icon: "slider.horizontal.3"
                )

                section(L10n.localized("management.settings.shortcuts")) {
                    shortcutRow(L10n.localized("management.shortcuts.search"), name: .togglePanel, recorder: KeyboardShortcuts.Recorder(for: .togglePanel))
                    shortcutRow(L10n.localized("management.shortcuts.captureRegion"), name: .captureRegion, recorder: KeyboardShortcuts.Recorder(for: .captureRegion))
                    shortcutRow(L10n.localized("management.shortcuts.captureWindow"), name: .captureWindow, recorder: KeyboardShortcuts.Recorder(for: .captureWindow))
                    shortcutRow(L10n.localized("management.shortcuts.captureFullscreen"), name: .captureFullscreen, recorder: KeyboardShortcuts.Recorder(for: .captureFullscreen))
                    shortcutRow(L10n.localized("management.shortcuts.clipboardHistory"), name: .openClipboardHistory, recorder: KeyboardShortcuts.Recorder(for: .openClipboardHistory))
                    shortcutRow(L10n.localized("management.shortcuts.openSettings"), name: .openSettings, recorder: KeyboardShortcuts.Recorder(for: .openSettings))
                    HStack {
                        Spacer()
                        Button(L10n.localized("settings.restoreDefaults")) {
                            viewModel.resetAllShortcutsToDefaults()
                        }
                    }
                }

                section(L10n.localized("management.settings.sources")) {
                    ForEach($viewModel.sourceToggles) { $source in
                        Toggle(isOn: $source.isEnabled) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(source.title)
                                    Text(source.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: source.iconName)
                            }
                        }
                    }
                }

                section(L10n.localized("management.settings.clipboard")) {
                    Toggle(isOn: $viewModel.clipboardEnabled) {
                        Text(L10n.localized("management.clipboard.enabled"))
                    }

                    Picker(L10n.localized("management.clipboard.retention"), selection: $viewModel.clipboardRetention) {
                        ForEach(SettingsViewModel.retentionOptions, id: \.self) { retention in
                            Text(viewModel.retentionTitle(retention)).tag(retention)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                section(L10n.localized("management.settings.screenshot")) {
                    HStack {
                        Text(L10n.localized("management.screenshot.saveDirectory"))
                        Spacer()
                        Text(viewModel.screenshotSaveDirectory.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button(L10n.localized("management.screenshot.choose")) {
                            viewModel.showDirectoryImporter = true
                        }
                    }
                }

                section(L10n.localized("management.settings.system")) {
                    Toggle(isOn: $viewModel.launchAtLoginEnabled) {
                        Text(L10n.localized("settings.launchAtLogin"))
                    }

                    Picker(L10n.localized("settings.language"), selection: $viewModel.languageMode) {
                        ForEach(SettingsViewModel.languageOptions, id: \.self) { language in
                            Text(viewModel.languageTitle(language)).tag(language)
                        }
                    }
                }

                BlacklistManagementSection(viewModel: viewModel)

                HStack {
                    if let status = viewModel.statusMessage {
                        Label(status, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    Spacer()
                    Button(L10n.localized("settings.restoreDefaults")) {
                        Task { await viewModel.resetSettingsToDefaults() }
                    }
                    Button(L10n.localized("settings.save")) {
                        Task { await viewModel.saveSettings() }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
        }
        .fileImporter(isPresented: $viewModel.showDirectoryImporter, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.updateScreenshotDirectory(url)
            }
        }
    }

    private func shortcutRow<R: View>(_ label: String, name: KeyboardShortcuts.Name, recorder: R) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .frame(width: 170, alignment: .leading)
                recorder
                    .onChange(of: KeyboardShortcuts.getShortcut(for: name)) { _ in
                        viewModel.refreshShortcutConflicts()
                    }
                Spacer()
            }
            if let message = viewModel.conflictMessage(for: name) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.leading, 170)
            }
        }
    }
}

struct BlacklistManagementSection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        section(L10n.localized("management.blacklist.title")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Picker(L10n.localized("management.blacklist.source"), selection: $viewModel.newBlacklistSourceID) {
                        ForEach(SettingsViewModel.sourceOptions, id: \.id) { option in
                            Text(option.label).tag(option.id.rawValue)
                        }
                    }
                    TextField(L10n.localized("management.blacklist.resultID"), text: $viewModel.newBlacklistResultID)
                    TextField(L10n.localized("management.blacklist.titleField"), text: $viewModel.newBlacklistTitle)
                    TextField(L10n.localized("management.blacklist.type"), text: $viewModel.newBlacklistType)
                        .frame(width: 120)
                    Button(L10n.localized("management.blacklist.add")) {
                        Task { await viewModel.addBlacklistItem() }
                    }
                }

                if viewModel.blacklistItems.isEmpty {
                    Text(L10n.localized("management.blacklist.empty"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.blacklistItems) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline)
                                Text("\(item.sourceID.rawValue) · \(item.resultID.rawValue) · \(item.resultType)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                Task { await viewModel.removeBlacklistItem(item) }
                            } label: {
                                Label(L10n.localized("management.blacklist.remove"), systemImage: "trash")
                            }
                        }
                        Divider()
                    }
                }
            }
        }
    }
}

struct PermissionsManagementPage: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pageHeader(
                    title: L10n.localized("management.permissions.title"),
                    subtitle: L10n.localized("management.permissions.subtitle"),
                    icon: "lock.shield"
                )

                ForEach(PermissionKind.allCases, id: \.self) { kind in
                    let status = viewModel.permissionStatuses[kind] ?? .unknown
                    section(viewModel.permissionTitle(kind)) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: status.isAuthorized ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .font(.title2)
                                .foregroundColor(status.isAuthorized ? .green : .orange)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(viewModel.statusTitle(status))
                                    .font(.headline)
                                Text(viewModel.permissionDescription(kind))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(L10n.localized("onboarding.permission.openSettings")) {
                                viewModel.openSystemSettings(for: kind)
                            }
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button {
                        Task { await viewModel.refreshPermissions() }
                    } label: {
                        Label(L10n.localized("management.permissions.refresh"), systemImage: "arrow.clockwise")
                    }
                }
            }
            .padding(24)
        }
    }
}

struct AboutManagementPage: View {
    private let aboutProvider: AboutInfoProviderProtocol
    private let feedbackService: FeedbackServiceProtocol
    private let updateService: UpdateCheckServiceProtocol
    private let opener: ReleaseURLOpening

    @State private var showingPrivacyPolicy = false
    @State private var showingFeedbackSheet = false
    @State private var feedbackSummary = ""
    @State private var feedbackDetails = ""
    @State private var feedbackError: String?

    init(
        aboutProvider: AboutInfoProviderProtocol = BundleAboutInfoProvider(),
        feedbackService: FeedbackServiceProtocol = FeedbackEmailService(),
        updateService: UpdateCheckServiceProtocol = WebUpdateCheckService(),
        opener: ReleaseURLOpening = NSWorkspace.shared
    ) {
        self.aboutProvider = aboutProvider
        self.feedbackService = feedbackService
        self.updateService = updateService
        self.opener = opener
    }

    var body: some View {
        let info = aboutProvider.info

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pageHeader(
                    title: L10n.localized("about.title"),
                    subtitle: L10n.localized("about.subtitle"),
                    icon: "info.circle"
                )

                section(L10n.localized("about.product.section")) {
                    HStack(alignment: .center, spacing: 16) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .frame(width: 64, height: 64)
                            .cornerRadius(14)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(info.appName)
                                .font(.title2.weight(.semibold))
                            Text(L10n.localized("about.version", info.version, info.buildNumber))
                                .foregroundColor(.secondary)
                            Text(L10n.localized("about.description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                section(L10n.localized("about.links.section")) {
                    aboutLinkRow(title: L10n.localized("about.homepage"), url: info.homepageURL)
                    aboutButtonRow(title: L10n.localized("about.privacyPolicy"), systemImage: "hand.raised") {
                        showingPrivacyPolicy = true
                    }
                    aboutButtonRow(title: L10n.localized("about.checkUpdates"), systemImage: "arrow.triangle.2.circlepath") {
                        updateService.openDownloadPage()
                    }
                    aboutButtonRow(title: L10n.localized("about.feedback"), systemImage: "envelope") {
                        showingFeedbackSheet = true
                    }
                    aboutLinkRow(title: L10n.localized("about.thirdPartyLicenses"), url: info.thirdPartyLicensesURL)
                }

                section(L10n.localized("about.release.section")) {
                    bullet(L10n.localized("about.release.privacy"))
                    bullet(L10n.localized("about.release.update"))
                    bullet(L10n.localized("about.release.feedback"))
                }

                section(L10n.localized("about.copyright.section")) {
                    Text(info.copyright)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicySheet(info: info)
        }
        .sheet(isPresented: $showingFeedbackSheet) {
            FeedbackSheet(
                info: info,
                feedbackService: feedbackService,
                opener: opener,
                summary: $feedbackSummary,
                details: $feedbackDetails,
                errorMessage: $feedbackError
            )
        }
        .alert(L10n.localized("about.feedback.error.title"), isPresented: Binding(
            get: { feedbackError != nil },
            set: { if !$0 { feedbackError = nil } }
        )) {
            Button(L10n.localized("settings.alert.ok")) { feedbackError = nil }
        } message: {
            Text(feedbackError ?? "")
        }
    }

    private func aboutLinkRow(title: String, url: URL) -> some View {
        aboutButtonRow(title: title, systemImage: "arrow.up.right.square") {
            opener.open(url)
        }
    }

    private func aboutButtonRow(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Button(action: action) {
                HStack {
                    Label(title, systemImage: systemImage)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Divider()
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
}

struct PrivacyPolicySheet: View {
    let info: AboutInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.localized("privacy.title"))
                    .font(.title2.weight(.semibold))
                Spacer()
                Button(L10n.localized("settings.alert.ok")) { dismiss() }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    privacySection("privacy.local.title", bodyKey: "privacy.local.body")
                    privacySection("privacy.clipboard.title", bodyKey: "privacy.clipboard.body")
                    privacySection("privacy.screenshot.title", bodyKey: "privacy.screenshot.body")
                    privacySection("privacy.control.title", bodyKey: "privacy.control.body")
                    privacySection("privacy.feedback.title", bodyKey: "privacy.feedback.body")
                    Text(L10n.localized("privacy.contact", info.feedbackEmail))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .frame(width: 640, height: 560)
    }

    private func privacySection(_ titleKey: String, bodyKey: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.localized(titleKey))
                .font(.headline)
            Text(L10n.localized(bodyKey))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct FeedbackSheet: View {
    let info: AboutInfo
    let feedbackService: FeedbackServiceProtocol
    let opener: ReleaseURLOpening
    @Binding var summary: String
    @Binding var details: String
    @Binding var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.localized("about.feedback.sheet.title"))
                .font(.title2.weight(.semibold))
            Text(L10n.localized("about.feedback.sheet.scope"))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.localized("about.feedback.summary"))
                TextField(L10n.localized("about.feedback.summary.placeholder"), text: $summary)
                Text(L10n.localized("about.feedback.details"))
                TextEditor(text: $details)
                    .frame(minHeight: 110)
                    .border(Color.secondary.opacity(0.25))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.localized("about.feedback.included"))
                    .font(.headline)
                Text("- \(L10n.localized("about.feedback.included.version", info.version, info.buildNumber))")
                Text("- \(L10n.localized("about.feedback.included.macos", ProcessInfo.processInfo.operatingSystemVersionString))")
                Text("- \(L10n.localized("about.feedback.included.summary"))")
                Text("- \(L10n.localized("about.feedback.included.userText"))")
                Text(L10n.localized("about.feedback.excluded"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .font(.caption)

            HStack {
                Spacer()
                Button(L10n.localized("about.feedback.cancel"), role: .cancel) { dismiss() }
                Button(L10n.localized("about.feedback.openMail")) { openMail() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560)
    }

    private func openMail() {
        do {
            let context = FeedbackContext(
                appVersion: info.version,
                buildNumber: info.buildNumber,
                macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                errorSummary: summary,
                userDescription: details
            )
            let url = try feedbackService.makeFeedbackEmail(context: context)
            opener.open(url)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@ViewBuilder
private func pageHeader(title: String, subtitle: String, icon: String) -> some View {
    HStack(spacing: 14) {
        Image(systemName: icon)
            .font(.system(size: 28, weight: .semibold))
            .foregroundColor(.accentColor)
            .frame(width: 44, height: 44)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 26, weight: .semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        Spacer()
    }
}

@ViewBuilder
private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text(title)
            .font(.headline)
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    SettingsView()
}
