import XCTest
@testable import SnapVault

final class SettingsSourceTests: XCTestCase {
    func testChinesePinyinMatchesSettingsRoute() async {
        let source = SettingsSource()

        let results = await source.search(query: "jiantieban")

        XCTAssertTrue(results.contains { $0.id.rawValue == "setting:\(SettingsRoute.clipboardHistory.rawValue)" })
    }

    func testInitialsMatchesSettingsRoute() async {
        let source = SettingsSource()

        let results = await source.search(query: "kjj")

        XCTAssertTrue(results.contains { $0.id.rawValue == "setting:\(SettingsRoute.hotkey.rawValue)" })
    }

    func testEnglishAliasMatchesRegardlessOfInterfaceLanguage() async {
        let source = SettingsSource()

        let results = await source.search(query: "privacy")

        XCTAssertTrue(results.contains { $0.id.rawValue == "setting:\(SettingsRoute.permissions.rawValue)" })
    }
}
