import SwiftUI
import KeyboardShortcuts
import AppKit
import UniformTypeIdentifiers

/// Application preferences window with tabbed sections.
///
/// Opened via the gear icon in the menu bar view or via the app menu.
/// Uses macOS-native Form + Section styling for a standard preferences look.
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        TabView {
            GeneralSettingsView(viewModel: viewModel)
                .tabItem {
                    Label(L10n.localized("settings.general"), systemImage: "gear")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label(L10n.localized("settings.shortcuts"), systemImage: "keyboard")
                }

            DataSettingsView(viewModel: viewModel)
                .tabItem {
                    Label(L10n.localized("settings.data"), systemImage: "externaldrive")
                }

            AboutSettingsView()
                .tabItem {
                    Label(L10n.localized("settings.about"), systemImage: "info.circle")
                }
        }
        .frame(width: 480, height: 420)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            // -- Retention & Storage --
            Section {
                HStack {
                    Text(L10n.localized("settings.retention.label"))
                        .frame(width: 140, alignment: .trailing)
                    Stepper(
                        L10n.localized("settings.retention.format", viewModel.retentionDays),
                        value: $viewModel.retentionDays,
                        in: 1...365,
                        step: 1
                    )
                }

                HStack {
                    Text(L10n.localized("settings.storage.label"))
                        .frame(width: 140, alignment: .trailing)
                    Stepper(
                        L10n.localized("settings.storage.format", viewModel.maxStorageMB),
                        value: $viewModel.maxStorageMB,
                        in: 100...2000,
                        step: 50
                    )
                }
            } header: {
                Text(L10n.localized("settings.retention.header"))
            } footer: {
                Text(L10n.localized("settings.retention.footer"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // -- Behavior --
            Section {
                Toggle(isOn: $viewModel.launchAtLogin) {
                    Text(L10n.localized("settings.launchAtLogin"))
                }

                Toggle(isOn: $viewModel.ocrEnabled) {
                    Text(L10n.localized("settings.ocrEnabled"))
                }

                HStack {
                    Text(L10n.localized("settings.polling.label"))
                        .frame(width: 140, alignment: .trailing)
                    Picker("", selection: $viewModel.pollInterval) {
                        ForEach(SettingsViewModel.pollIntervalOptions, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
            } header: {
                Text(L10n.localized("settings.behavior.header"))
            } footer: {
                Text(L10n.localized("settings.behavior.footer"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // -- Save / Reset --
            HStack {
                Spacer()
                Button(L10n.localized("settings.restoreDefaults")) {
                    viewModel.resetToDefaults()
                }
                .help(L10n.localized("settings.restoreDefaults.help"))

                Button(L10n.localized("settings.save")) {
                    Task {
                        await viewModel.save()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .help(L10n.localized("settings.save.help"))
            }
        }
        .padding()
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Text(L10n.localized("settings.shortcuts.togglePanel"))
                        .frame(width: 120, alignment: .trailing)
                    KeyboardShortcuts.Recorder(for: .togglePanel)
                    Spacer()
                }

                HStack {
                    Text(L10n.localized("settings.shortcuts.captureRegion"))
                        .frame(width: 120, alignment: .trailing)
                    KeyboardShortcuts.Recorder(for: .captureRegion)
                    Spacer()
                }

                HStack {
                    Text(L10n.localized("settings.shortcuts.captureWindow"))
                        .frame(width: 120, alignment: .trailing)
                    KeyboardShortcuts.Recorder(for: .captureWindow)
                    Spacer()
                }

                HStack {
                    Spacer()
                    Button(L10n.localized("settings.restoreDefaults")) {
                        KeyboardShortcuts.reset(.togglePanel)
                        KeyboardShortcuts.reset(.captureRegion)
                        KeyboardShortcuts.reset(.captureWindow)
                    }
                    .help(L10n.localized("settings.restoreDefaults.help"))
                }
            } header: {
                Text(L10n.localized("settings.shortcuts.header"))
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.localized("settings.shortcuts.footer.defaults"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(L10n.localized("settings.shortcuts.footer.spotlightWarning"))
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(L10n.localized("settings.shortcuts.footer.instructions"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

// MARK: - Data Settings

struct DataSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            // -- Database Info --
            Section {
                HStack {
                    Text(L10n.localized("settings.data.dbSize"))
                        .frame(width: 140, alignment: .trailing)
                    Text(formatSize(viewModel.databaseSizeMB))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(L10n.localized("settings.data.refresh")) {
                        viewModel.loadDatabaseStats()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }

                HStack {
                    Text(L10n.localized("settings.data.totalItems"))
                        .frame(width: 140, alignment: .trailing)
                    Text("\(viewModel.totalItemCount)")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } header: {
                Text(L10n.localized("settings.data.storage.header"))
            }

            // -- Export --
            Section {
                HStack {
                    Button(action: { exportJSON() }) {
                        Label(L10n.localized("settings.data.exportJson"), systemImage: "doc.text")
                    }
                    .disabled(viewModel.isExporting)

                    Spacer()

                    Button(action: { exportCSV() }) {
                        Label(L10n.localized("settings.data.exportCsv"), systemImage: "tablecells")
                    }
                    .disabled(viewModel.isExporting)
                }

                HStack {
                    Button(action: { exportDatabase() }) {
                        Label(L10n.localized("settings.data.exportDb"), systemImage: "internaldrive")
                    }
                    .disabled(viewModel.isExporting)

                    Spacer()
                }
            } header: {
                Text(L10n.localized("settings.data.export.header"))
            } footer: {
                Text(L10n.localized("settings.data.export.footer"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // -- Import --
            Section {
                Button(action: { importJSON() }) {
                    Label(L10n.localized("settings.data.importJson"), systemImage: "square.and.arrow.down")
                }
                .disabled(viewModel.isImporting)

                if viewModel.isImporting {
                    ProgressView(value: viewModel.importProgress)
                        .progressViewStyle(.linear)
                    Text(L10n.localized("settings.data.importing"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text(L10n.localized("settings.data.import.header"))
            } footer: {
                Text(L10n.localized("settings.data.import.footer"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // -- Status --
            if let status = viewModel.dataOperationStatus {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(status)
                            .font(.caption)
                            .foregroundColor(.green)
                        Spacer()
                        Button(L10n.localized("settings.data.status.dismiss")) {
                            viewModel.dataOperationStatus = nil
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
            }

            // -- Danger Zone --
            Section {
                HStack {
                    Button(action: { viewModel.showClearHistoryConfirm = true }) {
                        Label(L10n.localized("settings.data.clearHistory"), systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .disabled(viewModel.isClearingHistory)
                    .confirmationDialog(
                        L10n.localized("settings.data.clearHistory.confirm.title"),
                        isPresented: $viewModel.showClearHistoryConfirm,
                        titleVisibility: .visible
                    ) {
                        Button(L10n.localized("settings.data.clearHistory.confirm.action"), role: .destructive) {
                            Task {
                                await viewModel.clearHistory()
                            }
                        }
                        Button(L10n.localized("settings.data.clearHistory.cancel"), role: .cancel) {}
                    } message: {
                        Text(L10n.localized("settings.data.clearHistory.confirm.message"))
                    }

                    Spacer()
                }
            } header: {
                Text(L10n.localized("settings.data.dangerZone.header"))
            }
        }
        .padding()
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            Button(L10n.localized("settings.alert.ok")) {}
        } message: {
            Text(viewModel.alertMessage)
        }
    }

    // MARK: - Export Actions

    private func exportJSON() {
        let panel = NSSavePanel()
        panel.title = L10n.localized("settings.savePanel.json")
        panel.nameFieldStringValue = "snapvault-export.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            await viewModel.exportJSON(to: url)
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.title = L10n.localized("settings.savePanel.csv")
        panel.nameFieldStringValue = "snapvault-export.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            await viewModel.exportCSV(to: url)
        }
    }

    private func exportDatabase() {
        let panel = NSSavePanel()
        panel.title = L10n.localized("settings.savePanel.db")
        panel.nameFieldStringValue = "snapvault.db"
        panel.allowedContentTypes = [.init(filenameExtension: "db")!]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            await viewModel.exportDatabase(to: url)
        }
    }

    // MARK: - Import Actions

    private func importJSON() {
        let panel = NSOpenPanel()
        panel.title = L10n.localized("settings.openPanel.import")
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            await viewModel.importJSON(from: url)
        }
    }

    // MARK: - Helpers

    private func formatSize(_ mb: Double) -> String {
        if mb < 1.0 {
            return String(format: "%.0f KB", mb * 1024)
        }
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - About Settings

struct AboutSettingsView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // App icon
            if let icon = NSApplication.shared.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
            } else {
                Image(systemName: "clipboard.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
            }

            Text(L10n.localized("settings.about.appName"))
                .font(.title)
                .fontWeight(.bold)

            Text(L10n.localized("settings.about.version", appVersion, buildNumber))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(L10n.localized("settings.about.description"))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Check for Updates button
            Button(L10n.localized("settings.about.checkUpdates")) {
                NotificationCenter.default.post(name: .checkForUpdates, object: nil)
            }
            .buttonStyle(.bordered)

            Divider()

            VStack(spacing: 4) {
                Text(L10n.localized("settings.about.techStack"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(L10n.localized("settings.about.dataNote"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

#Preview {
    SettingsView()
}
