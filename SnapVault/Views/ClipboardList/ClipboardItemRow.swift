import SwiftUI
import AppKit

/// A single row in the clipboard history list.
/// Renders content-type-specific previews: monospace text, RTF, image thumbnail, file info.
/// Supports search result keyword highlighting via highlightRanges.
struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    /// Ranges of matched search keywords within the content text.
    /// When non-empty, matched regions are rendered with a yellow background.
    var highlightRanges: [NSRange] = []

    var body: some View {
        HStack(spacing: 10) {
            // Content type icon / thumbnail
            contentTypeIcon

            // Content preview
            VStack(alignment: .leading, spacing: 3) {
                contentPreview
                    .lineLimit(2)

                HStack(spacing: 6) {
                    // Content type label
                    Text(item.contentType.displayName)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    // File size for file type
                    if item.contentType == .file, let size = fileSizeString {
                        Text(size)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                    }

                    Spacer(minLength: 0)

                    // Relative time
                    Text(relativeTime)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }

            // Favorite indicator (yellow star) — independent from pin, may co-exist
            if item.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow)
            }

            // Pin indicator (right-aligned) — blue accent
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                    .rotationEffect(.degrees(45))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
    }

    // MARK: - Content Type Icon / Thumbnail

    @ViewBuilder
    private var contentTypeIcon: some View {
        if item.contentType == .image, let data = item.imageData, let nsImage = NSImage(data: data) {
            // Image thumbnail
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                )
        } else {
            // Standard icon
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(iconBackgroundColor)
                    .frame(width: 40, height: 40)

                Image(systemName: item.contentType.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(iconForegroundColor)
            }
        }
    }

    private var iconBackgroundColor: Color {
        switch item.contentType {
        case .text:
            return Color.blue.opacity(0.15)
        case .rtf:
            return Color.orange.opacity(0.15)
        case .image:
            return Color.green.opacity(0.15)
        case .file:
            return Color.gray.opacity(0.15)
        }
    }

    private var iconForegroundColor: Color {
        switch item.contentType {
        case .text:
            return .blue
        case .rtf:
            return .orange
        case .image:
            return .green
        case .file:
            return .gray
        }
    }

    // MARK: - Content Preview

    @ViewBuilder
    private var contentPreview: some View {
        switch item.contentType {
        case .text:
            // Monospace font for plain text, with search highlight if available
            if !highlightRanges.isEmpty, let text = item.textContent {
                Text(highlightedAttributedString(text: text, ranges: highlightRanges))
                    .font(.system(size: 13, design: .monospaced))
                    .lineLimit(2)
            } else {
                Text(item.textContent ?? "Empty content")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }

        case .rtf:
            // Render RTF preview
            RTFPreviewView(rtfString: item.rtfContent ?? item.textContent ?? "")
                .lineLimit(2)

        case .image:
            // Image: show dimensions + OCR text if available (with highlight)
            VStack(alignment: .leading, spacing: 2) {
                if let data = item.imageData, let nsImage = NSImage(data: data) {
                    Text("\(Int(nsImage.size.width)) x \(Int(nsImage.size.height))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                }
                if let ocr = item.ocrText, !ocr.isEmpty {
                    if !highlightRanges.isEmpty {
                        Text(highlightedAttributedString(text: ocr, ranges: highlightRanges))
                            .font(.system(size: 11))
                            .lineLimit(1)
                    } else {
                        Text(ocr)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

        case .file:
            // File: filename + file size
            VStack(alignment: .leading, spacing: 2) {
                Text(item.filePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "File")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if let size = fileSizeString {
                    Text(size)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    /// Build an AttributedString with yellow background highlight at the specified ranges.
    private func highlightedAttributedString(text: String, ranges: [NSRange]) -> AttributedString {
        let nsString = text as NSString
        let nsAttr = NSMutableAttributedString(string: text, attributes: [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        ])

        for range in ranges {
            // Clamp range to valid bounds
            let clampedRange = NSIntersectionRange(range, NSRange(location: 0, length: nsString.length))
            guard clampedRange.length > 0 else { continue }
            nsAttr.addAttributes([
                .backgroundColor: NSColor.systemYellow.withAlphaComponent(0.4),
                .foregroundColor: NSColor.labelColor
            ], range: clampedRange)
        }

        return AttributedString(nsAttr)
    }

    /// Formatted file size string for file-type items.
    private var fileSizeString: String? {
        guard item.contentType == .file, let path = item.filePath else { return nil }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64 else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    /// Chinese relative time display.
    private var relativeTime: String {
        let now = Date()
        let interval = now.timeIntervalSince(item.createdAt)

        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)天前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: item.createdAt)
        }
    }
}

// MARK: - RTF Preview Helper

/// A lightweight NSViewRepresentable that renders a single-line RTF preview.
struct RTFPreviewView: View {
    let rtfString: String
    var lineLimit: Int = 2

    var body: some View {
        if let attributedString = parseRTF() {
            Text(AttributedString(attributedString))
                .lineLimit(lineLimit)
        } else {
            // Fallback: plain text
            Text(rtfString)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .lineLimit(lineLimit)
        }
    }

    private func parseRTF() -> NSAttributedString? {
        guard let data = rtfString.data(using: .utf8) else { return nil }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        return try? NSAttributedString(data: data, options: options, documentAttributes: nil)
    }
}

#Preview {
    VStack {
        ClipboardItemRow(
            item: ClipboardItem(
                contentType: .text,
                textContent: "Hello, this is a sample text content for preview. It shows how the row looks with two lines.",
                contentHash: "abc123"
            ),
            isSelected: false
        )
        ClipboardItemRow(
            item: ClipboardItem(
                contentType: .rtf,
                textContent: "Rich text content",
                rtfContent: "{\\rtf1\\ansi This is {\\b bold} and {\\i italic} text.}",
                contentHash: "def456"
            ),
            isSelected: false
        )
        ClipboardItemRow(
            item: ClipboardItem(
                contentType: .image,
                ocrText: "Extracted text from image",
                contentHash: "ghi789"
            ),
            isSelected: true
        )
        ClipboardItemRow(
            item: ClipboardItem(
                contentType: .file,
                filePath: "/Users/test/Documents/report.pdf",
                contentHash: "jkl012"
            ),
            isSelected: false
        )
    }
    .padding()
    .frame(width: 400)
}
