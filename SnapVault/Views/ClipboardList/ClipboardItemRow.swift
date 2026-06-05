import SwiftUI

/// A single row in the clipboard history list.
struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Content type icon
            contentTypeIcon

            // Content preview
            VStack(alignment: .leading, spacing: 3) {
                contentPreview
                    .lineLimit(2)
                    .font(.system(size: 13))

                HStack(spacing: 6) {
                    // Content type label
                    Text(item.contentType.displayName)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    // Relative time
                    Text(relativeTime)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }

            Spacer(minLength: 0)

            // Pin indicator
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
    }

    // MARK: - Content Type Icon

    private var contentTypeIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(iconBackgroundColor)
                .frame(width: 32, height: 32)

            Image(systemName: item.contentType.iconName)
                .font(.system(size: 14))
                .foregroundColor(iconForegroundColor)
        }
    }

    private var iconBackgroundColor: Color {
        switch item.contentType {
        case .text:
            return Color.blue.opacity(0.15)
        case .rtf:
            return Color.purple.opacity(0.15)
        case .image:
            return Color.green.opacity(0.15)
        case .file:
            return Color.orange.opacity(0.15)
        }
    }

    private var iconForegroundColor: Color {
        switch item.contentType {
        case .text:
            return .blue
        case .rtf:
            return .purple
        case .image:
            return .green
        case .file:
            return .orange
        }
    }

    // MARK: - Content Preview

    @ViewBuilder
    private var contentPreview: some View {
        switch item.contentType {
        case .text, .rtf:
            Text(item.textContent ?? "Empty content")
                .foregroundColor(.primary)
        case .image:
            Text(item.ocrText?.isEmpty == false ? item.ocrText! : "Image")
                .foregroundColor(.primary)
        case .file:
            Text(item.filePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "File")
                .foregroundColor(.primary)
        }
    }

    // MARK: - Relative Time

    private var relativeTime: String {
        let now = Date()
        let interval = now.timeIntervalSince(item.createdAt)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

#Preview {
    VStack {
        ClipboardItemRow(
            item: ClipboardItem(
                contentType: .text,
                textContent: "Hello, this is a sample text content for preview",
                contentHash: "abc123"
            ),
            isSelected: false
        )
        ClipboardItemRow(
            item: ClipboardItem(
                contentType: .image,
                ocrText: "Extracted text from image",
                contentHash: "def456"
            ),
            isSelected: true
        )
    }
    .padding()
    .frame(width: 400)
}
