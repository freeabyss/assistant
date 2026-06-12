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
        }
    }
}
