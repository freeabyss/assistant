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
                    shortcutRow(L10n.localized("management.shortcuts.search"), recorder: KeyboardShortcuts.Recorder(for: .togglePanel))
                    shortcutRow(L10n.localized("management.shortcuts.captureRegion"), recorder: KeyboardShortcuts.Recorder(for: .captureRegion))
                    shortcutRow(L10n.localized("management.shortcuts.captureWindow"), recorder: KeyboardShortcuts.Recorder(for: .captureWindow))
                    HStack {
                        Spacer()
                        Button(L10n.localized("settings.restoreDefaults")) {
                            KeyboardShortcuts.reset(.togglePanel)
                            KeyboardShortcuts.reset(.captureRegion)
                            KeyboardShortcuts.reset(.captureWindow)
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

    private func shortcutRow<R: View>(_ label: String, recorder: R) -> some View {
        HStack {
            Text(label)
                .frame(width: 170, alignment: .leading)
            recorder
            Spacer()
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
