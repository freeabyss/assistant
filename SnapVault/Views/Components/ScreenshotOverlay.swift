import Cocoa
import os.log

// MARK: - ScreenshotOverlayViewDelegate

/// Delegate protocol for the screenshot overlay view.
protocol ScreenshotOverlayViewDelegate: AnyObject {
    /// Called when the user completes a selection.
    func overlayView(_ view: ScreenshotOverlayView, didSelectRect rect: NSRect)

    /// Called when the user cancels the selection (ESC key).
    func overlayViewDidCancel(_ view: ScreenshotOverlayView)
}

// MARK: - ScreenshotOverlayView

/// Custom NSView that handles mouse tracking and drawing for region selection.
///
/// Displays a semi-transparent overlay covering the entire screen.
/// The user can drag to select a rectangular region. The selected area
/// is shown clear with a white border and dimension text.
/// Pressing ESC cancels the selection.
final class ScreenshotOverlayView: NSView {
    weak var delegate: ScreenshotOverlayViewDelegate?

    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Keyboard Events

    override func keyDown(with event: NSEvent) {
        // ESC key (keyCode 53) cancels the overlay
        if event.keyCode == 53 {
            delegate?.overlayViewDidCancel(self)
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = startPoint, let end = currentPoint else {
            delegate?.overlayViewDidCancel(self)
            return
        }

        let rect = normalizedRect(from: start, to: end)

        // Minimum selection size: 5x5 pixels
        guard rect.width > 5 && rect.height > 5 else {
            delegate?.overlayViewDidCancel(self)
            return
        }

        delegate?.overlayView(self, didSelectRect: rect)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw semi-transparent dark overlay over the entire screen
        NSColor.black.withAlphaComponent(0.3).set()
        dirtyRect.fill()

        guard let start = startPoint, let end = currentPoint else { return }

        let rect = normalizedRect(from: start, to: end)

        // Clear the selected area (make it fully transparent)
        NSColor.clear.set()
        rect.fill(using: .copy)

        // Draw white border around the selection
        NSColor.white.set()
        let borderPath = NSBezierPath(rect: rect)
        borderPath.lineWidth = 2
        borderPath.stroke()

        // Draw cross-hair guides (dashed lines through the center)
        NSColor.white.withAlphaComponent(0.5).set()
        let dashPattern: [CGFloat] = [4, 4]
        let centerHPath = NSBezierPath()
        centerHPath.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
        centerHPath.move(to: NSPoint(x: rect.minX, y: rect.midY))
        centerHPath.line(to: NSPoint(x: rect.maxX, y: rect.midY))
        centerHPath.stroke()

        let centerVPath = NSBezierPath()
        centerVPath.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
        centerVPath.move(to: NSPoint(x: rect.midX, y: rect.minY))
        centerVPath.line(to: NSPoint(x: rect.midX, y: rect.maxY))
        centerVPath.stroke()

        // Draw dimension text below the selection
        drawDimensions(for: rect)
    }

    // MARK: - Private Helpers

    /// Create a normalized rect (positive width/height) from two points.
    private func normalizedRect(from p1: NSPoint, to p2: NSPoint) -> NSRect {
        NSRect(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p2.x - p1.x),
            height: abs(p2.y - p1.y)
        )
    }

    /// Draw the dimension text (width x height) below the selection rectangle.
    private func drawDimensions(for rect: NSRect) {
        let dimensionText = "\(Int(rect.width)) x \(Int(rect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white,
        ]

        let textSize = dimensionText.size(withAttributes: attributes)
        let padding: CGFloat = 6
        let backgroundSize = NSSize(
            width: textSize.width + padding * 2,
            height: textSize.height + padding
        )

        // Position the label centered below the selection, with a small gap
        let labelRect = NSRect(
            x: rect.midX - backgroundSize.width / 2,
            y: rect.minY - backgroundSize.height - 4,
            width: backgroundSize.width,
            height: backgroundSize.height
        )

        // Draw background pill
        let backgroundPath = NSBezierPath(
            roundedRect: labelRect,
            xRadius: 4,
            yRadius: 4
        )
        NSColor.black.withAlphaComponent(0.7).set()
        backgroundPath.fill()

        // Draw text centered in the pill
        let textRect = NSRect(
            x: labelRect.origin.x + padding,
            y: labelRect.origin.y + padding / 2,
            width: textSize.width,
            height: textSize.height
        )
        dimensionText.draw(in: textRect, withAttributes: attributes)
    }
}

// MARK: - ScreenshotOverlayController

/// Manages the full-screen transparent overlay window for region selection.
///
/// Creates a borderless, full-screen window at screen saver level that covers all content.
/// The overlay view handles mouse drag selection and ESC cancellation.
/// The completion handler receives the selected rect in AppKit coordinates, or nil if cancelled.
final class ScreenshotOverlayController {
    private let logger = Logger.screenshot
    private var window: NSWindow?
    private let completion: (NSRect?) -> Void

    /// Create a new overlay controller.
    ///
    /// - Parameter completion: Called when the user completes selection or cancels.
    ///   The rect is in AppKit coordinates (bottom-left origin). nil means cancelled.
    init(completion: @escaping (NSRect?) -> Void) {
        self.completion = completion
    }

    /// Show the overlay window covering the entire screen.
    func show() {
        guard let screen = NSScreen.main else {
            logger.error("No main screen available for overlay")
            completion(nil)
            return
        }

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false

        let overlayView = ScreenshotOverlayView(frame: screen.frame)
        overlayView.delegate = self
        window.contentView = overlayView

        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(overlayView)

        self.window = window
        logger.debug("Overlay window shown on screen: \(screen.localizedName)")
    }

    /// Dismiss the overlay window.
    private func dismiss() {
        window?.orderOut(nil)
        window = nil
    }
}

// MARK: - ScreenshotOverlayViewDelegate

extension ScreenshotOverlayController: ScreenshotOverlayViewDelegate {
    func overlayView(_ view: ScreenshotOverlayView, didSelectRect rect: NSRect) {
        dismiss()
        completion(rect)
    }

    func overlayViewDidCancel(_ view: ScreenshotOverlayView) {
        dismiss()
        completion(nil)
    }
}
