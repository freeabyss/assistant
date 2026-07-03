# T-002 Code Review

- **审查时间**：2026-07-02
- **审查人**：code-review subagent
- **审查对象**：`git diff HEAD -- SnapVault/ SnapVaultTests/`（HEAD = T-001 commit 35b2208），完整读修改后 4 文件
- **审查结论**：APPROVED
- **进入 Step 3 测试环节**：是

## 一、done_definition 逐条核对

| # | 条目 | 状态 | 证据 |
|---|------|------|------|
| 1 | 进入 .screenRecording + openPermissionSettings(.screenRecording) 均触发 request | ✅ PASS | VM:74（continueToNextStep 进入 .screenRecording 后 `_ = permissionService.requestScreenRecordingPrompt()`，同步路径先于 refreshPermissions Task）；VM:99-102（openPermissionSettings 内 `.screenRecording` 分支先 request） |
| 2 | skipOnboarding 显式 clipboardEnabled=false + onboardingCompleted=true + onComplete | ✅ PASS | VM:119 `set(false, .clipboardEnabled)`；VM:120 `set(true, .onboardingCompleted)`；VM:122 `onComplete()` |
| 3 | footer 左下角 Skip 按钮 + 确认 Alert，7 步都可见 | ✅ PASS | View:116-119（footer HStack 左侧 Quit 旁，`.buttonStyle(.link)`，Spacer 后才是 Continue）；footer 与 step 无关恒渲染 → 7 步天然可见；Alert:21-31 挂最外层 VStack |
| 4 | Localizable.xcstrings 双语键齐全 | ✅ PASS | 5 键齐全，均含 en + zh-Hans；python3 json.load 校验 valid |
| 5 | TC-U-002/003/004/005/006 全绿 | ✅ PASS | 6 个新测试方法全部执行（含 TC-U-003 反向），swift test 无 failure |
| 6 | swift test ≥ 132 | ✅ PASS | `Executed 134 tests, with 0 failures`（126 基线 +T-001 2 +T-002 6） |
| 7 | xcodebuild test TEST SUCCEEDED | ✅ PASS | `Executed 125 tests, with 0 failures` + `** TEST SUCCEEDED **`（v1.0.1 119 +T-002 6，新增入 target） |

**结论：7/7 全部满足。**

## 二、skipOnboarding 关键约束

- **显式 `set(false, for: .clipboardEnabled)`（红线）**：✅ 已落地（VM:119），注释明确引用 P-2.3 与 PersistenceController:307 默认 true 的陷阱。
- **复用 `hotkeyService.persistCurrentShortcutString()`**：✅ VM:115，行为对齐 PRD"若已录入 hotkey 则持久化"（未录入返回默认 option+space）。
- **未强制 launchAtLogin**：✅ 无 launchAtLogin 写入/注册（对比 completeIfPossible:149-150 有）。
- **未校验/申请权限**：✅ 无 refreshPermissions / isCompleteReady 门槛。
- **错误处理**：✅ do/catch 与 completeIfPossible 一致，catch 落 completionErrorMessage，不吞关键错误。settingsService async throws 被正确 try await。

## 三、Skip 按钮 UI

- **7 步可见**：✅ 按钮在 footer HStack（View:116），footer 无 step 条件分支，恒渲染。
- **位置**：✅ 左下角，Quit 之后、`Spacer()`（View:120）之前，Continue 在最右，远离主 CTA。
- **样式**：✅ `.buttonStyle(.link)`，辅助样式，与 Quit（默认无边框）观感协调、区别于 Continue 的 `.borderedProminent`。
- **Alert**：✅ destructive Skip（confirm.action）+ cancel Cancel（confirm.cancel）+ title + message 四文案键正确使用，Skip 分支 `Task { await viewModel.skipOnboarding() }`。
- **Alert 挂载层**：最外层 VStack（View:21），可正常弹出，符合任务允许。

## 四、Localizable.xcstrings 有效性

- 5 键齐全：onboarding.skip / skip.confirm.title / .message / .action / .cancel。
- 每键均 en + zh-Hans 双份。
- JSON 结构 valid（python3 json.load 通过）。
- 文案与 PRD §五 / design §八逐字一致（含 message 双语版本、title "跳过引导？"）。

## 五、VM 变更

- **continueToNextStep 进入 .screenRecording**：request 在 `step = .screenRecording` 之后、`Task { refreshPermissions }` 之前的同步路径调用（VM:71-75），满足 TC-U-002 计数时序稳定（review §二 TC-U-002 时序提示已规避）。返回值不参与前进判定，canContinueCurrentStep 仍由 preflight 决定，功能等价。
- **openPermissionSettings 顺序**：request 在 openSystemSettings 之前（VM:101→103），满足 TC-U-003 `[request, openSettings]`。
- **completeIfPossible 未破坏**：VM:128-155 逻辑与 clipboardEnabled=true 强制路径保持不变。
- **refreshPermissions 未破坏**：VM:106-108 原样。

## 六、测试质量

- **TC-U-004**：✅ 断言前先读默认 `XCTAssertTrue(defaultClipboard)`（tests:133-134），确保 `XCTAssertFalse(clipboardEnabled)` 有意义（否则默认 true 会掩盖未写入的 bug）。
- **TC-U-005**：✅ 循环内每步新构造 VM + 新 InMemorySettingsService + 独立 localDidComplete（tests:152-162），零污染；断言 `allCases.count == 7`。
- **TC-U-002**：✅ 用 `== 1`（tests:103），因 continueToNextStep 单次调用只触发一次 request，精确断言合理；且前置断言 `== 0`。
- **TC-U-003**：✅ callLog 精确顺序 `[.request, .openSettings]`（tests:113-116）+ opened 校验；另有反向测试证 accessibility 不触发 request（tests:121-128）。
- **TC-U-006**：✅ 真正测 hotkey 已录入分支（persisted="option+space"，step=.searchHotkey），断言 searchHotkey 持久化该值，未 skip。
- **无测试污染**：类级 mock 每个 test 由 setUp 重建；TC-U-005 用局部实例。无共享单例注入。

## 七、MockPermissionService callLog 设计

- ✅ `enum PermissionCall: Equatable`（tests:208-211），case request(kind:) / openSettings(kind:)。
- ✅ request（:233-237）与 openSettings（:224-227）均 append callLog。
- ✅ 既有 `opened` 数组保留（:214、:225），兼容旧测试 testPermissionSettingsAndRefreshAreDelegated。
- ✅ requestScreenRecordingCallCount（private(set)）+ requestScreenRecordingResult（可配）保留自 T-001。
- 满足 T-001 review §八前瞻性建议（补 callLog 支撑 TC-U-003 严格顺序断言）。

## 八、边界与安全

- diff 仅涉及 files_touch_hint 4 文件 + progress.md，无越界。
- 未触碰 AppDelegate / PermissionService.swift / Info.plist / entitlements / build_and_run.sh（grep 确认）。
- 无 print / TODO / FIXME / dead code（diff 扫描 0 命中）。
- Skip 按钮文案走 L10n key（onboarding.skip），无 hardcoded。

## 九、xcodebuild target 归属

- ✅ 新增 5 测试方法追加到既有 `OnboardingViewModelTests.swift`（同 target 自动包含），非新建文件。
- xcodebuild 用例数 119 → 125（+6），确认新增测试随 SnapVaultTests target 编译执行。
- 与 T-001 新建独立文件未入 target 的做法不同；本任务方式使新增用例在 xcodebuild 侧也真跑，更优。

## 十、AC 追溯

- **AC-1/2/3（TCC）**：request 调用点已就位（VM:74、:101），TC-U-002 侧证进入步骤触发 request；最终 clean 构建弹窗靠 T-004 手工。
- **AC-4（Skip 7 步可见）**：footer 恒渲染，源码确认无条件分支；手工 TC-M-004 终验。单测未直接覆盖 UI 可见性（项目未用 SwiftUI 快照测试，可接受），TC-U-005 从 VM 层侧证任意步可跳。
- **AC-5（Skip 进主界面）**：TC-U-004（settings 写入 + onComplete）覆盖 + 手工 TC-M-006。
- **AC-6（重启不重弹）**：TC-U-004（onboardingCompleted=true 持久化）覆盖 + 手工 TC-M-007。
- **AC-7（按需申请）**：归 T-003，本任务不涉及。
- **AC-8（回归）**：swift test 134、xcodebuild 125，全绿。

## 十一、发现的问题

### 阻塞级
- 无。

### 非阻塞级
1. **design §4.2 差异表文档缺陷（承接 test/review.md 非阻塞建议 1）**：差异表仍写"clipboardEnabled 不写（保持默认 false）"，实为默认 true。代码已按 cases.md TC-U-004 正确显式写 false，行为无误；仅 design 文档措辞待后续顺手订正，不阻塞。
2. **AC-4 无自动化 UI 断言**：Skip 按钮 7 步可见仅靠源码 footer 结构 + 手工 TC-M-004。项目未引入 SwiftUI 快照测试，此为既有测试基建限制，可接受。

## 十二、最终结论

- **APPROVED**
- T-002 done_definition 7/7 全满足；关键红线（clipboardEnabled 显式 false）已落地。
- swift test 134/134、xcodebuild 125/125 TEST SUCCEEDED，新增测试入 target 真跑。
- 无阻塞级问题；2 条非阻塞（design 文档措辞 + UI 无快照断言），均不影响进入 Step 3。
- 可进入 T-002 测试环节（Step 3）。
