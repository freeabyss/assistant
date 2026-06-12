import XCTest
@testable import SnapVault

final class SettingsSourceTests: XCTestCase {
    private var tempDirectory: URL!
    private var persistence: PersistenceController!
    private var settingsService: SettingsService!

    override func tearDownWithError() throws {
        settingsService = nil
        persistence = nil
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
        try super.tearDownWithError()
    }

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

    func testDefaultRoutesCoverPageAndSettingSectionEntrypoints() {
        let routes = Set(SettingsSource.defaultRoutes.map(\.id))

        XCTAssertEqual(routes, Set([
            .settings,
            .permissions,
            .clipboardHistory,
            .searchSources,
            .hotkey,
            .screenshot,
            .about
        ]))
    }

    func testSettingsSearchResultsOnlyOpenRoutesAndDoNotToggleSettings() async {
        let source = SettingsSource()

        let results = await source.search(query: "搜索源开关")

        XCTAssertTrue(results.contains { $0.id.rawValue == "setting:\(SettingsRoute.searchSources.rawValue)" })
        XCTAssertTrue(results.allSatisfy { result in
            if case .openSettings = result.primaryAction {
                return result.secondaryActions.isEmpty
            }
            return false
        })
    }

    func testSettingsSourceCanBeHiddenByPersistentSearchSourceSwitch() async throws {
        try makeTemporarySettingsService()
        try await settingsService.set(false, for: .settingsSourceEnabled)
        let source = SettingsSource(settingsService: settingsService)

        let hiddenResults = await source.search(query: "settings")
        XCTAssertTrue(hiddenResults.isEmpty)

        try await settingsService.set(true, for: .settingsSourceEnabled)
        let visibleResults = await source.search(query: "settings")
        XCTAssertFalse(visibleResults.isEmpty)
    }

    private func makeTemporarySettingsService() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AssistantSettingsSourceTests-")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileSystem = AssistantFileSystem(rootDirectory: tempDirectory)
        persistence = PersistenceController(storeConfiguration: .temporary, fileSystem: fileSystem)
        try persistence.load()
        settingsService = SettingsService(persistence: persistence)
    }
}
