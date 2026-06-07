import Cocoa
import CoreImage

// MARK: - Annotation Shape Model

/// A single vector mark drawn on top of the screenshot inside
/// `AnnotationCanvasView`. Each case stores everything the renderer needs
/// to draw itself in `drawRect`; no extra state lives in the view.
///
/// Design choices:
/// - Coordinates are in the *image's own coordinate space* (origin at the
///   image bottom-left, in pixels). The canvas view scales / translates
///   to fit its bounds, so the shape buffer remains resolution-independent
///   regardless of window resizes.
/// - `mosaic` carries an `intensity` (CIPixellate `scale`) per shape so
///   each mosaic block can have its own granularity if a future tool
///   wants per-shape intensity. Default we use 8.0 (see `defaultIntensity`).
/// - Colours / fonts are kept as `NSColor` / `NSFont` (not `CGColor`)
///   because the SwiftUI toolbar already converts user choices to AppKit
///   types — staying in AppKit avoids back-and-forth conversion.
enum AnnotationShape {
    case arrow(start: CGPoint, end: CGPoint, color: NSColor, width: CGFloat)
    case rectangle(rect: CGRect, color: NSColor, width: CGFloat)
    case mosaic(rect: CGRect, intensity: CGFloat)
    case text(point: CGPoint, content: String, color: NSColor, font: NSFont)
}

extension AnnotationShape {
    /// Default mosaic block size (CIPixellate `scale`). 8pt strikes a
    /// balance between visibly hiding text and not turning the area into
    /// a single colour blob.
    static let defaultMosaicIntensity: CGFloat = 8.0

    /// Default arrow head: 15pt sides at 30 degrees from the shaft.
    static let arrowHeadLength: CGFloat = 15
    static let arrowHeadAngle: CGFloat = .pi / 6   // 30°

    /// Default text font for the simple Alert-input text tool.
    static let defaultTextFont: NSFont = .systemFont(ofSize: 18, weight: .semibold)
}

// MARK: - Tool Selection

/// User-facing tool selection. Drives `mouseDown/Dragged/Up` interpretation
/// inside `AnnotationCanvasView`.
enum AnnotationTool: String, CaseIterable, Identifiable {
    case arrow
    case rectangle
    case mosaic
    case text

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .arrow:     return L10n.localized("annotation.tool.arrow")
        case .rectangle: return L10n.localized("annotation.tool.rectangle")
        case .mosaic:    return L10n.localized("annotation.tool.mosaic")
        case .text:      return L10n.localized("annotation.tool.text")
        }
    }

    var systemImage: String {
        switch self {
        case .arrow:     return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .mosaic:    return "square.grid.3x3.square"
        case .text:      return "textformat"
        }
    }
}

// MARK: - Palette

/// Fixed colour palette (matches PRD: red/orange/yellow/green/blue/black).
/// Returning `NSColor` lets the canvas use them directly without conversion.
enum AnnotationPalette {
    static let colors: [NSColor] = [
        .systemRed,
        .systemOrange,
        .systemYellow,
        .systemGreen,
        .systemBlue,
        .black
    ]

    static let defaultColor: NSColor = .systemRed
    static let defaultLineWidth: CGFloat = 4.0
    static let minLineWidth: CGFloat = 2.0
    static let maxLineWidth: CGFloat = 8.0
}

// MARK: - Drawing Helpers

/// Common path-construction helpers shared between the live canvas
/// drawing and the off-screen "flatten to PNG" routine. Centralising
/// them keeps WYSIWYG between editor view and exported image.
enum AnnotationRenderer {

    /// Draw all shapes into the *current* `NSGraphicsContext`, assuming
    /// the coordinate space is already aligned to the image origin
    /// (image bottom-left at (0,0), 1pt == 1px).
    static func drawShapes(_ shapes: [AnnotationShape], sourceImage: NSImage?) {
        for shape in shapes {
            switch shape {
            case .arrow(let start, let end, let color, let width):
                drawArrow(from: start, to: end, color: color, width: width)
            case .rectangle(let rect, let color, let width):
                drawRectangle(rect: rect, color: color, width: width)
            case .mosaic(let rect, let intensity):
                drawMosaic(rect: rect, intensity: intensity, sourceImage: sourceImage)
            case .text(let point, let content, let color, let font):
                drawText(point: point, content: content, color: color, font: font)
            }
        }
    }

    // MARK: Arrow

    /// Solid line from `start` to `end` plus a 30° triangle head at `end`.
    /// We compute the two head edges by rotating the unit vector
    /// (start - end) by ±`arrowHeadAngle` and scaling to `arrowHeadLength`.
    static func drawArrow(from start: CGPoint, to end: CGPoint, color: NSColor, width: CGFloat) {
        color.setStroke()
        color.setFill()

        // Shaft.
        let shaft = NSBezierPath()
        shaft.lineWidth = width
        shaft.lineCapStyle = .round
        shaft.move(to: start)
        shaft.line(to: end)
        shaft.stroke()

        // Head — degenerate when start == end; bail to avoid NaN.
        let dx = start.x - end.x
        let dy = start.y - end.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0.001 else { return }

        let ux = dx / length
        let uy = dy / length
        let cosA = cos(AnnotationShape.arrowHeadAngle)
        let sinA = sin(AnnotationShape.arrowHeadAngle)
        let head = AnnotationShape.arrowHeadLength

        // Rotate (ux, uy) by ±arrowHeadAngle to get the two side directions,
        // then march `head` pts away from `end`.
        let leftX = end.x + head * (ux * cosA - uy * sinA)
        let leftY = end.y + head * (ux * sinA + uy * cosA)
        let rightX = end.x + head * (ux * cosA + uy * sinA)
        let rightY = end.y + head * (-ux * sinA + uy * cosA)

        let headPath = NSBezierPath()
        headPath.move(to: end)
        headPath.line(to: CGPoint(x: leftX, y: leftY))
        headPath.line(to: CGPoint(x: rightX, y: rightY))
        headPath.close()
        headPath.fill()
    }

    // MARK: Rectangle

    static func drawRectangle(rect: CGRect, color: NSColor, width: CGFloat) {
        let path = NSBezierPath(rect: rect.standardized)
        path.lineWidth = width
        color.setStroke()
        path.stroke()
    }

    // MARK: Mosaic

    /// Pixelate the source image region and stamp it back. We render via
    /// `CIPixellate` for fidelity (vs. naive averaging), then composite
    /// the result inside the rect's bounds only — keeping cost ~O(rect).
    static func drawMosaic(rect: CGRect, intensity: CGFloat, sourceImage: NSImage?) {
        let target = rect.standardized
        guard target.width > 0, target.height > 0 else { return }
        guard let image = sourceImage else {
            // Fall back to a grey block so the user still sees feedback.
            NSColor.gray.withAlphaComponent(0.6).setFill()
            target.fill()
            return
        }

        // Convert NSImage to CIImage. We grab a CGImage proposal so the
        // CI pipeline runs in absolute pixel space, matching our canvas.
        var imgRect = NSRect(origin: .zero, size: image.size)
        guard let cg = image.cgImage(forProposedRect: &imgRect, context: nil, hints: nil) else {
            NSColor.gray.withAlphaComponent(0.6).setFill()
            target.fill()
            return
        }
        let ciInput = CIImage(cgImage: cg)

        // Clamp the pixelate centre to the rect's centre so the block
        // grid aligns with the user-selected region.
        let pix = CIFilter(name: "CIPixellate")
        pix?.setValue(ciInput, forKey: kCIInputImageKey)
        pix?.setValue(max(intensity, 1.0), forKey: kCIInputScaleKey)
        pix?.setValue(CIVector(x: target.midX, y: target.midY), forKey: kCIInputCenterKey)
        guard let output = pix?.outputImage else { return }

        let ctx = CIContext(options: nil)
        // Crop to the requested rect — CIPixellate returns an infinite extent.
        guard let cgOut = ctx.createCGImage(output, from: target) else { return }
        guard let gctx = NSGraphicsContext.current?.cgContext else { return }
        gctx.saveGState()
        gctx.draw(cgOut, in: target)
        gctx.restoreGState()
    }

    // MARK: Text

    static func drawText(point: CGPoint, content: String, color: NSColor, font: NSFont) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let str = NSAttributedString(string: content, attributes: attrs)
        let size = str.size()
        // Anchor at the bottom-left of the glyph run, matching where the
        // user clicked. Future versions can offer centre-anchored text.
        str.draw(at: point)
        // Suppress unused warning for `size` — kept for future hit-testing.
        _ = size
    }
}
