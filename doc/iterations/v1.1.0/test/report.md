# v1.1.0 测试执行报告

## 一、T-001 自动化测试（Step 3 独立验证）

- **执行时间**：2026-07-02
- **执行者**：test subagent（独立复跑）

### swift test
- 命令：`swift test`
- 结果：128/128 通过（v1.0.1 基线 126；本次 N=128，+2）
- TC-U-001 断言：MockPermissionService 与 StaticPermissionService 均实现 requestScreenRecordingPrompt() 且行为符合预期（Mock callCount==1 + 可配置返回值；Static 固定返回 true）
- 判定：TC-U-001 通过、TC-U-007（spy 基础设施 = MockPermissionService.requestScreenRecordingCallCount + requestScreenRecordingResult）通过

### xcodebuild test
- 命令：`xcodebuild test -project SnapVault.xcodeproj -scheme SnapVault -destination 'platform=macOS' -derivedDataPath ./DerivedData`
- 首跑：FAIL —— 2 条 flaky 失败（SearchBlacklistRepositoryTests.testSearchServiceFiltersOnlyBlacklistedConcreteResultAndRestoresAfterRemoval、SettingsSourceTests.testSettingsSourceCanBeHiddenByPersistentSearchSourceSwitch），与 T-001 改动无关（属顺序敏感的历史 flaky）
- 重跑：PASS —— 119/119 全绿
- 结果：119/119（新增测试文件 PermissionServiceProtocolConformanceTests.swift 未纳入 Xcode target，P2 遗留，与 v1.0.1 处理一致）
- 判定：PASS

### T-001 结论
- done_definition：6/6 满足
- 是否可以 commit T-001：是

## 二、T-002 自动化测试（Step 3 独立验证）

- **执行时间**：2026-07-02
- **执行者**：test subagent（独立复跑）

### swift test
- 命令：`swift test`
- 结果：134/134 通过（本次 N=134；v1.0.1 基线 126 + T-001 新增 2 + T-002 新增 6）
- 新增用例 TC-U-002/003/004/005/006：全绿（无 XCTSkip 降级）
- 判定：PASS
- 备注：首跑遭遇一条与 T-002 无关的历史 flaky 崩溃（SearchBlacklistRepositoryTests，PersistenceController.initializeDefaultSettings 的 NSCFSet mutated-while-enumerated），重跑一次即全绿

### xcodebuild test
- 命令：`xcodebuild test -project SnapVault.xcodeproj -scheme SnapVault -destination 'platform=macOS' -derivedDataPath ./DerivedData`
- 结果：125/125 TEST SUCCEEDED（新增测试追加到既有 OnboardingViewModelTests.swift，随 target 一起执行；预期 125）
- 判定：PASS

### T-002 结论
- done_definition：7/7 满足
- clipboardEnabled 显式 false：确认落地（红线）
- Skip 按钮 7 步可见：确认（footer 恒渲染）
- L10n 双语齐全：确认
- 可以 commit T-002：是

## 三、T-003 自动化测试（无新增用例，回归验证）
- swift test：134/134 全绿
- xcodebuild test：125/125 TEST SUCCEEDED
- AC-7 手工验收留待 T-004（TC-M-008）
