import Cocoa
import SwiftUI

// MARK: - Canvas State

/// Shared mutable state between the SwiftUI host (toolbar) and the
/// underlying `NSView`. Marked `@MainActor` because mutations come from
/// both the toolbar (`@StateObject` binding) and the mouse-event loop.
@MainActor
final class AnnotationCanvasState: ObservableObject {

    /// Source image (rendered as the background of every frame).
    let sourceImage: NSImage

    /// Image pixel size — also used to position the NSView at the right
    /// aspect ratio inside its SwiftUI parent.
    let imageSize: CGSize

    /// Committed shapes, in draw order. Bottom-first so later shapes
    /// (e.g. text on top of a rectangle) appear on top.
    @Published var shapes: [AnnotationShape] = []

    /// In-progress shape during a drag (not yet committed to `shapes`).
    /// Rendered every frame on top of `shapes` so the user sees live
    /// feedback. Cleared on `mouseUp` once the gesture commits.
    @Published var draftShape: AnnotationShape?

    /// Currently selected tool / colour / line width.
    @Published var tool: AnnotationTool = .arrow
    @Published var color: NSColor = AnnotationPalette.defaultColor
    @Published var lineWidth: CGFloat = AnnotationPalette.defaultLineWidth

    /// Undo manager driving ⌘Z / ⌘⇧Z. We push every add/remove through
    /// here so the user can rewind history. The NSView forwards its own
    /// undoManager into here when it becomes a first responder.
    let undoManager = UndoManager()

    init(image: NSImage) {
        self.sourceImage = image
        self.imageSize = image.size
    }

    // MARK: - Mutations (undo-aware)

    /// Append a shape with an undo-registered inverse.
    /// Calls `objectWillChange` explicitly because `shapes` is a value
    /// array — `@Published` only catches reassignment, not in-place
    /// `.append` from inside `MainActor.run` blocks.
    func append(_ shape: AnnotationShape) {
        let index = shapes.count
        shapes.append(shape)
        registerUndoRemove(at: index)
    }

    private func registerUndoRemove(at index: Int) {
        undoManager.registerUndo(withTarget: self) { state in
            Task { @MainActor in
                guard state.shapes.indices.contains(index) else { return }
                let removed = state.shapes.remove(at: index)
                state.registerUndoInsert(removed, at: index)
            }
        }
        undoManager.setActionName("Add Annotation")
    }

    private func registerUndoInsert(_ shape: AnnotationShape, at index: Int) {
        undoManager.registerUndo(withTarget: self) { state in
            Task { @MainActor in
                let clamped = min(index, state.shapes.count)
                state.shapes.insert(shape, at: clamped)
                state.registerUndoRemove(at: clamped)
            }
        }
        undoManager.setActionName("Add Annotation")
    }
}

// MARK: - Underlying NSView

/// `NSView` subclass that owns mouse-tracking + drawing. We keep it as a
/// plain `NSView` (not `NSImageView`) so we can interleave the image and
/// shape passes inside a single `draw(_:)` call — important for the
/// mosaic case which reads from the source image.
final class AnnotationCanvasNSView: NSView {

    weak var state: AnnotationCanvasState?
    /// Callback to ask the host to present the text-input alert (so the
    /// view stays AppKit-pure while the alert UX is owned by the window
    /// controller).
    var onRequestTextInput: ((CGPoint, @escaping (String?) -> Void) -> Void)?

    // MARK: First-responder boilerplate (so undoManager / key events work)

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // Provide our undo manager up the responder chain. The window's
    // FirstResponder picks this up so ⌘Z routes here.
    override var undoManager: UndoManager? { state?.undoManager }

    // MARK: - Drawing

    /// Pre-allocated drag start in image-space.
    private var dragStart: CGPoint?

    /// Image-space rect drawn into in `draw(_:)`. Equals the view bounds
    /// scaled so the image fits. Cached so mouse → image conversion is
    /// cheap.
    private var drawnImageRect: CGRect = .zero

    override func draw(_ dirtyRect: NSRect) {
        guard let state = state else { return }
        let image = state.sourceImage

        // Fit the image into our bounds preserving aspect ratio.
        let bounds = self.bounds
        let imgSize = state.imageSize
        let scale = min(bounds.width / imgSize.width, bounds.height / imgSize.height)
        let drawW = imgSize.width * scale
        let drawH = imgSize.height * scale
        let drawX = (bounds.width - drawW) / 2
        let drawY = (bounds.height - drawH) / 2
        let dest = CGRect(x: drawX, y: drawY, width: drawW, height: drawH)
        drawnImageRect = dest

        // Draw the background image first.
        image.draw(in: dest, from: .zero, operation: .copy, fraction: 1.0)

        // Now transform into image-coordinate space (image bottom-left at
        // (0,0), 1pt == 1 image-px) so the stored shape coordinates draw
        // identically here and during off-screen export.
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.translateBy(x: dest.minX, y: dest.minY)
        ctx.scaleBy(x: scale, y: scale)

        AnnotationRenderer.drawShapes(state.shapes, sourceImage: image)
        if let draft = state.draftShape {
            AnnotationRenderer.drawShapes([draft], sourceImage: image)
        }

        ctx.restoreGState()
    }

    // MARK: - Mouse → Image-space conversion

    /// Convert a view-local point into image pixel space. Clamps to image
    /// bounds so drags off-edge don't produce negative coordinates.
    private func imagePoint(from viewPoint: CGPoint) -> CGPoint? {
        guard let state = state, drawnImageRect.width > 0 else { return nil }
        let local = CGPoint(
            x: viewPoint.x - drawnImageRect.minX,
            y: viewPoint.y - drawnImageRect.minY
        )
        let scale = drawnImageRect.width / state.imageSize.width
        let x = max(0, min(state.imageSize.width, local.x / scale))
        let y = max(0, min(state.imageSize.height, local.y / scale))
        return CGPoint(x: x, y: y)
    }

    // MARK: - Mouse events

    override func mouseDown(with event: NSEvent) {
        guard let state = state else { return }
        let loc = convert(event.locationInWindow, from: nil)
        guard let p = imagePoint(from: loc) else { return }
        dragStart = p

        // Text tool is a single click → alert → commit.
        if state.tool == .text {
            onRequestTextInput?(p) { [weak self] content in
                guard let self = self, let state = self.state,
                      let content = content, !content.isEmpty else { return }
                state.append(.text(
                    point: p,
                    content: content,
                    color: state.color,
                    font: AnnotationShape.defaultTextFont
                ))
                self.needsDisplay = true
            }
            dragStart = nil
            return
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let state = state, let start = dragStart else { return }
        let loc = convert(event.locationInWindow, from: nil)
        guard let p = imagePoint(from: loc) else { return }

        switch state.tool {
        case .arrow:
            state.draftShape = .arrow(start: start, end: p, color: state.color, width: state.lineWidth)
        case .rectangle:
            state.draftShape = .rectangle(rect: rect(from: start, to: p), color: state.color, width: state.lineWidth)
        case .mosaic:
            state.draftShape = .mosaic(rect: rect(from: start, to: p), intensity: AnnotationShape.defaultMosaicIntensity)
        case .text:
            break
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let state = state, let start = dragStart else { return }
        let loc = convert(event.locationInWindow, from: nil)
        guard let p = imagePoint(from: loc) else { dragStart = nil; return }

        // Discard degenerate clicks (no drag) — avoids polluting the
        // shape list with zero-sized markers when the user just clicks.
        let dx = p.x - start.x
        let dy = p.y - start.y
        if (dx * dx + dy * dy) < 4 {
            state.draftShape = nil
            dragStart = nil
            needsDisplay = true
            return
        }

        switch state.tool {
        case .arrow:
            state.append(.arrow(start: start, end: p, color: state.color, width: state.lineWidth))
        case .rectangle:
            state.append(.rectangle(rect: rect(from: start, to: p), color: state.color, width: state.lineWidth))
        case .mosaic:
            state.append(.mosaic(rect: rect(from: start, to: p), intensity: AnnotationShape.defaultMosaicIntensity))
        case .text:
            break
        }
        state.draftShape = nil
        dragStart = nil
        needsDisplay = true
    }

    private func rect(from a: CGPoint, to b: CGPoint) -> CGRect {
        let x = min(a.x, b.x)
        let y = min(a.y, b.y)
        let w = abs(a.x - b.x)
        let h = abs(a.y - b.y)
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

// MARK: - SwiftUI Bridge

/// Wrap `AnnotationCanvasNSView` so the SwiftUI editor can mount it.
/// We bridge state through `AnnotationCanvasState` rather than a million
/// bindings — the view only needs `state` to render and route mouse events.
struct AnnotationCanvasView: NSViewRepresentable {
    @ObservedObject var state: AnnotationCanvasState
    let onRequestTextInput: (CGPoint, @escaping (String?) -> Void) -> Void

    func makeNSView(context: Context) -> AnnotationCanvasNSView {
        let v = AnnotationCanvasNSView()
        v.state = state
        v.onRequestTextInput = onRequestTextInput
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        return v
    }

    func updateNSView(_ nsView: AnnotationCanvasNSView, context: Context) {
        nsView.state = state
        nsView.onRequestTextInput = onRequestTextInput
        nsView.needsDisplay = true
    }
}

// MARK: - Flatten Helper

/// Off-screen render of `shapes` over `sourceImage` into a new `NSImage`,
/// then PNG. Used by Save / Copy so the exported bitmap matches WYSIWYG.
///
/// We render at 1:1 image pixel scale (no DPI doubling) so file size
/// stays predictable; the source image is already at native resolution.
enum AnnotationFlattener {
    static func flatten(image: NSImage, shapes: [AnnotationShape]) -> NSImage {
        let size = image.size
        let out = NSImage(size: size)
        out.lockFocus()
        // Background image.
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: .zero, operation: .copy, fraction: 1.0)
        // Shapes are stored in image-space already.
        AnnotationRenderer.drawShapes(shapes, sourceImage: image)
        out.unlockFocus()
        return out
    }

    /// Convert an `NSImage` to PNG bytes via TIFF → NSBitmapImageRep.
    /// Returns `nil` if the conversion path fails (extremely rare).
    static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
