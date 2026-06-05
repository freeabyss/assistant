import SwiftUI
import KeyboardShortcuts

/// Application preferences view.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .frame(width: 450, height: 300)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Text("General settings placeholder")
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
                    .help("Reset the toggle panel shortcut to the default ⌘+Shift+V")
                }
            } header: {
                Text("Global Shortcuts")
            } footer: {
                Text("Use the global shortcut to show or hide the SnapVault panel from anywhere.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
