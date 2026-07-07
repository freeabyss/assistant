import XCTest
@testable import Qingniao

final class SettingsServiceTests: XCTestCase {
    private var tempDirectory: URL!
    private var persistence: PersistenceController!
    private var service: SettingsService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AssistantSettingsServiceTests-")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileSystem = AssistantFileSystem(rootDirectory: tempDirectory)
        persistence = PersistenceController(storeConfiguration: .temporary, fileSystem: fileSystem)
        try persistence.load()
        service = SettingsService(persistence: persistence)
    }

    override func tearDownWithError() throws {
        service = nil
        persistence = nil
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
        try super.tearDownWithError()
    }

    func testDefaultSearchSourceSwitchesAreEnabled() async throws {
        let appEnabled = try await service.value(for: .appSourceEnabled, as: Bool.self)
        let clipboardShown = try await service.value(for: .clipboardShowInSearch, as: Bool.self)
        let commandEnabled = try await service.value(for: .commandSourceEnabled, as: Bool.self)
        let calculatorEnabled = try await service.value(for: .calculatorSourceEnabled, as: Bool.self)
        let settingsEnabled = try await service.value(for: .settingsSourceEnabled, as: Bool.self)

        XCTAssertTrue(appEnabled)
        XCTAssertTrue(clipboardShown)
        XCTAssertTrue(commandEnabled)
        XCTAssertTrue(calculatorEnabled)
        XCTAssertTrue(settingsEnabled)
    }

    func testClipboardIsOnlyFunctionalEnableDisableSetting() async throws {
        let clipboardEnabled = try await service.value(for: .clipboardEnabled, as: Bool.self)
        XCTAssertTrue(clipboardEnabled)

        let functionalToggleKeys = SettingKey.allCases.filter { key in
            key.rawValue.hasSuffix(".enabled") && !key.rawValue.hasPrefix("search.source.")
        }
        XCTAssertEqual(functionalToggleKeys, [.launchAtLoginEnabled, .clipboardEnabled])
    }

    func testLanguageOptionsAndDefaultFollowSystem() async throws {
        XCTAssertEqual(LanguageMode.allCases, [.followSystem, .simplifiedChinese, .english])

        let defaultLanguage = try await service.value(for: .languageMode, as: LanguageMode.self)
        XCTAssertEqual(defaultLanguage, .followSystem)

        try await service.set(LanguageMode.simplifiedChinese, for: .languageMode)
        let simplifiedChinese = try await service.value(for: .languageMode, as: LanguageMode.self)
        XCTAssertEqual(simplifiedChinese, .simplifiedChinese)

        try await service.set(LanguageMode.english, for: .languageMode)
        let rawLanguage = try await service.stringValue(for: .languageMode)
        XCTAssertEqual(rawLanguage, "en")
    }

    func testClipboardRetentionDefaultsAndPersistsPresetValues() async throws {
        XCTAssertEqual(ClipboardRetention.allCases, [.sevenDays, .thirtyDays, .ninetyDays, .forever])

        let defaultRetention = try await service.value(for: .clipboardRetention, as: ClipboardRetention.self)
        XCTAssertEqual(defaultRetention, .thirtyDays)

        try await service.set(ClipboardRetention.ninetyDays, for: .clipboardRetention)
        let persistedRetention = try await service.value(for: .clipboardRetention, as: ClipboardRetention.self)
        let rawRetention = try await service.stringValue(for: .clipboardRetention)
        XCTAssertEqual(persistedRetention, .ninetyDays)
        XCTAssertEqual(rawRetention, "90d")
    }

    func testScreenshotSaveDirectoryAndLaunchAtLoginPersist() async throws {
        let defaultDirectory = try await service.stringValue(for: .screenshotSaveDirectory)
        let defaultLaunchAtLogin = try await service.value(for: .launchAtLoginEnabled, as: Bool.self)
        XCTAssertEqual(defaultDirectory, "~/Desktop")
        XCTAssertTrue(defaultLaunchAtLogin)

        let customDirectory = tempDirectory.appendingPathComponent("Shots", isDirectory: true)
        try await service.set(customDirectory, for: .screenshotSaveDirectory)
        try await service.set(false, for: .launchAtLoginEnabled)

        let persistedDirectory = try await service.value(for: .screenshotSaveDirectory, as: URL.self)
        let persistedLaunchAtLogin = try await service.value(for: .launchAtLoginEnabled, as: Bool.self)
        XCTAssertEqual(persistedDirectory.standardizedFileURL.path, customDirectory.standardizedFileURL.path)
        XCTAssertFalse(persistedLaunchAtLogin)
    }

    func testResetRestoresDefaultValue() async throws {
        try await service.set(false, for: .settingsSourceEnabled)
        let disabled = try await service.value(for: .settingsSourceEnabled, as: Bool.self)
        XCTAssertFalse(disabled)

        try await service.reset(key: .settingsSourceEnabled)
        let reset = try await service.value(for: .settingsSourceEnabled, as: Bool.self)
        XCTAssertTrue(reset)
    }

    func testLanguageModePersistsRawValuesRequiredForAppLanguageOverride() async throws {
        try await service.set(LanguageMode.followSystem, for: .languageMode)
        let followSystemRaw = try await service.stringValue(for: .languageMode)
        XCTAssertEqual(followSystemRaw, "system")

        try await service.set(LanguageMode.simplifiedChinese, for: .languageMode)
        let simplifiedChineseRaw = try await service.stringValue(for: .languageMode)
        XCTAssertEqual(simplifiedChineseRaw, "zh-Hans")

        try await service.set(LanguageMode.english, for: .languageMode)
        let englishRaw = try await service.stringValue(for: .languageMode)
        XCTAssertEqual(englishRaw, "en")
    }
}
