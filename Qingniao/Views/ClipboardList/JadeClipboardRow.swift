import AppKit
import SwiftUI

/// Unified clipboard history row (P-02). Merges the former `ClipboardItemRow`
/// and `ClipboardHistoryRow` into a single Jade-styled component backed by
/// `ClipboardRecordSnapshot` (Core Data chain).
///
/// Layout: 40×40 radius-md thumbnail (image → thumbnail, rtf/text → glyph or
/// first char, file → system icon), single-line title, caption subtitle
/// (type · size · time). Hover reveals pin / copy / preview / delete actions
/// via `JadeListRow`.
struct JadeClipboardRow: View {
    let item: ClipboardRecordSnapshot
    let selected: Bool
    var thumbnailProvider: (ClipboardRecordSnapshot) async -> Data?
    var onPin: () -> Void
    var onCopy: () -> Void
    var onPreview: () -> Void
    var onDelete: () -> Void

    @State private var thumbnail: NSImage?

    private var actions: [JadeRowAction] {
        [
            JadeRowAction(systemImage: item.isPinned ? "pin.slash.fill" : "pin.fill",
                          label: item.isPinned ? "clipboard.unpin" : "clipboard.pin",
                          action: onPin),
            JadeRowAction(systemImage: "doc.on.doc", label: "clipboard.action.copy", action: onCopy),
            JadeRowAction(systemImage: "eye", label: "preview.open", action: onPreview),
            JadeRowAction(systemImage: "trash", label: "preview.delete", isDestructive: true, action: onDelete)
        ]
    }

    var body: some View {
        JadeListRow(selected: selected, rowSize: .comfortable, actions: actions) {
            HStack(spacing: JadeSpace.x3.value) {
                thumbnailView

                VStack(alignment: .leading, spacing: JadeSpace.x1.value) {
                    HStack(spacing: JadeSpace.x1.value) {
                        Text(primaryText)
                            .font(JadeFont.body)
                            .fontWeight(.medium)
                            .foregroundStyle(JadeColor.textPrimary)
                            .lineLimit(1)

                        if item.isPinned {
                            Image(systemName: "pin.fill")
                                .font(JadeFont.caption)
                                .foregroundStyle(JadeColor.primary)
                                .rotationEffect(.degrees(45))
                        }
                        if item.isFavorite {
                            Image(systemName: "star.fill")
                                .font(JadeFont.caption)
                                .foregroundStyle(JadeColor.attention)
                        }
                        if item.failureReason != nil {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(JadeFont.caption)
                                .foregroundStyle(JadeColor.warning)
                        }
                    }

                    Text(subtitleText)
                        .font(JadeFont.caption)
                        .foregroundStyle(JadeColor.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .task(id: item.id) {
            if item.contentType == .image, let data = await thumbnailProvider(item) {
                thumbnail = NSImage(data: data)
            }
        }
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .jadeRadius(.md)
        } else {
            ZStack {
                JadeRadius.md.shape
                    .fill(typeColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                if item.contentType == .text, let ch = firstCharacter {
                    Text(ch)
                        .font(JadeFont.title3)
                        .foregroundStyle(typeColor)
                } else {
                    Image(systemName: iconName)
                        .font(JadeFont.title3)
                        .foregroundStyle(typeColor)
                }
            }
        }
    }

    private var firstCharacter: String? {
        let source = item.summary ?? item.plainText ?? ""
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return nil }
        return String(first)
    }

    // MARK: - Text

    private var primaryText: String {
        switch item.contentType {
        case .text, .richText:
            return item.summary ?? item.plainText ?? L10n.localized("preview.empty")
        case .image:
            return item.summary ?? L10n.localized("content.image")
        case .file:
            return item.fileDisplayName ?? item.filePath?.lastPathComponent ?? L10n.localized("content.file")
        }
    }

    private var subtitleText: String {
        var parts: [String] = [typeLabel]
        if let size = sizeText {
            parts.append(size)
        }
        parts.append(L10n.relativeTime(from: item.updatedAt))
        return parts.joined(separator: " · ")
    }

    private var sizeText: String? {
        switch item.contentType {
        case .image:
            if let original = item.resources.first(where: { $0.type == .imageOriginal }) {
                if let width = original.width, let height = original.height {
                    return "\(width)×\(height)"
                }
                return ByteCountFormatter.string(fromByteCount: original.byteSize, countStyle: .file)
            }
            return nil
        case .file:
            guard let size = item.fileSize, size > 0 else { return nil }
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        case .text, .richText:
            return nil
        }
    }

    private var typeLabel: String {
        switch item.contentType {
        case .text: return L10n.localized("content.text")
        case .richText: return L10n.localized("content.richText")
        case .image: return L10n.localized("content.image")
        case .file: return L10n.localized("content.file")
        }
    }

    private var iconName: String {
        switch item.contentType {
        case .text: return "doc.text"
        case .richText: return "doc.richtext"
        case .image: return "photo"
        case .file: return "doc"
        }
    }

    private var typeColor: Color {
        switch item.contentType {
        case .text: return JadeColor.info
        case .richText: return JadeColor.warning
        case .image: return JadeColor.success
        case .file: return JadeColor.gray
        }
    }
}
