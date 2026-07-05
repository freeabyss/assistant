import Cocoa
import SwiftUI
import os.log

// MARK: - Toolbar Action

/// Actions a user can trigger from the US-016 screenshot preview toolbar.
enum ScreenshotToolbarAction {
    case copy
    case save
    case annotate
    case cancel
    case dismiss
}

// MARK: - ScreenshotToolbarController

/// Presents a screenshot preview with a compact floating toolbar.
///
/// US-016 scope is intentionally narrow:
/// - capture result is previewed in-memory;
/// - Copy writes PNG/TIFF data to the system pasteboard, allowing the normal
///   clipboard monitor to persist it into history;
/// - Save writes PNG directly to ~/Pictures/Screenshots with the required
///   timestamp name and does not touch the pasteboard/history;
/// - Annotate is an entry point reserved for US-017 and does not implement
///   annotation tools here;
/// - Cancel/ESC discards the in-memory screenshot and closes the preview.
@MainActor
final class ScreenshotToolbarController {
    private let logger = Logger.screenshot

    private var window: ScreenshotPreviewWindow?
    private var annotationWindow: AnnotationEditorWindow?
    private var overlayCancelObserver: NSObjectProtocol?
    private var toastWorkItem: DispatchWorkItem?

    init() {
        overlayCancelObserver = NotificationCenter.default.addObserver(
            forName: .screenshotOverlayDidCancel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss(reason: .userEscape)
            }
        }
    }

    deinit {
        toastWorkItem?.cancel()
        if let overlayCancelObserver {
            NotificationCenter.default.removeObserver(overlayCancelObserver)
        }
    }

    func show(result: ScreenshotResult) {
        dismiss(reason: .superseded)

        let viewModel = ScreenshotPreviewViewModel(result: result)
        let view = ScreenshotPreviewView(
            viewModel: viewModel,
            onAction: { [weak self] action in
                self?.handle(action: action, result: result, viewModel: viewModel)
            }
        )

        let window = ScreenshotPreviewWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 560),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.onEscape = { [weak self] in
            self?.dismiss(reason: .userEscape)
        }
        window.contentView = NSHostingView(rootView: view)
        position(window: window, for: result)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
        logger.info("Screenshot preview shown for \(result.width)x\(result.height) capture")
    }

    private enum DismissReason {
        case userEscape, action, cancel, superseded
    }

    private func dismiss(reason: DismissReason) {
        toastWorkItem?.cancel()
        toastWorkItem = nil
        annotationWindow?.close()
        annotationWindow = nil
        if let window {
            window.orderOut(nil)
            logger.debug("Screenshot preview dismissed (reason: \(String(describing: reason)))")
        }
        window = nil
    }

    private func position(window: NSWindow, for result: ScreenshotResult) {
        guard let screen = NSScreen.main else {
            window.center()
            return
        }
        let visible = screen.visibleFrame
        let maxWidth = min(860, visible.width - 80)
        let maxHeight = min(640, visible.height - 80)
        let imageAspect = result.height > 0 ? CGFloat(result.width) / CGFloat(result.height) : 1
        let chromeHeight: CGFloat = 112
        let targetImageHeight = min(maxHeight - chromeHeight, max(240, maxWidth / max(imageAspect, 0.1)))
        let targetWidth = min(maxWidth, max(520, targetImageHeight * imageAspect + 64))
        let targetHeight = min(maxHeight, targetImageHeight + chromeHeight)
        let frame = NSRect(
            x: visible.midX - targetWidth / 2,
            y: visible.midY - targetHeight / 2,
            width: targetWidth,
            height: targetHeight
        )
        window.setFrame(frame, display: true)
    }

    private func handle(action: ScreenshotToolbarAction, result: ScreenshotResult, viewModel: ScreenshotPreviewViewModel) {
        switch action {
        case .copy:
            do {
                try copyToPasteboard(result.imageData)
                viewModel.showToast(L10n.localized("screenshot.toast.copied"))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    self?.dismiss(reason: .action)
                }
            } catch {
                logger.error("Screenshot copy failed: \(error.localizedDescription, privacy: .public)")
                viewModel.showToast(L10n.localized("screenshot.toast.copyFailed", error.localizedDescription))
            }
        case .save:
            do {
                let url = try savePNG(result.imageData, date: result.captureDate)
                viewModel.showToast(L10n.localized("screenshot.toast.saved", url.deletingLastPathComponent().path))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    self?.dismiss(reason: .action)
                }
            } catch {
                logger.error("Screenshot save failed: \(error.localizedDescription, privacy: .public)")
                viewModel.showToast(L10n.localized("screenshot.toast.saveFailed", error.localizedDescription))
            }
        case .annotate:
            presentAnnotationEditor(result: result, viewModel: viewModel)
        case .cancel, .dismiss:
            dismiss(reason: action == .cancel ? .cancel : .userEscape)
        }
    }

    private func presentAnnotationEditor(result: ScreenshotResult, viewModel: ScreenshotPreviewViewModel) {
        guard let image = NSImage(data: result.imageData) else {
            viewModel.showToast(L10n.localized("screenshot.preview.unavailable"))
            return
        }
        window?.orderOut(nil)
        let editor = AnnotationEditorWindow(
            image: image,
            captureDate: result.captureDate,
            onCopy: { [weak self] pngData in
                try self?.copyToPasteboard(pngData)
            },
            onSave: { [weak self] pngData, date in
                guard let self else { throw SnapVaultError.screenshotFailed(reason: L10n.localized("error.serviceDeallocated")) }
                return try self.savePNG(pngData, date: date)
            },
            onComplete: { [weak self, weak viewModel] completion in
                Task { @MainActor in
                    guard let self else { return }
                    self.annotationWindow = nil
                    switch completion {
                    case .copied:
                        viewModel?.showToast(L10n.localized("screenshot.toast.copied"))
                        self.dismiss(reason: .action)
                    case .saved(let url):
                        viewModel?.showToast(L10n.localized("screenshot.toast.saved", url.deletingLastPathComponent().path))
                        self.dismiss(reason: .action)
                    case .cancelled:
                        self.window?.makeKeyAndOrderFront(nil)
                        NSApp.activate(ignoringOtherApps: true)
                    case .failed(let message):
                        self.window?.makeKeyAndOrderFront(nil)
                        viewModel?.showToast(message)
                    }
                }
            }
        )
        annotationWindow = editor
        editor.present()
        logger.info("Screenshot annotation editor opened")
    }

    private func copyToPasteboard(_ pngData: Data) throws {
        guard let image = NSImage(data: pngData), let tiff = image.tiffRepresentation else {
            throw SnapVaultError.screenshotFailed(reason: L10n.localized("error.pngConversionFailed"))
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(pngData, forType: .png)
        pasteboard.setData(tiff, forType: .tiff)
        logger.info("Screenshot copied to system pasteboard")
    }

    @discardableResult
    private func savePNG(_ pngData: Data, date: Date) throws -> URL {
        let fileManager = FileManager.default
        let pictures = fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Pictures", isDirectory: true)
        let directory = pictures.appendingPathComponent("Screenshots", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        var url = directory.appendingPathComponent("Screenshot \(formatter.string(from: date)).png")
        if fileManager.fileExists(atPath: url.path) {
            url = uniqueURL(baseURL: url)
        }
        try pngData.write(to: url, options: .atomic)
        logger.info("Screenshot saved to \(url.path, privacy: .public)")
        return url
    }

    private func uniqueURL(baseURL: URL) -> URL {
        let directory = baseURL.deletingLastPathComponent()
        let basename = baseURL.deletingPathExtension().lastPathComponent
        let ext = baseURL.pathExtension
        for index in 2...999 {
            let candidate = directory.appendingPathComponent("\(basename) \(index).\(ext)")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return baseURL
    }
}

// MARK: - Preview Window

final class ScreenshotPreviewWindow: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }
}

// MARK: - Preview View Model

@MainActor
final class ScreenshotPreviewViewModel: ObservableObject {
    let result: ScreenshotResult
    @Published var toastMessage: String?

    init(result: ScreenshotResult) {
        self.result = result
    }

    func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            if self?.toastMessage == message {
                self?.toastMessage = nil
            }
        }
    }
}

// MARK: - SwiftUI Preview

private struct ScreenshotPreviewView: View {
    @ObservedObject var viewModel: ScreenshotPreviewViewModel
    let onAction: (ScreenshotToolbarAction) -> Void

    private var image: NSImage? {
        NSImage(data: viewModel.result.imageData)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                previewHeader
                Divider().opacity(0.35)
                ZStack {
                    Color.black.opacity(0.82)
                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .padding(24)
                    } else {
                        Label(L10n.localized("screenshot.preview.unavailable"), systemImage: "exclamationmark.triangle")
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider().opacity(0.35)
                toolbar
            }
            .background(
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
            )

            if let toast = viewModel.toastMessage {
                // T-007: migrated to the unified JadeToast component
                // (JadeToast replaced ToastView.swift). The preview is a
                // standalone NSHostingView, so we render JadeToast directly
                // rather than via the `.jadeToast` modifier (auto-dismiss is
                // already handled by ScreenshotPreviewViewModel.showToast).
                JadeToast(toast, variant: .info)
                    .padding(.bottom, JadeSpace.x8.value)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: 520, minHeight: 380)
    }

    private var previewHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName(for: viewModel.result.sourceType))
                .font(.system(size: 15, weight: .semibold))
            Text(L10n.localized("screenshot.preview.title"))
                .font(.system(size: 13, weight: .semibold))
            Text("\(viewModel.result.width) × \(viewModel.result.height)")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(.secondary)
            Spacer()
            Text(L10n.localized("screenshot.preview.escHint"))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 42)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            ToolbarButton(systemName: "doc.on.doc", label: L10n.localized("screenshot.toolbar.copy")) {
                onAction(.copy)
            }
            ToolbarButton(systemName: "square.and.arrow.down", label: L10n.localized("screenshot.toolbar.save")) {
                onAction(.save)
            }
            ToolbarButton(systemName: "pencil", label: L10n.localized("screenshot.toolbar.annotate")) {
                onAction(.annotate)
            }
            ToolbarButton(systemName: "xmark", label: L10n.localized("screenshot.toolbar.cancel"), tint: .red) {
                onAction(.cancel)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 62)
        .background(Color.black.opacity(0.16))
    }

    private func iconName(for source: CaptureSource) -> String {
        switch source {
        case .region: return "crop"
        case .window: return "macwindow"
        case .screen: return "rectangle.inset.filled"
        }
    }
}

private struct ToolbarButton: View {
    let systemName: String
    let label: String
    var tint: Color? = nil
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .regular))
            }
            .foregroundColor(tint ?? .primary)
            .frame(width: 72, height: 46)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(hovering ? Color.primary.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(label)
        .onHover { hovering = $0 }
    }
}

// MARK: - Visual Effect Helper

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
