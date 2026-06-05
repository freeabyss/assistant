import XCTest
@testable import SnapVault

final class DatabaseManagerTests: XCTestCase {

    func testDatabaseURL() {
        let url = DatabaseManager.databaseURL()
        XCTAssertTrue(url.path.hasSuffix("snapvault.db"))
        XCTAssertTrue(url.path.contains("Application Support"))
        XCTAssertTrue(url.path.contains("SnapVault"))
    }

    func testMigratorRegistration() {
        let migrator = DatabaseManager.migrator()
        // Verify migrator is created without errors
        XCTAssertNotNil(migrator)
    }
}
