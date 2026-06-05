import SwiftUI

/// Content preview panel shown when a clipboard item is selected.
/// Will be fully implemented in US-004.
struct PreviewPanel: View {
    let item: ClipboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.contentType.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(item.textContent ?? "No preview available")
                .textSelection(.enabled)
        }
        .padding()
    }
}
