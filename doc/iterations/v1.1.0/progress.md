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
