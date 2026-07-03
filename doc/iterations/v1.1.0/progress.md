# v1.1.0 迭代进度

## 2026-07-02 · T-001 开发完成
- 修改：SnapVault/Services/Permissions/PermissionService.swift（PermissionServiceProtocol 增 `@MainActor func requestScreenRecordingPrompt() -> Bool` 声明，无默认实现；PermissionService 实现内调 `CGRequestScreenCaptureAccess()`。CoreGraphics 已 import，无需新增）
- 修改：SnapVaultTests/OnboardingViewModelTests.swift（MockPermissionService 补 `requestScreenRecordingPrompt()` + spy 基础设施 `requestScreenRecordingResult` / `requestScreenRecordingCallCount`；未加 timestamp 数组，TC-U-003 顺序断言可用现有 `opened` 数组配合 callCount 实现，留待 T-002）
- 修改：SnapVaultTests/SettingsSourceTests.swift（StaticPermissionService 补 stub 返回固定 true）
- 新增：SnapVaultTests/PermissionServiceProtocolConformanceTests.swift（TC-U-001，2 个用例：Mock 断言 callCount==1 + 返回值；Static 断言返回 true）
- 单测：swift test 128/128 全绿（v1.0.1 基线 126 +2）；xcodebuild test 119/119 TEST SUCCEEDED（首跑即过，无 flaky）
- MockPermissionService 可见性调整：**是**。MockPermissionService（OnboardingViewModelTests.swift）与 StaticPermissionService（SettingsSourceTests.swift）原为 `private`，为让 TC-U-001 跨文件引用，提升为 `internal`（去掉 private）。遵循「最小侵入首选：提升可见性」。
- 新测试文件是否入 Xcode target：**否**。xcodebuild 用例数保持 119（SPM 侧 128 已含）。属 P2 遗留，不阻塞。
- 未 commit（等 code review + 后续 T-002/003/004 统一收尾）

## 2026-07-02 · T-001 Step 3 独立测试验证
- swift test：128/128 全绿
- xcodebuild test：119/119 TEST SUCCEEDED（首跑 2 条历史 flaky 失败，重跑一次全绿）
- test/report.md 已生成
- T-001.passes = true；code review APPROVED（reviews/task-T-001-review.md）
- 前瞻性提醒：T-002 需补 MockPermissionService.callLog 时序数组以支撑 TC-U-003 严格顺序断言（本任务不做，属 T-002 范围）

## 2026-07-02 · T-002 开发完成
- OnboardingViewModel.swift: continueToNextStep 的 .clipboardPrivacy→.screenRecording 分支追加 `_ = permissionService.requestScreenRecordingPrompt()`（同步路径，先于 refreshPermissions 的 Task）；openPermissionSettings 对 .screenRecording 先调 request 再 openSystemSettings；新增 `skipOnboarding() async`（try await settingsService：显式 set(false, .clipboardEnabled) + set(true, .onboardingCompleted) + 持久化 persistCurrentShortcutString() 到 .searchHotkey + onComplete()；不强制 launchAtLogin/不校验权限）。settingsService API 是 async throws，与 completeIfPossible 一致，故 skipOnboarding 用 do/catch。
- OnboardingView.swift: footer 左下角 Quit 旁新增 Skip 按钮（.buttonStyle(.link)），@State showSkipConfirmation，.alert 挂在最外层 VStack（7 步 footer 恒渲染，天然全步可见）。
- Localizable.xcstrings: +5 键（onboarding.skip / skip.confirm.title / .message / .action / .cancel），en+zh-Hans 双份，插在 onboarding.error.permissionsRequired 后，JSON 校验通过（python3 json.load valid）。
- MockPermissionService: 新增 `enum PermissionCall { case request(kind:) / openSettings(kind:) }` + `private(set) var callLog: [PermissionCall]`（前瞻性要求，支撑 TC-U-003 严格顺序断言）；保留既有 opened 数组兼容旧测试。
- 单测新增：TC-U-002（进入 screenRecording request 恰一次）/ TC-U-003（顺序 [request, openSettings]）+ accessibility 反向不触发 request / TC-U-004（显式 clipboardEnabled=false + 前置断言默认 true）/ TC-U-005（7 步参数化，每步新构造 VM）/ TC-U-006（hotkey 持久化 option+space）。全部正常执行，无 XCTSkip 降级。
- swift test: 134/134 全绿（v1.0.1 基线 126 + T-001 新增 2 + T-002 新增 6）。
- xcodebuild test: TEST SUCCEEDED（SnapVaultTests 125 tests，本次新增用例入 OnboardingViewModelTests 既有文件，随 target 编译执行；首跑即过）。
- 关键避坑：clipboard.enabled 默认 "true"（PersistenceController.swift:307，非 :307 行号笔误但值确为 true），skipOnboarding 必须显式写 false，否则 TC-U-004 XCTAssertFalse 失败且违背 PRD P-2.3。
- 未 commit（等 T-002 code review + 后续统一收尾）。

## 2026-07-02 · T-002 Step 3 独立测试验证
- swift test：134/134 全绿；xcodebuild test：125/125 TEST SUCCEEDED
- T-002.passes=true；code review APPROVED
- 红线全过：clipboardEnabled 显式 false（VM:119）、Skip 7 步可见、xcstrings JSON valid、TC-U-004 前置断言 default=true
- design.md §4.2 差异表非阻塞订正（"不写"→"显式 false"）留待 ⑥ 归档或后续 patch 顺手改
- 备注：swift test 首跑遭遇一条与 T-002 无关的历史 flaky 崩溃（SearchBlacklistRepositoryTests，NSCFSet mutated-while-enumerated），重跑一次全绿

## 2026-07-02 · T-003 开发 + 自审 + 测试完成
- AppDelegate.ensureScreenRecordingPermission 补 requestScreenRecordingPrompt（openSystemSettings 前一行）
- swift test 134/134；xcodebuild 125/125 TEST SUCCEEDED
- 单文件 diff（仅 AppDelegate.swift 该函数体）
- self-review APPROVED（reviews/task-T-003-review.md）

## 2026-07-03 · T-004 手工验收 + 收尾开 PR
- TC-M-001~006 由 @user 亲自验证通过（核心路径：TCC 注册 + Skip 进入主界面）
- TC-M-007/008/009 按用户决策延期（AC-6/AC-7 端到端），cases.md 与 tasks.json 已记录
- T-004.passes=true
- 代码冻结，准备开 PR
