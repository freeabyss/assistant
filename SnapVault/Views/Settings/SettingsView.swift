import SwiftUI

/// Application preferences view.
/// Will be fully implemented in US-009.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            Text("Shortcuts settings placeholder")
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Text("General settings placeholder")
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
