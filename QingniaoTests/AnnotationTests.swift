import XCTest
@testable import SnapVault
import AppKit

final class AnnotationTests: XCTestCase {
    func testStylePresetsMatchUS017Requirements() {
        XCTAssertEqual(AnnotationColor.allCases.map(\.rawValue), ["red", "yellow", "blue", "green", "white", "black"])
        XCTAssertEqual(AnnotationLineWidth.allCases.map(\.points), [2, 4, 8])
        XCTAssertEqual(AnnotationTextSize.allCases.map(\.points), [18, 28, 42])
    }

    func testAnnotationShapeCodableRoundTrip() throws {
        let shape = AnnotationShape(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000017")!,
            tool: .text,
            startPoint: CGPoint(x: 12, y: 34),
            endPoint: nil,
            text: "Hello",
            style: AnnotationStyle(color: .blue, lineWidth: .thick, textSize: .large)
        )

        let data = try JSONEncoder().encode(shape)
        let decoded = try JSONDecoder().decode(AnnotationShape.self, from: data)

        XCTAssertEqual(decoded, shape)
    }

    func testFlattenRendersAnnotatedPNGData() throws {
        let source = NSImage(size: NSSize(width: 80, height: 60))
        source.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 80, height: 60).fill()
        source.unlockFocus()

        let shapes = [
            AnnotationShape(tool: .rectangle, startPoint: CGPoint(x: 5, y: 5), endPoint: CGPoint(x: 60, y: 40), text: nil, style: AnnotationStyle(color: .red, lineWidth: .medium, textSize: .medium)),
            AnnotationShape(tool: .arrow, startPoint: CGPoint(x: 10, y: 10), endPoint: CGPoint(x: 70, y: 50), text: nil, style: AnnotationStyle(color: .green, lineWidth: .thin, textSize: .small)),
            AnnotationShape(tool: .text, startPoint: CGPoint(x: 8, y: 42), endPoint: nil, text: "A", style: AnnotationStyle(color: .black, lineWidth: .thin, textSize: .small)),
            AnnotationShape(tool: .mosaic, startPoint: CGPoint(x: 20, y: 15), endPoint: CGPoint(x: 45, y: 35), text: nil, style: AnnotationStyle(color: .red, lineWidth: .thin, textSize: .small))
        ]

        let flattened = AnnotationFlattener.flatten(image: source, shapes: shapes)
        let png = try XCTUnwrap(AnnotationFlattener.pngData(from: flattened))

        XCTAssertGreaterThan(png.count, 8)
        XCTAssertEqual(Array(png.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
    }
}
