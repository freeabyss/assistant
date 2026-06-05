import SwiftUI

/// A single row in the clipboard history list.
/// Will be fully implemented in US-004.
struct ClipboardItemRow: View {
    let item: ClipboardItem

    var body: some View {
        HStack {
            Image(systemName: item.contentType.iconName)
            Text(item.textContent ?? "Untitled")
                .lineLimit(1)
        }
    }
}

#Preview {
    ClipboardItemRow(item: ClipboardItem(
        contentType: .text,
        textContent: "Sample text",
        contentHash: "abc123"
    ))
}
