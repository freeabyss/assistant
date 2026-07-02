# T-001 Code Review

- **审查时间**：2026-07-02
- **审查人**：code-review subagent
- **审查对象**：git diff HEAD -- SnapVault/ SnapVaultTests/（含新增 SnapVaultTests/UpdateServiceTests.swift）
- **审查结论**：APPROVED
- **进入 Step 3 测试**：是

## 一、done_definition 逐条核对

| # | 条目 | 状态 | 证据 |
|---|------|------|------|
| 1 | `SPUStandardUpdaterController` 的 `startingUpdater` 实参绑定到 `startsUpdaterAutomatically` 常量，值为 false | ✅ 通过 | UpdateService.swift:48 `static let startsUpdaterAutomatically: Bool = false`；:69 `startingUpdater: Self.startsUpdaterAutomatically`。全仓仅此一处 `startingUpdater`，无残留硬编码 `true`（grep 确认） |
| 2 | TC-U-002 单测通过（spy 断言 checkNow 触发 releases 跳转） | ✅ 通过 | `test_checkNow_callsUpdateCheckService_openDownloadPage_exactlyOnce` 在 `swift test` 中 passed（0 failures） |
| 3 | swift test 通过数 ≥ v1.0.0 基线 124 | ✅ 通过 | 实测 `Executed 126 tests, with 0 failures`（124 基线 + 新增 2） |
| 4 | xcodebuild test 全绿，用例数 ≥ v1.0.0 基线 119 | ✅ 通过（字面） | 实测 `Executed 119 tests, with 0 failures` + `** TEST SUCCEEDED **`（3 次运行中 2 次绿；见第五节关于首次冷启动 flaky 的说明）。注意：新增用例未进 Xcode target，故仍为 119=基线，见第二节 |
| 5 | 未改动 Info.plist / entitlements / appcast.xml / CFBundleShortVersionString | ✅ 通过 | `git diff HEAD --stat` 对上述文件为空，无任何改动 |
| 6 | diff 仅涉及 files_touch_hint 内文件 | ✅ 通过（代码层） | `git status` 中 SnapVault/ 与 SnapVaultTests/ 下仅 `UpdateService.swift`、`UpdateServiceTests.swift` 变更。README.md/PRIVACY.md/zh-CN 的改动在会话开始前的 gitStatus 中已存在（与 T-001 无关，属既有翻译改动，提醒收尾 commit 不要误纳入 T-001） |

**结论**：6 条 done_definition 全部满足。

## 二、xcodebuild target 归属问题判定

**判定：APPROVED（作为 P2 遗留，不阻塞进入测试）。**

理由：
- 字面 done_definition 第 4 条为 "xcodebuild test 全绿、用例数 ≥ 119"，实测 119 绿且 `TEST SUCCEEDED`，字面满足。
- 两条新用例的语义与平台/构建方式无关：TC-U-001 断言的是 `static let startsUpdaterAutomatically`（同一份源码在 SPM 与 Xcode 两 target 下编译结果完全一致），TC-U-002 断言的是纯依赖注入逻辑（`checkNow()` 同步调用注入 spy）。这两者不存在 SPM/Xcode 行为分叉，因此 `swift test`（126 绿）已构成对这两条断言的**真实、充分**覆盖，AC-3/AC-4 有实证。
- 盲区评估：Xcode 侧测试 runner 永不执行这两条断言，从 IDE 跑测试的人看不到它们——这是真实盲区，但**严重度低**：被测行为在两 target 完全同构，`swift test` 已守住回归；且实际发布的 SnapVault.app 的运行时行为由源码（已改 `false`）决定，而非由"哪个 target 跑了测试"决定。手工用例 TC-M-001/002（Xcode 构建产物启动）会从用户侧兜住 AC-1 根因。
- 处置：记为 P2 遗留——建议本迭代收尾（或下一 patch）派一个专门 subagent 编辑 `SnapVault.xcodeproj/project.pbxproj`，将 `UpdateServiceTests.swift` 加入 SnapVaultTests target（参考 `ReleaseInfoServiceTests` 在 pbxproj 中的 4 处显式引用），使 xcodebuild 计数升至 121 并实跑这两条断言。开发未擅自改 pbxproj（超出 files_touch_hint）是正确的边界克制。

## 三、代码质量

- **策略 A 常量声明**：符合 review.md 指导。`static let`（不可变契约，非 `var`、外部不可改），符合 tasks.json step "禁止把常量声明为 var 或让外部可修改"。
- **注释质量**：优秀。注释解释了"为什么 false"（MVP 走 checkNow 跳转，不依赖 Sparkle 自动流程 + SUPublicEDKey 未配置会弹窗）、"什么时候改回 true"（生成 EdDSA 密钥并补齐 appcast 签名后），并**显式引用了 Issue #1**，便于未来考古。
- **常量绑定路径**：`SPUStandardUpdaterController(startingUpdater: Self.startsUpdaterAutomatically, ...)` 是唯一入参；grep 全仓 `startingUpdater` 仅此一处，别处无硬编码 `true`。
- **init 签名未变**：`init(updateCheckService: UpdateCheckServiceProtocol = WebUpdateCheckService())` 保留，符合 step 2 与 TC-U-002 注入前置。

## 四、测试质量

- **TC-U-001**：只断言静态常量 `UpdateService.startsUpdaterAutomatically == false`，不构造 controller、不触碰真实 Sparkle，无弹窗风险。断言 message 引用 Issue #1，可读性好。（未做可选的 setup() 反射校验，但 done_definition 未强制，且第一节已用 grep 确认实参绑定，可接受。）
- **TC-U-002 spy `RecordingUpdateCheckService`**：
  - 声明为 `private final class`——不污染 test target 全局命名空间。✅
  - 完整实现 `UpdateCheckServiceProtocol`（该协议仅 `openDownloadPage()` 一个方法，见 ReleaseInfoService.swift:32-34），无 `fatalError` 桩。✅
  - 记录方式安全：实例级 `private(set) var openDownloadPageCallCount`，非全局可变状态。✅
- **不触发真实 NSWorkspace.open**：`checkNow()` → `updateCheckService.openDownloadPage()`，注入 spy 后完全拦截在最外层，spy 实现内不调用 NSWorkspace，路径确认安全。选方式一（注入 protocol spy）而非方式二（注入 opener）合理，侵入最小。
- **async/expectation**：`checkNow()` 与 `openDownloadPage()` 均为同步方法，无需 `XCTestExpectation`，同步断言正确。
- **测试污染**：每条用例 `let service = UpdateService(updateCheckService: spy)` 新建实例，未污染单例，无跨用例状态残留。✅
- **URL 断言范围**：本用例只断言"恰好一次调用"（callCount==1），未断言具体 URL 字符串。cases.md 修订版把判定放宽为"所注入的 releasesURL"，方式一下 spy 不持有 URL，断言次数符合评审放宽后的判定，可接受；若想更强可补方式二断言 URL，属非阻塞增强。

## 五、边界与安全

- 未改动 delegate 方法、feedURL 逻辑、Sparkle 版本；diff 仅新增常量 + 替换一个实参。✅
- **`false` 时 controller 仍构造**：`setup()` 仍 `SPUStandardUpdaterController(startingUpdater: false, ...)`，符合 bug.md 五节预期——controller 惰性初始化、不在启动期执行签名校验，弹窗根因消除，`canCheckForUpdates` KVO 绑定仍工作。符合 Sparkle 2 文档（`startingUpdater: false` 表示不自动 startUpdater，调用方后续可手动 start）。
- **`updater.checkForUpdates()` 调用点**：`UpdateService.checkForUpdates()`（async，:103）仍调用真实 Sparkle updater。但排查调用链——UI 侧 `.checkForUpdates` 通知 → AppDelegate:899 `handleCheckForUpdates()` → **`updateService.checkNow()`**（走 GitHub 跳转），**没有任何 UI/生产路径调用 `updateService.checkForUpdates()`**（grep 确认仅协议声明与自身实现，无外部调用者）。故 `startingUpdater: false` 下不会有别处触发 Sparkle 启动签名校验，无副作用。
- **未来误改捕获**：若将来有人把 `checkNow()` 误改为调 Sparkle updater，TC-U-002 会失败（spy callCount 变 0），能捕获——测试设计有前瞻性。

## 六、文档更新

- **progress.md**：已按要求追加 T-001 记录，含变更点、策略 A + spy 方式一选型理由、以及 xcodebuild target 归属注记（诚实说明 119=基线未回归、未改 pbxproj 的原因）。记录数字 126/126、119/119 与本次实测一致。✅
- **doc/iterations/v1.0.1/README.md**：已新增一行 "2026-07-02 T-001 开发完成（swift test 126/126；xcodebuild 119/119 TEST SUCCEEDED），待 code review"，数字属实。✅
- 顶层 README.md/PRIVACY.md 的 zh-CN 链接改动属会话前既有改动，与 T-001 无关（见第一节 #6 说明）。

## 七、发现的问题

### 阻塞级（必须修订才能进入测试环节）
- 无。

### 非阻塞（建议改，可留）
- **[P2] xcodebuild target 归属**：`UpdateServiceTests.swift` 未加入 SnapVaultTests target（pbxproj 显式引用，grep 该文件名 0 匹配），xcodebuild 侧不实跑这两条新断言。建议收尾/下一 patch 派专门 subagent 编辑 pbxproj 补入。理由见第二节。
- **[P3] xcodebuild 冷启动 flaky**：本次首次运行出现 `Executed 46 tests` + `TEST FAILED`，紧接两次运行均 `Executed 119 tests` + `TEST SUCCEEDED`。失败伴随 `com.apple.linkd.autoShortcut` XPC 连接错误，属测试宿主冷启动环境抖动，与本次代码改动无关（新用例根本不在该 target）。建议 T-002 手工/回归执行时对 xcodebuild 首次结果做一次重跑确认。
- **[P3] 收尾 commit 边界提醒**：git 工作区含 README.md/PRIVACY.md/PRIVACY.zh-CN.md/README.zh-CN.md 等与 T-001 无关的既有改动，收尾 commit 时应只纳入 `UpdateService.swift`、`UpdateServiceTests.swift`、`progress.md`、`doc/iterations/v1.0.1/README.md`，勿误提交翻译改动。
- **[P3] TC-U-002 增强（可选）**：当前只断言调用次数，未断言目标 URL；若想强化可补方式二注入 opener 断言 URL == `https://github.com/abyss/assistant/releases`。cases.md 评审已放宽判定，不做也合规。

## 八、最终结论

- 结论：**APPROVED**
- 可以进入 T-002 手工验收。
- xcodebuild target 归属判定：**APPROVED（留 P2）**——字面 done_definition 满足（≥119 且 TEST SUCCEEDED），两条新用例语义与构建方式无分叉、已由 `swift test`(126) 实证覆盖，Xcode 侧盲区严重度低且有手工用例 TC-M-001/002 兜底 AC-1；pbxproj 补入作为 P2 遗留交后续 subagent。
