import Cocoa
import SwiftUI
import os.log

// MARK: - Toolbar Action

/// Actions a user can trigger from the screenshot toolbar.
enum ScreenshotToolbarAction {
    case ocr
    case copy
    case save
    case annotate
    case discard
    case dismiss     // ESC or 5s auto-dismiss (no destructive action)
}

// MARK: - Non-Activating Panel

/// A floating utility panel that never becomes key/main, so the user's
/// underlying app keeps focus. Required for the post-capture toolbar — if
/// it grabbed focus, ESC and quick clicks in the previous window would
/// behave unexpectedly.
final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - ScreenshotToolbarController

/// Pops a small, non-activating SwiftUI toolbar next to a freshly captured
/// screenshot. Provides explicit user-driven actions (OCR / Copy / Save /
/// Annotate / Discard) and self-dismisses after 5s of inactivity or on ESC.
///
/// Design notes:
/// - Single instance (held by `AppDelegate`); calling `show(...)` while a
///   previous panel is open dismisses the old one first.
/// - Positioning: bottom-centre of the main screen's visible area. Choosing
///   a fixed screen-relative location keeps the toolbar predictable when
///   the captured region itself was tiny or off-screen; PRD does not pin a
///   precise anchor, but bottom-centre matches CleanShot X / Shottr's
///   default and never collides with the menu bar.
/// - Auto-close timer: 5s after every `resetIdleTimer()`. Mouse-hover on
///   the panel pauses the timer (see `ScreenshotToolbarView.onHover`);
///   moving out restarts it.
/// - Item lifecycle: AppDelegate stores the screenshot into ContentStore
///   *before* showing the toolbar so the toolbar holds the canonical
///   `itemId` (Int64). Discard => repository.delete; Copy/Save read the
///   image from the in-memory `imageData` passed in; OCR routes through
///   ContentStore.recognizeOCR(itemId:) which also writes the text back
///   for FTS5 search.
@MainActor
final class ScreenshotToolbarController {
    private let logger = Logger.screenshot

    private var panel: NonActivatingPanel?
    private var idleTimer: Timer?
    private weak var ocrWindow: NSWindow?

    /// Dependencies injected by AppDelegate.
    private let contentStore: ContentStore
    private let repository = ContentRepository()

    init(contentStore: ContentStore) {
        self.contentStore = contentStore
    }

    deinit {
        idleTimer?.invalidate()
    }

    // MARK: - Show / Dismiss

    /// Show the toolbar for a newly captured screenshot.
    ///
    /// - Parameters:
    ///   - itemId: Database id of the saved screenshot row (already persisted).
    ///   - imageData: The PNG bytes (used for Copy / Save / re-OCR fallback).
    ///   - sourceType: Capture source, for naming the saved PNG file.
    func show(itemId: Int64, imageData: Data, sourceType: CaptureSource) {
        dismiss(reason: .superseded)

        let view = ScreenshotToolbarView(
            onAction: { [weak self] action in
                self?.handle(action: action, itemId: itemId, imageData: imageData, sourceType: sourceType)
            },
            onHoverChange: { [weak self] isHovering in
                if isHovering {
                    self?.cancelIdleTimer()
                } else {
                    self?.resetIdleTimer()
                }
            },
            onEscape: { [weak self] in
                self?.dismiss(reason: .userEscape)
            }
        )

        let hosting = NSHostingController(rootView: view)
        // Match the SwiftUI intrinsic size (see ScreenshotToolbarView.size).
        let panelSize = ScreenshotToolbarView.size

        guard let screen = NSScreen.main else {
            logger.error("No main screen available for toolbar")
            return
        }

        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - panelSize.width / 2,
            y: visible.minY + 64                          // 64pt above the Dock / screen bottom
        )

        let panel = NonActivatingPanel(
            contentRect: NSRect(origin: origin, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentViewController = hosting

        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 10
        panel.contentView?.layer?.masksToBounds = true

        panel.orderFrontRegardless()                       // never steals focus
        self.panel = panel

        resetIdleTimer()
        logger.info("Screenshot toolbar shown for item id=\(itemId)")
    }

    /// Reasons the toolbar may be dismissed (used for logging only).
    private enum DismissReason {
        case userEscape, timeout, action, discard, superseded
    }

    private func dismiss(reason: DismissReason) {
        cancelIdleTimer()
        if let panel = panel {
            panel.orderOut(nil)
            logger.debug("Toolbar dismissed (reason: \(String(describing: reason)))")
        }
        panel = nil
    }

    // MARK: - Idle Timer

    private func resetIdleTimer() {
        cancelIdleTimer()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss(reason: .timeout)
            }
        }
    }

    private func cancelIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }

    // MARK: - Action Handling

    private func handle(
        action: ScreenshotToolbarAction,
        itemId: Int64,
        imageData: Data,
        sourceType: CaptureSource
    ) {
        // Any interaction restarts the idle timer; destructive ones close the panel.
        resetIdleTimer()

        switch action {
        case .ocr:
            performOCR(itemId: itemId, imageData: imageData)
        case .copy:
            performCopy(itemId: itemId, imageData: imageData)
            dismiss(reason: .action)
        case .save:
            performSave(imageData: imageData)
            dismiss(reason: .action)
        case .annotate:
            performAnnotate(itemId: itemId, imageData: imageData)
            dismiss(reason: .action)
        case .discard:
            performDiscard(itemId: itemId)
            dismiss(reason: .discard)
        case .dismiss:
            dismiss(reason: .userEscape)
        }
    }

    // MARK: - Actions

    private func performCopy(itemId: Int64, imageData: Data) {
        let pb = NSPasteboard.general
        pb.clearContents()
        // Write image (.tiff) so paste-targets that prefer image data get the bitmap.
        if let nsImage = NSImage(data: imageData), let tiff = nsImage.tiffRepresentation {
            pb.setData(tiff, forType: .tiff)
        }
        // Write OCR text alongside, if we already recognised it. We do NOT block
        // the user here on a slow Vision pass — copy is the fast path.
        if let item = try? repository.fetch(id: itemId), let text = item.ocrText, !text.isEmpty {
            pb.setString(text, forType: .string)
        }
        logger.info("Copied screenshot to pasteboard (item id=\(itemId))")
    }

    private func performSave(imageData: Data) {
        let panel = NSSavePanel()
        panel.title = "Save Screenshot"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        panel.nameFieldStringValue = "Screenshot \(formatter.string(from: Date())).png"

        // Run modally relative to the floating panel so the save dialog
        // attaches to the foreground app's window stack.
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try imageData.write(to: url)
                self?.logger.info("Saved screenshot to \(url.path, privacy: .public)")
            } catch {
                self?.logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func performDiscard(itemId: Int64) {
        do {
            try repository.delete(id: itemId)
            NotificationCenter.default.post(name: .clipboardItemSaved, object: nil)
            logger.info("Discarded screenshot item id=\(itemId)")
        } catch {
            logger.error("Discard failed for id=\(itemId): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - OCR

    private func performOCR(itemId: Int64, imageData _: Data) {
        // If we already have non-empty OCR text in the DB, show it instantly.
        if let item = try? repository.fetch(id: itemId), let text = item.ocrText, !text.isEmpty {
            presentOCRWindow(text: text, lineCount: countLines(text), confidence: nil)
            return
        }

        // Otherwise show a progress-only window first, then fill it in async.
        let progressWindow = makeOCRWindow(initial: .loading)
        self.ocrWindow = progressWindow
        progressWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.contentStore.recognizeOCR(itemId: itemId)
                await MainActor.run {
                    self.updateOCRWindow(
                        progressWindow,
                        text: result.text.isEmpty ? "(no text recognized)" : result.text,
                        lineCount: self.countLines(result.text),
                        confidence: result.text.isEmpty ? nil : result.confidence
                    )
                }
            } catch {
                self.logger.error("On-demand OCR failed: \(error.localizedDescription, privacy: .public)")
                await MainActor.run {
                    self.updateOCRWindow(progressWindow, text: "OCR failed: \(error.localizedDescription)", lineCount: 0, confidence: nil)
                }
            }
        }
    }

    fileprivate enum OCRWindowState {
        case loading
        case result(text: String, lineCount: Int, confidence: Float?)
    }

    private func makeOCRWindow(initial state: OCRWindowState) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "OCR Result"
        window.isReleasedWhenClosed = false
        window.center()

        let viewModel = OCRResultViewModel(state: state)
        let host = NSHostingController(rootView: OCRResultView(viewModel: viewModel))
        window.contentViewController = host

        // Hold onto the VM via associated object so the closure-based update
        // survives. Simpler than subclassing NSWindow.
        objc_setAssociatedObject(window, &OCRWindowVMKey, viewModel, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return window
    }

    private func presentOCRWindow(text: String, lineCount: Int, confidence: Float?) {
        let window = makeOCRWindow(initial: .result(text: text, lineCount: lineCount, confidence: confidence))
        self.ocrWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateOCRWindow(_ window: NSWindow, text: String, lineCount: Int, confidence: Float?) {
        guard let vm = objc_getAssociatedObject(window, &OCRWindowVMKey) as? OCRResultViewModel else { return }
        vm.update(state: .result(text: text, lineCount: lineCount, confidence: confidence))
    }

    private func countLines(_ s: String) -> Int {
        if s.isEmpty { return 0 }
        return s.split(whereSeparator: \.isNewline).count
    }

    // MARK: - Transient Toast (Annotate stub)

    // Removed: showTransientToast was the US-024 placeholder for Annotate.
    // US-025 replaced it with performAnnotate below.

    // MARK: - Annotation Editor

    /// Open the full annotation editor window for this screenshot.
    private func performAnnotate(itemId: Int64, imageData: Data) {
        guard let nsImage = NSImage(data: imageData) else {
            logger.error("Cannot open annotation editor: invalid image data")
            return
        }
        let editor = AnnotationEditorWindow(image: nsImage, itemId: itemId)
        editor.present()
        logger.info("Annotation editor opened for item id=\(itemId)")
    }
}

// Associated-object key for OCRResultViewModel storage on NSWindow.
private var OCRWindowVMKey: UInt8 = 0

// MARK: - OCR Result Window (SwiftUI)

@MainActor
final class OCRResultViewModel: ObservableObject {
    @Published fileprivate var state: ScreenshotToolbarController.OCRWindowState

    fileprivate init(state: ScreenshotToolbarController.OCRWindowState) {
        self.state = state
    }

    fileprivate func update(state: ScreenshotToolbarController.OCRWindowState) {
        self.state = state
    }
}

// Re-export the nested type so SwiftUI in this file can reach it.
extension ScreenshotToolbarController {
    fileprivate typealias _OCRState = OCRWindowState
}

private struct OCRResultView: View {
    @ObservedObject var viewModel: OCRResultViewModel
    @State private var editableText: String = ""
    @State private var toastVisible: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch viewModel.state {
            case .loading:
                VStack {
                    Spacer()
                    ProgressView("Recognizing text…")
                        .progressViewStyle(.circular)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .result(let text, let lineCount, let confidence):
                // Stats bar
                HStack(spacing: 12) {
                    Label("\(lineCount) line\(lineCount == 1 ? "" : "s")", systemImage: "text.alignleft")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    if let c = confidence {
                        Label(String(format: "%.0f%% confidence", c * 100), systemImage: "checkmark.seal")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Editable text area
                TextEditor(text: $editableText)
                    .font(.system(size: 13))
                    .padding(8)
                    .onAppear { editableText = text }
                    .onChange(of: viewModel.state) { _ in
                        if case .result(let t, _, _) = viewModel.state {
                            editableText = t
                        }
                    }

                Divider()

                // Action bar
                HStack {
                    Spacer()
                    Button("Close") {
                        NSApp.keyWindow?.close()
                    }
                    .keyboardShortcut(.cancelAction)
                    Button("Copy All") {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(editableText, forType: .string)
                        withAnimation { toastVisible = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                            withAnimation { toastVisible = false }
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .frame(minWidth: 480, minHeight: 360)
        .overlay(alignment: .bottom) {
            if toastVisible {
                Text("Copied")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.78))
                    .cornerRadius(8)
                    .padding(.bottom, 60)
                    .transition(.opacity)
            }
        }
    }
}

// Required so onChange(of:) can compare; the enum has associated values
// so we hand-roll Equatable here.
extension ScreenshotToolbarController.OCRWindowState: Equatable {
    static func == (lhs: ScreenshotToolbarController.OCRWindowState, rhs: ScreenshotToolbarController.OCRWindowState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading): return true
        case let (.result(t1, l1, c1), .result(t2, l2, c2)):
            return t1 == t2 && l1 == l2 && c1 == c2
        default: return false
        }
    }
}

// MARK: - Toolbar SwiftUI View

struct ScreenshotToolbarView: View {
    /// Compact pill: 5 buttons × ~52pt + chrome.
    static let size = NSSize(width: 320, height: 52)

    let onAction: (ScreenshotToolbarAction) -> Void
    let onHoverChange: (Bool) -> Void
    let onEscape: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            ToolbarButton(
                systemName: "textformat",
                label: "OCR",
                tint: .accentColor
            ) { onAction(.ocr) }

            ToolbarButton(
                systemName: "doc.on.doc",
                label: "Copy"
            ) { onAction(.copy) }

            ToolbarButton(
                systemName: "square.and.arrow.down",
                label: "Save"
            ) { onAction(.save) }

            ToolbarButton(
                systemName: "pencil",
                label: "Annotate"
            ) { onAction(.annotate) }

            ToolbarButton(
                systemName: "xmark",
                label: "Discard",
                tint: .red
            ) { onAction(.discard) }
        }
        .padding(.horizontal, 8)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .onHover { hovering in
            isHovering = hovering
            onHoverChange(hovering)
        }
        .background(
            KeyCatcher(onEscape: onEscape)
                .frame(width: 0, height: 0)
        )
    }
}

private struct ToolbarButton: View {
    let systemName: String
    let label: String
    var tint: Color? = nil
    var disabled: Bool = false
    var disabledHint: String? = nil
    let action: () -> Void

    @State private var hovering: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .regular))
            }
            .foregroundColor(disabled ? .secondary : (tint ?? .primary))
            .frame(width: 56, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovering && !disabled ? Color.primary.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(disabled ? (disabledHint ?? label) : label)
        .onHover { hovering = $0 }
    }
}

// MARK: - Visual Effect Helper

/// Wrap `NSVisualEffectView` so the toolbar gets the standard macOS HUD blur.
private struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
}

// MARK: - Key Catcher (ESC)

/// Invisible NSView that listens for the ESC key. Sits inside the SwiftUI
/// view so we don't have to subclass the panel. Uses `flagsChanged` /
/// `keyDown` via a NSEvent local monitor — the panel itself doesn't become
/// key, so the responder chain can't deliver keystrokes natively.
private struct KeyCatcher: NSViewRepresentable {
    let onEscape: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.install(onEscape: onEscape)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var monitor: Any?

        func install(onEscape: @escaping () -> Void) {
            uninstall()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 {     // ESC
                    onEscape()
                    return nil
                }
                return event
            }
        }

        func uninstall() {
            if let m = monitor {
                NSEvent.removeMonitor(m)
                monitor = nil
            }
        }

        deinit { uninstall() }
    }
}
