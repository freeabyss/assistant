import XCTest
@testable import SnapVault

final class DatabaseManagerTests: XCTestCase {

    func testDatabaseURL() {
        let url = DatabaseManager.databaseURL()
        XCTAssertTrue(url.path.hasSuffix("assistant.db"))
        XCTAssertTrue(url.path.contains("Application Support"))
        XCTAssertTrue(url.path.contains("Assistant"))
    }

    func testMigratorRegistration() {
        let migrator = DatabaseManager.migrator()
        // Verify migrator is created without errors
        XCTAssertNotNil(migrator)
    }

    /// Verify ClipboardItem model exposes the isFavorite property (US-021).
    /// Default value is false and toggling works in-memory.
    func testClipboardItemIsFavoriteDefault() {
        let item = ClipboardItem(
            contentType: .text,
            textContent: "hello",
            contentHash: "h1"
        )
        XCTAssertFalse(item.isFavorite, "isFavorite should default to false")
        XCTAssertFalse(item.isPinned, "isPinned should default to false")

        var mutable = item
        mutable.isFavorite = true
        XCTAssertTrue(mutable.isFavorite)
        XCTAssertFalse(mutable.isPinned, "Toggling favorite should not affect pin")
    }

    /// Verify pin and favorite are orthogonal flags.
    func testPinAndFavoriteAreIndependent() {
        var item = ClipboardItem(
            contentType: .text,
            textContent: "hi",
            contentHash: "h2",
            isPinned: true,
            isFavorite: true
        )
        XCTAssertTrue(item.isPinned)
        XCTAssertTrue(item.isFavorite)

        item.isPinned = false
        XCTAssertFalse(item.isPinned)
        XCTAssertTrue(item.isFavorite, "Unpinning should not affect favorite")

        item.isFavorite = false
        XCTAssertFalse(item.isFavorite)
        XCTAssertFalse(item.isPinned)
    }

    /// Verify ExportItem round-trips isFavorite through JSON encoding/decoding.
    func testExportItemPreservesIsFavorite() throws {
        let original = ClipboardItem(
            contentType: .text,
            textContent: "favorited content",
            contentHash: "hfav",
            isPinned: false,
            isFavorite: true
        )
        let exported = ExportItem(from: original)
        XCTAssertTrue(exported.isFavorite)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exported)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let roundTripped = try decoder.decode(ExportItem.self, from: data)
        XCTAssertTrue(roundTripped.isFavorite)

        let restored = roundTripped.toClipboardItem()
        XCTAssertTrue(restored.isFavorite)
        XCTAssertFalse(restored.isPinned)
    }

    /// Verify legacy JSON (without isFavorite field) decodes with isFavorite=false.
    func testExportItemBackwardCompatibleDecoding() throws {
        // Legacy JSON shape from v1 exports (no isFavorite key)
        let legacyJSON = """
        {
          "contentType": "text",
          "textContent": "legacy",
          "rtfContent": null,
          "imageData": null,
          "filePath": null,
          "ocrText": null,
          "contentHash": "hlegacy",
          "isPinned": true,
          "createdAt": "2025-01-01T00:00:00Z",
          "updatedAt": "2025-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportItem.self, from: legacyJSON)
        XCTAssertTrue(decoded.isPinned)
        XCTAssertFalse(decoded.isFavorite, "Legacy JSON without isFavorite should default to false")
    }
}
