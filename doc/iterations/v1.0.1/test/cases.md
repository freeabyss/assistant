# v1.0.1 测试用例 —— 启动时 Sparkle updater 弹窗修复

- **迭代**：v1.0.1（精简 bug 修复版）
- **关联 Bug**：`doc/iterations/v1.0.1/bug.md`
- **关联 Issue**：#1
- **验收标准来源**：bug.md 第七节 AC-1 ~ AC-4
- **变更点**：`SnapVault/Services/UpdateService/UpdateService.swift` 中 `SPUStandardUpdaterController(startingUpdater: true, ...)` 改为 `startingUpdater: false`
- **说明**：本文件为本迭代自包含用例集，仅覆盖本次 bug 修复所需场景，不覆盖全局测试面。全局累积用例见 `doc/test/cases.md`（本迭代不写入、不修改，⑥ 归档时才合并）。

---

## 用例总览

| 编号 | 标题 | 关联 AC | 类型 | 执行者 |
|------|------|---------|------|--------|
| TC-U-001 | UpdateService 启动期不主动启动 Sparkle updater | AC-4（隐含 AC-1 根因） | unit | 自动化 |
| TC-U-002 | checkNow() 仍触发 GitHub Releases 跳转 | AC-2 | unit | 自动化 |
| TC-M-001 | Debug 构建启动无"无法启动更新程序"弹窗 | AC-1（Debug） | manual | 人工 |
| TC-M-002 | Release 构建启动无"无法启动更新程序"弹窗 | AC-1（Release） | manual | 人工 |
| TC-M-003 | "检查更新"点击后浏览器打开 GitHub Releases | AC-2 | manual | 人工 |
| TC-R-001 | swift test 套件全绿 | AC-3 | regression | 自动化 |
| TC-R-002 | xcodebuild test 套件全绿 | AC-3 | regression | 自动化 |

**执行顺序建议**：先跑自动化 (TC-U-001 → TC-U-002 → TC-R-001 → TC-R-002)，再做手工验收 (TC-M-001 → TC-M-002 → TC-M-003)。

---

## 一、自动化用例（放入 SnapVaultTests，可被 swift test / xcodebuild test 执行）

### TC-U-001：UpdateService 启动期不主动启动 Sparkle updater

- **编号**：TC-U-001
- **标题**：`UpdateService.setup()` 调用后，Sparkle updater 不在启动期主动 startUpdater（弹窗根因消除）
- **关联 AC**：AC-4（并覆盖 AC-1 的代码级根因；AC 隐含前置：`startingUpdater` 确实已改为 `false`）
- **类型**：unit
- **优先级**：P0
- **前置条件**：
  - v1.0.1 分支，`UpdateService.swift` 修复已应用（`startingUpdater: false`）
  - 测试目标能 `@testable import SnapVault`
- **建议放置位置**：`SnapVaultTests/UpdateServiceTests.swift`
- **依赖 mock/stub 说明**：
  - 本用例只描述**验证意图**与**成功判定**，具体断言路径由开发 subagent 挑最小侵入方案实现，三选一即可：
    - **策略 A（推荐 · 最小侵入）**：为 `UpdateService` 暴露一个可读常量/属性表达启动策略，例如 `static let startsUpdaterAutomatically = false` 或实例只读属性 `var startsUpdaterAutomatically: Bool`，并让 `setup()` 使用该常量作为 `SPUStandardUpdaterController(startingUpdater:)` 入参。断言该值为 `false`，同时（可选）用源码/反射确认 `setup()` 未硬编码 `true`。
    - **策略 B（依赖注入）**：将 `startingUpdater` 参数通过 `UpdateService` 初始化器注入（默认 `false`），断言默认实例注入值为 `false`。
    - **策略 C（delegate spy 行为验证）**：`UpdateService` 遵循 `SPUUpdaterDelegate`。构造 `UpdateService`、调用 `setup()`，在随后一段观察窗口（建议 1.0s，用 `XCTestExpectation` + 倒置期望 `isInverted = true`）内断言 `updater(_:didFinishLoading:)`、`updater(_:didAbortWithError:)`、`updaterDidNotFindUpdate(_:)` 均**未被触发**——即启动期没有跑签名校验流程。注意：此策略需要暴露一个 delegate 回调计数钩子（如注入闭包或用 `@testable` 子类覆写）以避免真实 Sparkle 弹窗。
- **测试步骤**：
  1. 构造 `UpdateService` 实例（`checkNow` 依赖用 stub，避免真实打开浏览器）
  2. 调用 `setup()`
  3. 按所选策略执行断言（A：读属性；B：读注入值；C：观察窗口内无 delegate 回调）
- **预期结果**：
  - 策略 A/B：启动策略值为 `false`
  - 策略 C：观察窗口结束时未捕获到任何 Sparkle updater 生命周期/错误回调
- **通过判定**：对应断言全部通过；测试进程内**未弹出**任何系统对话框；`swift test` / `xcodebuild test` 中该用例为 pass。

### TC-U-002：checkNow() 仍触发 GitHub Releases 跳转

- **编号**：TC-U-002
- **标题**：`UpdateService.checkNow()` 通过注入的 `UpdateCheckServiceProtocol` 打开 GitHub Releases 页
- **关联 AC**：AC-2（自动化侧证，手工侧证见 TC-M-003）
- **类型**：unit
- **优先级**：P0
- **前置条件**：
  - v1.0.1 分支
  - `UpdateService.init(updateCheckService:)` 支持注入（现状已支持，见 `UpdateService.swift:47`）
  - `WebUpdateCheckService` 支持注入 `ReleaseURLOpening`（现状已支持，见 `ReleaseInfoService.swift:127`）
- **建议放置位置**：`SnapVaultTests/UpdateServiceTests.swift`
- **依赖 mock/stub 说明**：
  - 复用现有 spy **模式**（参考 `ReleaseInfoServiceTests.swift:82` 的 `RecordingURLOpener: ReleaseURLOpening`）。注意该类型在原文件中声明为 `private`，**无法跨文件直接引用**；开发 subagent 需在 `UpdateServiceTests.swift` 内重新声明一个同等的 spy（或将其提取为 test target 内的 shared helper）：
    - 方式一：注入 spy 的 `UpdateCheckServiceProtocol`（记录 `openDownloadPage()` 是否被调用一次）到 `UpdateService.init`。
    - 方式二:构造 `WebUpdateCheckService(releasesURL:opener:)` 注入 spy opener,注入到 `UpdateService`,断言打开的 URL 等于所注入的 releasesURL（若用默认 `ReleaseLinks.releasesURL` 则为 `https://github.com/abyss/assistant/releases`）。
  - 不得触发真实 `NSWorkspace.shared.open`。
- **测试步骤**：
  1. 构造 spy opener / spy update-check service
  2. 用注入方式构造 `UpdateService`
  3. 调用 `checkNow()`
  4. 断言 spy 记录到恰好一次跳转，且目标 URL 为 releases 页
- **预期结果**：`openDownloadPage()` 被调用一次；打开 URL 为 `https://github.com/abyss/assistant/releases`
- **通过判定**：spy 断言通过（调用次数 == 1、URL 相等）；用例在 `swift test` / `xcodebuild test` 中 pass。

---

## 二、手工验收用例（Step 3 测试 subagent 通过手工步骤驱动）

### TC-M-001：Debug 构建启动无"无法启动更新程序"弹窗

- **编号**：TC-M-001
- **标题**：Debug 构建启动，3 秒观察窗口内无 Sparkle 错误弹窗
- **关联 AC**：AC-1（Debug）
- **类型**：manual
- **优先级**：P0
- **执行者角色**：人工
- **观察窗口时长**：应用主窗口/状态栏图标出现后 **3 秒**
- **前置条件**：
  - v1.0.1 分支且修复已应用
  - 已用 Debug 配置构建（`./build_and_run.sh run` 或 Xcode Debug scheme）
  - 若首启进入 onboarding 也可，弹窗判定与 onboarding 无关
- **测试步骤**：
  1. 完整退出已运行的 SnapVault.app
  2. 以 Debug 构建启动应用
  3. 从状态栏图标出现起计时,持续观察 3 秒
- **预期结果**：3 秒内不出现内容为"无法启动更新程序。请验证是否有最新版本的 Mac Super Assistant……"的系统对话框
- **通过判定**：观察窗口内**未见**该弹窗即通过；出现该弹窗（或任何 Sparkle updater 错误对话框）即失败，需截图记录。

### TC-M-002：Release 构建启动无"无法启动更新程序"弹窗

- **编号**：TC-M-002
- **标题**：Release 构建启动，3 秒观察窗口内无 Sparkle 错误弹窗
- **关联 AC**：AC-1（Release）
- **类型**：manual
- **优先级**：P0
- **执行者角色**：人工
- **观察窗口时长**：应用启动后 **3 秒**
- **前置条件**：
  - v1.0.1 分支且修复已应用
  - 已用 Release 配置构建 SnapVault.app
  - **注意**：`build_and_run.sh` 硬编码 `-configuration Debug`（脚本第 68 行），**不能**用于本 Release 用例。Release 构建请显式执行：
    `xcodebuild -project SnapVault.xcodeproj -scheme SnapVault -configuration Release -derivedDataPath ./DerivedData build`，
    产物位于 `./DerivedData/Build/Products/Release/SnapVault.app`（或用 Xcode 切到 Release scheme / `xcodebuild archive`）
- **测试步骤**：
  1. 完整退出已运行的 SnapVault.app
  2. 以上述 Release 产物路径启动应用（`open ./DerivedData/Build/Products/Release/SnapVault.app`）
  3. 从状态栏图标出现起计时,持续观察 3 秒
- **预期结果**：3 秒内不出现"无法启动更新程序"系统对话框
- **通过判定**：观察窗口内未见该弹窗即通过；出现即失败并截图。

### TC-M-003："检查更新"点击后浏览器打开 GitHub Releases

- **编号**：TC-M-003
- **标题**：Help/设置中的"检查更新"点击后浏览器打开 GitHub Releases 页
- **关联 AC**：AC-2
- **类型**：manual
- **优先级**：P0
- **执行者角色**：人工
- **观察窗口时长**：点击后 **5 秒**内
- **前置条件**：
  - v1.0.1 构建已启动并完成 onboarding（能进入设置/菜单）
  - 默认浏览器可用、有网络（或至少能观察到浏览器被拉起并尝试打开该 URL）
- **测试步骤**：
  1. 打开状态栏菜单或设置界面,找到"检查更新"入口（触发 `.checkForUpdates` 通知 → `UpdateService.checkNow()`）
  2. 点击"检查更新"
  3. 观察系统默认浏览器行为
- **预期结果**：默认浏览器被拉起并打开 `https://github.com/abyss/assistant/releases`;不出现 Sparkle 自带的更新 UI 或错误弹窗
- **通过判定**：浏览器打开的地址为项目 GitHub Releases 页即通过;若无反应、打开错误地址、或弹出 Sparkle 错误对话框则失败。

---

## 三、回归覆盖

### TC-R-001：swift test 套件全绿

- **编号**：TC-R-001
- **标题**：既有 + 新增 Swift 单元测试全部通过
- **关联 AC**：AC-3
- **类型**：regression
- **优先级**：P0
- **执行者角色**：自动化
- **前置条件**：v1.0.1 分支,TC-U-001/TC-U-002 新增用例已合入测试目标
- **测试步骤**：
  1. 项目根目录执行 `swift test`
- **预期结果**：所有用例通过,无 failure、无 error;用例总数不少于 v1.0.0 基线（**124/124**，见 `doc/iterations/v1.0.0/test/report.md`），新增 UpdateService 用例后应 ≥ 126
- **通过判定**：命令退出码为 0,输出 `Test Suite ... passed`,无 `failed` 计数;若项目未配置 SwiftPM 测试而仅走 xcodebuild,则本用例标记为 N/A 并以 TC-R-002 为准(执行者需在报告中说明)。

### TC-R-002：xcodebuild test 套件全绿

- **编号**：TC-R-002
- **标题**：Xcode 测试 target 全部通过
- **关联 AC**：AC-3
- **类型**：regression
- **优先级**：P0
- **执行者角色**：自动化
- **前置条件**：v1.0.1 分支,新增用例已加入 SnapVaultTests target
- **测试步骤**：
  1. 执行 `xcodebuild test -scheme SnapVault -destination 'platform=macOS'`（scheme/destination 以项目实际配置为准）
- **预期结果**：`** TEST SUCCEEDED **`;失败用例数为 0;用例总数保持 v1.0.0 基线（**119/119**，见 `doc/iterations/v1.0.0/test/report.md`）或更多
- **通过判定**：命令输出 `TEST SUCCEEDED` 且退出码为 0 即通过;出现 `TEST FAILED` 或任何用例 failure 即失败,需在报告中附失败用例与日志。

---

## 追溯矩阵（AC → 用例）

| AC | 描述 | 覆盖用例 |
|----|------|---------|
| AC-1 | 启动不再出现"无法启动更新程序"弹窗（Debug + Release） | TC-M-001（Debug）、TC-M-002（Release）；根因由 TC-U-001 侧证 |
| AC-2 | "检查更新"仍能打开浏览器跳转 GitHub Releases | TC-U-002、TC-M-003 |
| AC-3 | `swift test` 全绿、`xcodebuild test` 全绿 | TC-R-001、TC-R-002 |
| AC-4 | UpdateService 相关新增/回归单元测试通过 | TC-U-001（若无法直接断言则以 TC-M-001/002 手工替代）、TC-U-002 |
