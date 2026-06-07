import Cocoa
import SwiftUI
import os.log

// MARK: - Annotation Editor Window

/// Full window for editing a screenshot with arrows, rectangles, mosaic
/// blocks, and text labels. Opened from `ScreenshotToolbarController`'s
/// Annotate button.
///
/// Architecture:
/// - `NSWindowController` hosts a SwiftUI root that stacks the top toolbar,
///   the `AnnotationCanvasView`, and the bottom toolbar.
/// - `AnnotationCanvasState` is the single source of truth — owned by the
///   window controller and observed by both toolbars and the canvas.
/// - `⌘S` saves the annotated image back to the database (via callback)
///   and optionally to disk (via `NSSavePanel`).
/// - `⌘C` copies the flattened result to the pasteboard.
/// - `⌘Z`/`⌘⇧Z` route through the canvas's `UndoManager` (the NSView is
///   first responder, so the standard edit menu items drive it).
/// - Text tool: click → `NSAlert` with text field → commit shape.
///
/// Window sizing: show the image at its native pixel size, capped at 80%
/// of the main screen's visible area. The canvas scales with the window if
/// the user resizes it.
@MainActor
final class AnnotationEditorWindow: NSWindowController, NSWindowDelegate {

    private let logger = Logger.screenshot
    private let state: AnnotationCanvasState

    /// Database id of the screenshot row (used on save to overwrite).
    private let itemId: Int64

    /// Repository injected from outside for DB writes.
    private let repository = ContentRepository()

    /// Called on Save so the toolbar can update the OCR cache.
    var onSaved: ((_ newImageData: Data) -> Void)?

    // MARK: - Init

    init(image: NSImage, itemId: Int64) {
        self.itemId = itemId
        self.state = AnnotationCanvasState(image: image)
        super.init(window: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Present

    func present() {
        let root = AnnotationEditorRootView(
            state: state,
            onUndo: { [weak self] in self?.state.undoManager.undo() },
            onRedo: { [weak self] in self?.state.undoManager.redo() },
            onSave: { [weak self] in self?.save() },
            onCopy: { [weak self] in self?.copyToClipboard() },
            onCancel: { [weak self] in self?.cancel() },
            onRequestTextInput: { [weak self] point, completion in
                self?.requestTextInput(at: point, completion: completion)
            }
        )

        let window = NSWindow(
            contentRect: computeWindowRect(),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.localized("annotation.window.title")
        window.contentViewController = NSHostingController(rootView: root)
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    // MARK: - Window sizing

    /// Compute initial frame: native image size, capped at 80% of the
    /// main screen's visible area. Chrome (toolbars) adds ~90pt height.
    private func computeWindowRect() -> NSRect {
        let img = state.sourceImage
        let imgW = img.size.width
        let imgH = img.size.height

        guard let screen = NSScreen.main else {
            return NSRect(x: 100, y: 100, width: imgW, height: imgH + 90)
        }
        let visible = screen.visibleFrame
        let maxW = visible.width * 0.8
        let maxH = visible.height * 0.8
        let chromeH: CGFloat = 90   // top toolbar + bottom toolbar + titlebar

        let scale = min(1.0, min(maxW / imgW, (maxH - chromeH) / imgH))
        let winW = imgW * scale
        let winH = imgH * scale + chromeH

        return NSRect(
            x: visible.midX - winW / 2,
            y: visible.midY - winH / 2,
            width: winW,
            height: winH
        )
    }

    // MARK: - Text input (NSAlert)

    private func requestTextInput(at point: CGPoint, completion: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = L10n.localized("annotation.textInput.title")
        alert.informativeText = L10n.localized("annotation.textInput.message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.localized("annotation.textInput.add"))
        alert.addButton(withTitle: L10n.localized("annotation.textInput.cancel"))

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = L10n.localized("annotation.textInput.placeholder")
        textField.bezelStyle = .roundedBezel
        alert.accessoryView = textField

        guard let window = window else { completion(nil); return }

        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                completion(textField.stringValue)
            } else {
                completion(nil)
            }
        }
    }

    // MARK: - Save (to DB + optional to file)

    private func save() {
        let flat = AnnotationFlattener.flatten(image: state.sourceImage, shapes: state.shapes)
        guard let png = AnnotationFlattener.pngData(from: flat) else {
            logger.error("Failed to convert annotated image to PNG")
            return
        }

        // Write back to DB.
        do {
            try repository.updateImageData(id: itemId, imageData: png)
            // Reset OCR text so the next preview/OCR button re-recognises the
            // annotated version (text overlaid on screenshot changes content).
            try? repository.updateOCRText(id: itemId, ocrText: "")
            logger.info("Annotated image saved to DB for item id=\(self.itemId)")
            NotificationCenter.default.post(name: .clipboardItemSaved, object: nil)
        } catch {
            logger.error("Failed to save annotated image to DB: \(error.localizedDescription, privacy: .public)")
        }

        // Also offer a NSSavePanel for explicit file save.
        let panel = NSSavePanel()
        panel.title = L10n.localized("annotation.savePanel.title")
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH.mm.ss"
        panel.nameFieldStringValue = L10n.localized("annotation.savePanel.filename", fmt.string(from: Date()))
        panel.begin { [weak self] resp in
            guard resp == .OK, let url = panel.url else { return }
            do {
                try png.write(to: url)
                self?.logger.info("Saved annotated screenshot to \(url.path, privacy: .public)")
            } catch {
                self?.logger.error("File save failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        onSaved?(png)
        window?.close()
    }

    // MARK: - Copy to Clipboard

    private func copyToClipboard() {
        let flat = AnnotationFlattener.flatten(image: state.sourceImage, shapes: state.shapes)
        guard let png = AnnotationFlattener.pngData(from: flat) else {
            logger.error("Failed to convert annotated image to PNG")
            return
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        // Write both TIFF (AppKit native) and PNG (widely supported).
        if let tiff = flat.tiffRepresentation {
            pb.setData(tiff, forType: .tiff)
        }
        pb.setData(png, forType: NSPasteboard.PasteboardType("public.png"))
        logger.info("Annotated image copied to pasteboard")
        window?.close()
    }

    // MARK: - Cancel

    private func cancel() {
        window?.close()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Clean up the undo manager so its stacks don't leak.
        state.undoManager.removeAllActions()
    }
}

// MARK: - SwiftUI Root View

private struct AnnotationEditorRootView: View {
    @ObservedObject var state: AnnotationCanvasState

    let onUndo: () -> Void
    let onRedo: () -> Void
    let onSave: () -> Void
    let onCopy: () -> Void
    let onCancel: () -> Void
    let onRequestTextInput: (CGPoint, @escaping (String?) -> Void) -> Void

    var body: some View {
        VStack(spacing: 0) {
            AnnotationTopToolbar(state: state, onUndo: onUndo, onRedo: onRedo)
            Divider()
            AnnotationCanvasView(state: state, onRequestTextInput: onRequestTextInput)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            AnnotationBottomToolbar(onSave: onSave, onCopy: onCopy, onCancel: onCancel)
        }
    }
}
