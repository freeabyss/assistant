import XCTest
@testable import Qingniao

final class DataDirectoryMigratorTests: XCTestCase {
    private var root: URL!
    private let fileManager = FileManager.default

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = fileManager.temporaryDirectory
            .appendingPathComponent("DataMigratorTests-")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let root { try? fileManager.removeItem(at: root) }
        root = nil
        try super.tearDownWithError()
    }

    private func makeMigrator() -> DataDirectoryMigrator {
        DataDirectoryMigrator(
            applicationSupportDirectory: root,
            legacyDirectoryName: "Assistant",
            newDirectoryName: "Qingniao",
            legacyStoreFileName: "Assistant.sqlite",
            newStoreFileName: "Qingniao.sqlite",
            fileManager: fileManager
        )
    }

    func testFreshInstallWhenNoDirectories() {
        let outcome = makeMigrator().migrateIfNeeded()
        XCTAssertEqual(outcome, .freshInstall)
        XCTAssertFalse(fileManager.fileExists(atPath: root.appendingPathComponent("Qingniao").path))
    }

    func testAlreadyMigratedWhenNewDirectoryExists() throws {
        try fileManager.createDirectory(at: root.appendingPathComponent("Qingniao"), withIntermediateDirectories: true)
        let outcome = makeMigrator().migrateIfNeeded()
        XCTAssertEqual(outcome, .alreadyMigrated)
    }

    func testMovesLegacyDirectoryAndRenamesStoreFiles() throws {
        let legacy = root.appendingPathComponent("Assistant", isDirectory: true)
        try fileManager.createDirectory(at: legacy.appendingPathComponent("Clipboard/Images"), withIntermediateDirectories: true)
        for suffix in ["", "-shm", "-wal"] {
            try Data("db\(suffix)".utf8).write(to: legacy.appendingPathComponent("Assistant.sqlite\(suffix)"))
        }
        try Data("thumb".utf8).write(to: legacy.appendingPathComponent("Clipboard/Images/a.png"))

        let outcome = makeMigrator().migrateIfNeeded()
        XCTAssertEqual(outcome, .migrated)

        let new = root.appendingPathComponent("Qingniao", isDirectory: true)
        XCTAssertFalse(fileManager.fileExists(atPath: legacy.path))
        XCTAssertTrue(fileManager.fileExists(atPath: new.path))
        for suffix in ["", "-shm", "-wal"] {
            XCTAssertTrue(fileManager.fileExists(atPath: new.appendingPathComponent("Qingniao.sqlite\(suffix)").path))
            XCTAssertFalse(fileManager.fileExists(atPath: new.appendingPathComponent("Assistant.sqlite\(suffix)").path))
        }
        // Non-store resources are preserved under the moved directory.
        XCTAssertTrue(fileManager.fileExists(atPath: new.appendingPathComponent("Clipboard/Images/a.png").path))
    }
}
