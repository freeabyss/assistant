import SwiftUI
import os.log

@main
struct AssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var appState = AppState()

    var body: some Scene {
        // Main menu bar commands (Settings window)
        Settings {
            SettingsView()
                .environmentObject(appState)
                .tint(JadeColor.primary) // 全局主色注入（Design Token T-004）
        }
    }
}
