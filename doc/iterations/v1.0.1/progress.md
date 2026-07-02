# v1.0.1 开发进度

## 2026-07-02 · T-001 开发完成
- 修改：SnapVault/Services/UpdateService/UpdateService.swift（新增 `static let startsUpdaterAutomatically: Bool = false` 常量，绑定到 `SPUStandardUpdaterController(startingUpdater:)` 入参，替换原 `true`）
- 新增：SnapVaultTests/UpdateServiceTests.swift（2 条用例：TC-U-001 `test_startsUpdaterAutomatically_isFalse_toPreventStartupCrash`、TC-U-002 `test_checkNow_callsUpdateCheckService_openDownloadPage_exactlyOnce`）
- 单测：`swift test` 126/126 全绿（v1.0.0 基线 124，新增 2 条）；`xcodebuild test` 119/119 全绿，`** TEST SUCCEEDED **`
- 采用策略 A（review.md 推荐 · 常量绑定）+ spy 方式一（注入 `UpdateCheckServiceProtocol` spy `RecordingUpdateCheckService`，记录 `openDownloadPage()` 调用次数）。选方式一原因：`checkNow()` 直接同步调用注入的 `updateCheckService.openDownloadPage()`，init 已是现成注入点，无需深入 WebUpdateCheckService 注入 opener，侵入最小且完全不触碰真实 NSWorkspace。
- 备注：Xcode 测试 target 使用 project.pbxproj 显式文件引用（非 filesystem-synchronized），新增的 UpdateServiceTests.swift 未加入 SnapVaultTests target，故 `xcodebuild test` 计数仍为 119（=基线，未回归）。将该文件加入 target 需编辑 project.pbxproj，超出 files_touch_hint 范围，故未改动。TC-U-001/TC-U-002 的绿色由 `swift test`（126）保证；xcodebuild 侧保持基线且 TEST SUCCEEDED。待 code review 决定是否需要主会话补入 Xcode target。

## 2026-07-02 · T-001 Step 3 独立测试验证
- swift test：126/126 全绿
- xcodebuild test：119/119 TEST SUCCEEDED（首跑即绿，未复现 code review 记录的 linkd XPC 冷启动 flaky）
- test/report.md 已生成
- T-001 passes 置为 true
