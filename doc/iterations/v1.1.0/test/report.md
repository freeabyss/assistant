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

## 四、T-004 手工验收（用户 @user 执行）

- **执行时间**：2026-07-03
- **执行者**：@user（人工）
- **范围**：TC-M-001 ~ TC-M-006（核心路径通过）；TC-M-007/008/009 按用户决策延期

| 用例 | 结果 | 观察 |
|------|------|------|
| TC-M-001（AC-1） | ✅ 通过 | 进入屏幕录制步骤时系统权限弹窗出现 |
| TC-M-002（AC-2） | ✅ 通过 | 系统设置"屏幕录制"列表中出现本 App |
| TC-M-003（AC-3） | ✅ 通过 | 授权后 Continue 可继续 |
| TC-M-004（AC-4） | ✅ 通过 | 7 步 footer 均可见 Skip 按钮 |
| TC-M-005（P-2.2） | ✅ 通过 | 确认 Alert 出现；Cancel 无副作用 |
| TC-M-006（AC-5） | ✅ 通过 | 点 Skip 后主界面出现 |
| TC-M-007（AC-6） | ⏭️ 延期 | 用户决策留待下一迭代（重启不重弹端到端） |
| TC-M-008（AC-7 hotkey 路径） | ⏭️ 延期 | 用户决策留待下一迭代（按需申请 Alert 端到端） |
| TC-M-009（AC-7 设置面板） | ⏭️ 延期 | 用户决策留待下一迭代（设置面板入口端到端） |

### 已知待验证项（下一迭代处理）
- AC-6：跳过后重启不重弹 onboarding（代码层 `onboardingCompleted=true` 持久化由 TC-U-004 单测覆盖，但端到端重启行为未验）
- AC-7：按需申请 Alert 弹出 + 点"打开设置"后对称调用 request 流程（代码层 AppDelegate.ensureScreenRecordingPermission 已补 request，由 review §§八 + T-003 自审坐实，但端到端行为未验）
- SettingsViewModel 权限申请入口（评审 P2 遗留，未强制改造）

### T-004 结论
- 核心路径（TCC 注册 + Skip 进入主界面）用户亲自验收 6/6 通过
- 延期 3 条已文档化，留待下一迭代
- 判定：T-004 passes=true，允许开 PR
