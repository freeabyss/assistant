import Cocoa
import CoreImage

// MARK: - Annotation Model

/// Screenshot annotation tool set for Assistant MVP US-017.
enum AnnotationTool: String, Codable, CaseIterable, Identifiable {
    case rectangle
    case arrow
    case text
    case mosaic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rectangle: return L10n.localized("annotation.tool.rectangle")
        case .arrow: return L10n.localized("annotation.tool.arrow")
        case .text: return L10n.localized("annotation.tool.text")
        case .mosaic: return L10n.localized("annotation.tool.mosaic")
        }
    }

    var systemImage: String {
        switch self {
        case .rectangle: return "rectangle"
        case .arrow: return "arrow.up.right"
        case .text: return "textformat"
        case .mosaic: return "square.grid.3x3.square"
        }
    }
}

enum AnnotationColor: String, Codable, CaseIterable, Identifiable {
    case red, yellow, blue, green, white, black

    var id: String { rawValue }

    var nsColor: NSColor {
        switch self {
        case .red: return .systemRed
        case .yellow: return .systemYellow
        case .blue: return .systemBlue
        case .green: return .systemGreen
        case .white: return .white
        case .black: return .black
        }
    }

    var displayName: String {
        switch self {
        case .red: return L10n.localized("annotation.color.red")
        case .yellow: return L10n.localized("annotation.color.yellow")
        case .blue: return L10n.localized("annotation.color.blue")
        case .green: return L10n.localized("annotation.color.green")
        case .white: return L10n.localized("annotation.color.white")
        case .black: return L10n.localized("annotation.color.black")
        }
    }
}

enum AnnotationLineWidth: String, Codable, CaseIterable, Identifiable {
    case thin, medium, thick

    var id: String { rawValue }

    var points: CGFloat {
        switch self {
        case .thin: return 2
        case .medium: return 4
        case .thick: return 8
        }
    }

    var displayName: String {
        switch self {
        case .thin: return L10n.localized("annotation.lineWidth.thin")
        case .medium: return L10n.localized("annotation.lineWidth.medium")
        case .thick: return L10n.localized("annotation.lineWidth.thick")
        }
    }
}

enum AnnotationTextSize: String, Codable, CaseIterable, Identifiable {
    case small, medium, large

    var id: String { rawValue }

    var points: CGFloat {
        switch self {
        case .small: return 18
        case .medium: return 28
        case .large: return 42
        }
    }

    var displayName: String {
        switch self {
        case .small: return L10n.localized("annotation.textSize.small")
        case .medium: return L10n.localized("annotation.textSize.medium")
        case .large: return L10n.localized("annotation.textSize.large")
        }
    }
}

struct AnnotationStyle: Hashable, Codable {
    var color: AnnotationColor = .red
    var lineWidth: AnnotationLineWidth = .medium
    var textSize: AnnotationTextSize = .medium
}

struct AnnotationShape: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var tool: AnnotationTool
    var startPoint: CGPoint
    var endPoint: CGPoint?
    var text: String?
    var style: AnnotationStyle

    var rect: CGRect {
        let end = endPoint ?? startPoint
        return CGRect(
            x: min(startPoint.x, end.x),
            y: min(startPoint.y, end.y),
            width: abs(startPoint.x - end.x),
            height: abs(startPoint.y - end.y)
        ).standardized
    }
}

// MARK: - Rendering

enum AnnotationRenderer {
    private static let arrowHeadLength: CGFloat = 18
    private static let arrowHeadAngle: CGFloat = .pi / 6
    private static let mosaicScale: CGFloat = 10

    static func draw(_ shapes: [AnnotationShape], sourceImage: NSImage?) {
        for shape in shapes {
            switch shape.tool {
            case .rectangle:
                drawRectangle(shape)
            case .arrow:
                drawArrow(shape)
            case .text:
                drawText(shape)
            case .mosaic:
                drawMosaic(shape, sourceImage: sourceImage)
            }
        }
    }

    private static func drawRectangle(_ shape: AnnotationShape) {
        let path = NSBezierPath(rect: shape.rect)
        path.lineWidth = shape.style.lineWidth.points
        shape.style.color.nsColor.setStroke()
        path.stroke()
    }

    private static func drawArrow(_ shape: AnnotationShape) {
        guard let end = shape.endPoint else { return }
        let start = shape.startPoint
        let color = shape.style.color.nsColor
        let width = shape.style.lineWidth.points
        color.setStroke()
        color.setFill()

        let shaft = NSBezierPath()
        shaft.lineWidth = width
        shaft.lineCapStyle = .round
        shaft.move(to: start)
        shaft.line(to: end)
        shaft.stroke()

        let dx = start.x - end.x
        let dy = start.y - end.y
        let length = max((dx * dx + dy * dy).squareRoot(), 0.001)
        let ux = dx / length
        let uy = dy / length
        let cosA = cos(arrowHeadAngle)
        let sinA = sin(arrowHeadAngle)
        let head = arrowHeadLength + width
        let left = CGPoint(x: end.x + head * (ux * cosA - uy * sinA), y: end.y + head * (ux * sinA + uy * cosA))
        let right = CGPoint(x: end.x + head * (ux * cosA + uy * sinA), y: end.y + head * (-ux * sinA + uy * cosA))

        let headPath = NSBezierPath()
        headPath.move(to: end)
        headPath.line(to: left)
        headPath.line(to: right)
        headPath.close()
        headPath.fill()
    }

    private static func drawText(_ shape: AnnotationShape) {
        guard let text = shape.text, !text.isEmpty else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: shape.style.textSize.points, weight: .semibold),
            .foregroundColor: shape.style.color.nsColor,
            .strokeColor: NSColor.black.withAlphaComponent(shape.style.color == .black ? 0 : 0.35),
            .strokeWidth: -2.0
        ]
        NSAttributedString(string: text, attributes: attributes).draw(at: shape.startPoint)
    }

    private static func drawMosaic(_ shape: AnnotationShape, sourceImage: NSImage?) {
        let target = shape.rect
        guard target.width > 1, target.height > 1 else { return }
        guard let image = sourceImage else {
            NSColor.gray.withAlphaComponent(0.65).setFill()
            target.fill()
            return
        }
        var proposed = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &proposed, context: nil, hints: nil) else {
            NSColor.gray.withAlphaComponent(0.65).setFill()
            target.fill()
            return
        }

        let input = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIPixellate") else { return }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(mosaicScale, forKey: kCIInputScaleKey)
        filter.setValue(CIVector(x: target.midX, y: target.midY), forKey: kCIInputCenterKey)
        guard let output = filter.outputImage else { return }
        let context = CIContext(options: nil)
        guard let cgOutput = context.createCGImage(output, from: target),
              let graphics = NSGraphicsContext.current?.cgContext else { return }
        graphics.saveGState()
        graphics.draw(cgOutput, in: target)
        graphics.restoreGState()
    }
}

enum AnnotationFlattener {
    static func flatten(image: NSImage, shapes: [AnnotationShape]) -> NSImage {
        let output = NSImage(size: image.size)
        output.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: image.size), from: .zero, operation: .copy, fraction: 1)
        AnnotationRenderer.draw(shapes, sourceImage: image)
        output.unlockFocus()
        return output
    }

    static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
