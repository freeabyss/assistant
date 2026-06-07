import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Content preview panel shown as a sheet when a clipboard item is tapped.
/// Supports text selection, RTF rendering, image zoom, and file info display.
struct PreviewPanel: View {
    let item: ClipboardItem
    var onCopy: () -> Void
    var onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var imageScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar

            Divider()

            // Content area (scrollable)
            ScrollView {
                contentArea
                    .padding(16)
            }

            Divider()

            // Action bar
            actionBar
        }
        .frame(minWidth: 450, minHeight: 400)
        .background(Color(NSColor.windowBackgroundColor))
        // ESC to close: hidden button with .cancelAction keyboard shortcut (macOS 13+)
        .overlay(
            Button(action: { dismiss() }) { EmptyView() }
                .keyboardShortcut(.cancelAction)
                .hidden()
        )
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            // Type icon + label
            Image(systemName: item.contentType.iconName)
                .font(.system(size: 14))
                .foregroundColor(typeColor)

            Text(item.contentType.displayName)
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            // Relative time
            Text(relativeTime)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        switch item.contentType {
        case .text:
            textPreview
        case .rtf:
            rtfPreview
        case .image:
            imagePreview
        case .file:
            filePreview
        }
    }

    // MARK: - Text Preview

    private var textPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.textContent ?? L10n.localized("preview.empty"))
                .font(.system(size: 14, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )
        }
    }

    // MARK: - RTF Preview

    private var rtfPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let attributed = parseRTF() {
                RTFTextView(attributedString: attributed)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
            } else {
                // Fallback to plain text
                Text(item.textContent ?? item.rtfContent ?? L10n.localized("preview.empty"))
                    .font(.system(size: 14))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Image Preview

    private var imagePreview: some View {
        VStack(spacing: 12) {
            if let data = item.imageData, let nsImage = NSImage(data: data) {
                let _ = updateImageScaleIfNeeded(nsImage)

                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(imageScale)
                    .frame(maxWidth: .infinity, maxHeight: 400)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                imageScale = max(0.5, min(value, 5.0))
                            }
                    )

                // Image info
                HStack(spacing: 16) {
                    Label("\(Int(nsImage.size.width)) x \(Int(nsImage.size.height))", systemImage: "aspectratio")
                    if let rep = nsImage.representations.first {
                        Label("\(rep.pixelsWide) x \(rep.pixelsHigh) px", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    if let tiffData = nsImage.tiffRepresentation {
                        Label(ByteCountFormatter.string(fromByteCount: Int64(tiffData.count), countStyle: .file), systemImage: "doc")
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)

                // OCR text if available
                if let ocr = item.ocrText, !ocr.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.localized("preview.ocrText"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(ocr)
                            .font(.system(size: 13))
                            .textSelection(.enabled)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(L10n.localized("preview.imageNotAvailable"))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - File Preview

    private var filePreview: some View {
        VStack(spacing: 16) {
            // Large file icon
            if let path = item.filePath {
                let fileURL = URL(fileURLWithPath: path)
                let icon = NSWorkspace.shared.icon(forFile: path)

                VStack(spacing: 12) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 64, height: 64)

                    // File info table
                    VStack(spacing: 8) {
                        fileInfoRow(label: L10n.localized("preview.fileName"), value: fileURL.lastPathComponent)
                        fileInfoRow(label: L10n.localized("preview.filePath"), value: path)
                        if let size = fileSizeString(path: path) {
                            fileInfoRow(label: L10n.localized("preview.fileSize"), value: size)
                        }
                        if let type = fileType(path: path) {
                            fileInfoRow(label: L10n.localized("preview.fileType"), value: type)
                        }
                        if let modified = fileModifiedDate(path: path) {
                            fileInfoRow(label: L10n.localized("preview.fileModified"), value: modified)
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )

                    // Show in Finder button
                    Button(action: {
                        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                    }) {
                        Label(L10n.localized("preview.showInFinder"), systemImage: "folder")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(L10n.localized("preview.fileNotAvailable"))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            Spacer()

            Button(action: {
                onDelete()
                dismiss()
            }) {
                Label(L10n.localized("preview.delete"), systemImage: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(.red)
            }
            .buttonStyle(.bordered)

            Button(action: {
                onCopy()
                dismiss()
            }) {
                Label(L10n.localized("preview.copy"), systemImage: "doc.on.doc")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private var typeColor: Color {
        switch item.contentType {
        case .text: return .blue
        case .rtf: return .orange
        case .image: return .green
        case .file: return .gray
        }
    }

    private var relativeTime: String {
        L10n.relativeTime(from: item.createdAt)
    }

    private func parseRTF() -> NSAttributedString? {
        guard let rtf = item.rtfContent, let data = rtf.data(using: .utf8) else { return nil }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        return try? NSAttributedString(data: data, options: options, documentAttributes: nil)
    }

    private func updateImageScaleIfNeeded(_ image: NSImage) {
        // Reset scale when image changes
        imageScale = 1.0
    }

    private func fileInfoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func fileSizeString(path: String) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64 else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private func fileType(path: String) -> String? {
        guard let uti = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier else { return nil }
        return UTType(uti)?.localizedDescription ?? uti
    }

    private func fileModifiedDate(path: String) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let date = attrs[.modificationDate] as? Date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - RTF Text View (NSViewRepresentable for full RTF rendering with selection)

/// Wraps NSTextView to render attributed string with text selection support.
struct RTFTextView: NSViewRepresentable {
    let attributedString: NSAttributedString

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        textView.textStorage?.setAttributedString(attributedString)
    }
}

#Preview {
    PreviewPanel(
        item: ClipboardItem(
            contentType: .text,
            textContent: "Hello World\nThis is a preview of the clipboard content.\nLine 3 here.",
            contentHash: "preview1"
        ),
        onCopy: {},
        onDelete: {}
    )
}
