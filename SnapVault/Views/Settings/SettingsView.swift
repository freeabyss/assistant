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
                    Label("General", systemImage: "gear")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            DataSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
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
                    Text("Keep history for:")
                        .frame(width: 140, alignment: .trailing)
                    Stepper(
                        "\(viewModel.retentionDays) days",
                        value: $viewModel.retentionDays,
                        in: 1...365,
                        step: 1
                    )
                }

                HStack {
                    Text("Storage limit:")
                        .frame(width: 140, alignment: .trailing)
                    Stepper(
                        "\(viewModel.maxStorageMB) MB",
                        value: $viewModel.maxStorageMB,
                        in: 100...2000,
                        step: 50
                    )
                }
            } header: {
                Text("Retention")
            } footer: {
                Text("Clipboard items older than the retention period will be automatically deleted. Pinned items are never removed.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // -- Behavior --
            Section {
                Toggle(isOn: $viewModel.launchAtLogin) {
                    Text("Launch at login")
                }

                Toggle(isOn: $viewModel.ocrEnabled) {
                    Text("OCR text recognition")
                }

                HStack {
                    Text("Polling interval:")
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
                Text("Behavior")
            } footer: {
                Text("OCR extracts text from images for search. Polling interval controls how often SnapVault checks the clipboard for new content.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // -- Save / Reset --
            HStack {
                Spacer()
                Button("Restore Defaults") {
                    viewModel.resetToDefaults()
                }
                .help("Reset all general settings to their default values")

                Button("Save") {
                    Task {
                        await viewModel.save()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .help("Save all settings changes")
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
                    Text("Toggle Panel:")
                        .frame(width: 120, alignment: .trailing)
                    KeyboardShortcuts.Recorder(for: .togglePanel)
                    Spacer()
                }

                HStack {
                    Spacer()
                    Button("Restore Defaults") {
                        KeyboardShortcuts.reset(.togglePanel)
                    }
                    .help("Reset the toggle panel shortcut to the default Command+Shift+V")
                }
            } header: {
                Text("Global Shortcuts")
            } footer: {
                Text("Use the global shortcut to show or hide the SnapVault panel from anywhere. Click the recorder field and press your desired key combination.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                    Text("Database size:")
                        .frame(width: 140, alignment: .trailing)
                    Text(formatSize(viewModel.databaseSizeMB))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Refresh") {
                        viewModel.loadDatabaseStats()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }

                HStack {
                    Text("Total items:")
                        .frame(width: 140, alignment: .trailing)
                    Text("\(viewModel.totalItemCount)")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } header: {
                Text("Storage")
            }

            // -- Export --
            Section {
                HStack {
                    Button(action: { exportJSON() }) {
                        Label("Export JSON...", systemImage: "doc.text")
                    }
                    .disabled(viewModel.isExporting)

                    Spacer()

                    Button(action: { exportCSV() }) {
                        Label("Export CSV...", systemImage: "tablecells")
                    }
                    .disabled(viewModel.isExporting)
                }

                HStack {
                    Button(action: { exportDatabase() }) {
                        Label("Export Database...", systemImage: "internaldrive")
                    }
                    .disabled(viewModel.isExporting)

                    Spacer()
                }
            } header: {
                Text("Export")
            } footer: {
                Text("JSON includes all data (images as Base64). CSV includes text fields only. Database exports the raw SQLite file.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // -- Import --
            Section {
                Button(action: { importJSON() }) {
                    Label("Import JSON...", systemImage: "square.and.arrow.down")
                }
                .disabled(viewModel.isImporting)

                if viewModel.isImporting {
                    ProgressView(value: viewModel.importProgress)
                        .progressViewStyle(.linear)
                    Text("Importing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Import")
            } footer: {
                Text("Import data from a previously exported JSON file. Duplicate items (same content hash) will be skipped.")
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
                        Button("Dismiss") {
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
                        Label("Clear History...", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .disabled(viewModel.isClearingHistory)
                    .confirmationDialog(
                        "Are you sure you want to clear all clipboard history?",
                        isPresented: $viewModel.showClearHistoryConfirm,
                        titleVisibility: .visible
                    ) {
                        Button("Clear All History", role: .destructive) {
                            Task {
                                await viewModel.clearHistory()
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete all non-pinned clipboard items. Pinned items will be preserved. This action cannot be undone.")
                    }

                    Spacer()
                }
            } header: {
                Text("Danger Zone")
            }
        }
        .padding()
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            Button("OK") {}
        } message: {
            Text(viewModel.alertMessage)
        }
    }

    // MARK: - Export Actions

    private func exportJSON() {
        let panel = NSSavePanel()
        panel.title = "Export Clipboard History as JSON"
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
        panel.title = "Export Clipboard History as CSV"
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
        panel.title = "Export Database File"
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
        panel.title = "Import Clipboard History"
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

            Text("SnapVault")
                .font(.title)
                .fontWeight(.bold)

            Text("Version \(appVersion) (\(buildNumber))")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("A fast, local clipboard manager for macOS.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Check for Updates button
            Button("Check for Updates...") {
                NotificationCenter.default.post(name: .checkForUpdates, object: nil)
            }
            .buttonStyle(.bordered)

            Divider()

            VStack(spacing: 4) {
                Text("Built with SwiftUI + GRDB")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Data is stored locally on your Mac.")
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
