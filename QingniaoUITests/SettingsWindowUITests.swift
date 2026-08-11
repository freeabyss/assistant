import XCTest

/// TC-UI-019~020：设置窗口导航
///
/// 依据：`docs/iterations/v1.2.1/test/cases.md` TC-UI-019~020
/// 前置：`--uitest-mark-onboarding-completed` + `--uitest-trigger openSettings`/`openAbout`
/// 硬依赖（cases.md §0.5）：`settings.sidebar`
///
/// 文案偏差说明：cases.md §TC-UI-019 侧栏项引用"剪贴板"，实际 L10n key
/// `management.page.clipboard` 的 zh-Hans 值为"剪贴板历史"。本用例用实际 L10n 文案。
final class SettingsWindowUITests: XCTestCase {

    private var app: XCUIApplication!
    private var tmpDirURL: URL?

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        if let app = app, app.state != .notRunning {
            app.terminate()
        }
        if let url = tmpDirURL {
            try? FileManager.default.removeItem(at: url)
            tmpDirURL = nil
        }
    }

    // MARK: - Helpers

    @discardableResult
    private func makeTmpDir(for caseName: String) -> String {
        let path = NSTemporaryDirectory()
            + "QingniaoUITest/SettingsWindowUITests/\(caseName)"
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        tmpDirURL = url
        return url.path
    }

    private func baseArgs(tmpDir: String) -> [String] {
        ["--uitest-data-dir", tmpDir, "--uitest-skip-shortcuts"]
    }

    // MARK: - TC-UI-019　设置窗口侧栏导航切换

    /// 覆盖：FR-UI-5/8；US-011；全局 PRD §9.4 P-03
    /// 前置：mark-completed + `--uitest-trigger openSettings`
    /// 验证：点侧栏"剪贴板历史" -> 主区域切换到剪贴板设置（含"保留时间"）；
    ///       点"快捷键" -> 主区域切换到快捷键设置（含"打开搜索"）；
    ///       点"关于" -> 主区域切换到关于页（含"青鸟"/"Qingniao"）。
    func testTCUI019SidebarNavigationSwitches() throws {
        let tmpDir = makeTmpDir(for: "TC-UI-019")
        app.launchArguments = baseArgs(tmpDir: tmpDir)
            + ["--uitest-mark-onboarding-completed", "--uitest-trigger", "openSettings"]
        app.launch()
        app.activate()

        let sidebar = app.groups["settings.sidebar"]
        XCTAssertTrue(
            sidebar.waitForExistence(timeout: 10),
            "TC-UI-019: 设置窗口侧栏应呈现"
        )

        // 1. 点侧栏"剪贴板历史"项（实际 L10n；cases.md 写"剪贴板"）
        let clipboardItem = app.staticTexts["剪贴板历史"]
        XCTAssertTrue(
            clipboardItem.waitForExistence(timeout: 5),
            "TC-UI-019: 侧栏应含\"剪贴板历史\"项"
        )
        clipboardItem.click()
        // 主区域切换：剪贴板设置含"保留时间"（management.clipboard.retention，zh-Hans "保留时间"）
        let retentionText = app.staticTexts["保留时间"]
        XCTAssertTrue(
            retentionText.waitForExistence(timeout: 3),
            "TC-UI-019: 点\"剪贴板历史\"后主区域应切换到剪贴板设置（含\"保留时间\"）"
        )

        // 2. 点侧栏"快捷键"项
        let shortcutsItem = app.staticTexts["快捷键"]
        XCTAssertTrue(
            shortcutsItem.waitForExistence(timeout: 5),
            "TC-UI-019: 侧栏应含\"快捷键\"项"
        )
        shortcutsItem.click()
        // 主区域切换：快捷键设置含"打开搜索"（management.shortcuts.search，zh-Hans "打开搜索"）
        let searchShortcutText = app.staticTexts["打开搜索"]
        XCTAssertTrue(
            searchShortcutText.waitForExistence(timeout: 3),
            "TC-UI-019: 点\"快捷键\"后主区域应切换到快捷键设置（含\"打开搜索\"）"
        )

        // 3. 点侧栏"关于"项
        let aboutItem = app.staticTexts["关于"]
        XCTAssertTrue(
            aboutItem.waitForExistence(timeout: 5),
            "TC-UI-019: 侧栏应含\"关于\"项"
        )
        aboutItem.click()
        // 主区域切换：关于页含"青鸟"或"Qingniao"
        let qingniaoText = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "青鸟")
        ).firstMatch
        let pinyinText = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "Qingniao")
        ).firstMatch
        let aboutSwitched = qingniaoText.waitForExistence(timeout: 3) || pinyinText.exists
        XCTAssertTrue(
            aboutSwitched,
            "TC-UI-019: 点\"关于\"后主区域应切换到关于页（含\"青鸟\"或\"Qingniao\"）"
        )
    }

    // MARK: - TC-UI-020　关于页版本号可见

    /// 覆盖：FR-UI-8；FR-UI-ABOUT-VERSION；US-011；全局 PRD §9.4 P-03
    /// 前置：mark-completed + `--uitest-trigger openAbout`
    /// 验证：关于页显示版本号（label 匹配 1.2.* 格式）；不验证三源一致（退回脚本/构建检查）。
    ///
    /// 实现说明：cases.md §TC-UI-020 用 `label MATCHES "1\\.2\\..*"`，但实际 L10n label 为
    /// "版本 1.2.1 (123)"（about.version 模板"版本 %@ (%@)"）。MATCHES 整体匹配会失败。
    /// 本用例改用 `MATCHES ".*1\\.2\\..*"`（前后加 .*），等价于 CONTAINS "1.2."，能匹配实际 label。
    func testTCUI020AboutPageShowsVersion() throws {
        let tmpDir = makeTmpDir(for: "TC-UI-020")
        app.launchArguments = baseArgs(tmpDir: tmpDir)
            + ["--uitest-mark-onboarding-completed", "--uitest-trigger", "openAbout"]
        app.launch()
        app.activate()

        // 版本号 staticText：label 含 "1.2.x" 子串（实际 label 形如 "版本 1.2.1 (123)"）
        let versionText = app.staticTexts.containing(
            NSPredicate(format: "label MATCHES %@", ".*1\\.2\\..*")
        ).firstMatch
        XCTAssertTrue(
            versionText.waitForExistence(timeout: 10),
            "TC-UI-020: 关于页应显示版本号（label 含 1.2.x 子串）"
        )
    }
}
