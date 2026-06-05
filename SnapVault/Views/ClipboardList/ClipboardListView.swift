import SwiftUI

/// Main clipboard history list view.
/// Will be fully implemented in US-002/US-004.
struct ClipboardListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Text("Clipboard History")
    }
}

#Preview {
    ClipboardListView()
        .environmentObject(AppState())
}
