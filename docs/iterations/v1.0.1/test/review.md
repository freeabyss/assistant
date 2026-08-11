# v1.0.1 测试用例评审记录

- **评审时间**：2026-07-02
- **评审对象**：doc/iterations/v1.0.1/test/cases.md
- **评审人**：test-review subagent
- **评审结论**：APPROVED_WITH_MINOR_FIXES（评审中已直接修订 cases.md，修订后可进入 Gate 3）

## 一、AC 覆盖完整性

**结论：完整。** AC-1~AC-4 每条均被至少一个 TC 覆盖，追溯矩阵核对无误。

| AC | 描述 | 覆盖用例 | 核对结果 |
|----|------|---------|---------|
| AC-1 | 启动不再出现"无法启动更新程序"弹窗（Debug + Release） | TC-M-001（Debug）、TC-M-002（Release），TC-U-001 侧证根因 | ✅ Debug/Release 各有独立用例，符合"各验证一次" |
| AC-2 | "检查更新"仍能打开浏览器跳转 GitHub Releases | TC-U-002（自动化）、TC-M-003（手工） | ✅ 自动化 + 手工双覆盖 |
| AC-3 | swift test 全绿、xcodebuild test 全绿 | TC-R-001、TC-R-002 | ✅ 两条命令各一用例 |
| AC-4 | UpdateService 相关新增/回归单元测试通过 | TC-U-001、TC-U-002 | ✅ 且提供了"无法直接断言则以手工替代"退路，与 bug.md AC-4 措辞一致 |

矩阵与用例总览表一致，无遗漏 AC、无孤立 TC。

## 二、按用例逐条评审

### TC-U-001
- 结论：通过（修订后）
- 意见：验证意图正确——用"启动期不主动 startUpdater"侧证 AC-1 根因。三选一策略均在项目现有框架（XCTest + `@testable import SnapVault`）下可行：
  - 策略 A（可读常量）：最小侵入，需开发在 `setup()` 中把硬编码 `startingUpdater: true` 抽为常量，实现成本低，推荐。
  - 策略 B（构造器注入）：可行，`UpdateService.init` 已有注入先例（`updateCheckService`），加一个默认 `false` 参数即可。
  - 策略 C（delegate spy 倒置期望）：可行但成本最高，且需暴露回调计数钩子；作为兜底可接受。
- 说明：UpdateService 已随 SnapVault target 编译进 SwiftPM（Package.swift 未 exclude 该文件，Sparkle 是正式依赖），故 `swift test` 与 `xcodebuild test` 均能执行本用例。
- 建议修订：无（保留三选一开放式描述，交开发 subagent 决策，合理）。

### TC-U-002
- 结论：通过（已修订）
- 意见：注入路径成立——`UpdateService.init(updateCheckService:)`（UpdateService.swift:47）与 `WebUpdateCheckService(releasesURL:opener:)`（ReleaseInfoService.swift:127）均已支持注入，`ReleaseURLOpening` 协议存在，spy 模式可复用。
- 建议修订（已执行）：原文写"复用 `RecordingURLOpener`"存在事实性缺陷——该类型在 `ReleaseInfoServiceTests.swift:82` 声明为 `private`，**无法跨文件引用**。已改为"复用 spy 模式，需在 UpdateServiceTests 内重新声明同等 spy 或提取为 shared helper"，并把"URL 等于 `ReleaseLinks.releasesURL`"的判定放宽为"等于所注入的 releasesURL"，避免与方式二自定义 URL 冲突。

### TC-M-001
- 结论：通过
- 意见：Debug 路径明确（`build_and_run.sh run`），3 秒观察窗口对"启动后 0.5-1 秒弹窗"的诊断结论有足够裕量（覆盖 3-6 倍时延）。判定明确（见/未见指定文案弹窗），要求失败截图，可执行。

### TC-M-002
- 结论：通过（已修订）
- 意见：3 秒窗口同样充分。
- 建议修订（已执行）：原文"以 Release 构建启动"未给出 Release 构建方法，而 `build_and_run.sh` 硬编码 `-configuration Debug`（脚本第 68 行），非项目开发者照做会误用 Debug 产物。已补明确的 `xcodebuild -configuration Release` 命令与产物路径（`./DerivedData/Build/Products/Release/SnapVault.app`），并注明脚本不可用于本用例。

### TC-M-003
- 结论：通过
- 意见：入口链路核对无误——`.checkForUpdates` 通知（MenuBarView.swift:8）→ AppDelegate.swift:901 `updateService.checkNow()` → `WebUpdateCheckService.openDownloadPage()`。目标 URL 与 `ReleaseLinks.releasesURL` 一致。5 秒窗口合理，判定明确。

### TC-R-001
- 结论：通过（已修订）
- 意见：回归门槛合理。
- 建议修订（已执行）：补上 v1.0.0 基线数字 **124/124**（来源 `doc/iterations/v1.0.0/test/report.md`），并明确新增用例后应 ≥ 126，使"不少于基线"可量化判定。

### TC-R-002
- 结论：通过（已修订）
- 意见：判定标准清晰（`** TEST SUCCEEDED **` + 退出码 0）。
- 建议修订（已执行）：补上 v1.0.0 基线数字 **119/119**（xcodebuild target 与 SwiftPM 数量不同，属正常，因 Package.swift exclude 了部分文件、两套 target 用例集不同）。

## 三、发现的问题（按严重度）

### 阻塞级（必须修订才能进入任务拆解）
- 无。（原 TC-U-002 的 `RecordingURLOpener` 复用缺陷若不修会导致开发按错误假设编码、编译失败，评审中已直接修订，故降级为已解决。）

### 建议级（可以改也可以留）
- TC-U-001 策略 A 若被采纳，需开发同步微调 `setup()` 让 controller 入参引用该常量，否则"读常量为 false"无法真正约束 `SPUStandardUpdaterController(startingUpdater:)` 的实参——建议在任务拆解时把"常量与实参绑定"写进 done_definition。
- 遗留项边界核对：cases.md 全篇未出现 L-1~L-5，未把 SUPublicEDKey / entitlements / appcast 签名等遗留项当作本迭代验收范围，边界正确，无需修订。
- 测试独立性核对：TC-U-001（观察窗口/常量断言）、TC-U-002（spy opener）均不触网、不连真实 Sparkle 服务器、不调真实 `NSWorkspace.open`，独立性达标。
- bug.md 观察：AC-4 允许"若无法直接断言则以 AC-1 手工验收替代"，措辞偏宽松，可能被解读为"允许跳过单元测试"。**此为 bug.md 措辞问题，不阻塞用例评审通过**；cases.md 已通过 TC-U-001 提供三条可落地的直接断言路径，实际上不需要走替代分支，建议开发优先落地 TC-U-001 而非直接用手工替代。

## 四、修订记录

评审中直接修订 cases.md 共 4 处：

1. **TC-M-002 前置条件 + 测试步骤**（原 L113-121）：补 Release 构建命令与产物路径，注明 `build_and_run.sh` 硬编码 Debug 不可用于本用例。原因：Release 构建路径缺失，非开发者无法照做，且脚本会误导为 Debug。
2. **TC-U-002 依赖 mock/stub 说明**（原 L67-71）：把"复用 `RecordingURLOpener`"改为"复用 spy 模式并需在本测试文件内重新声明"，判定 URL 由固定 `ReleaseLinks.releasesURL` 放宽为"所注入的 releasesURL"。原因：`RecordingURLOpener` 为 `private`，跨文件不可引用，原描述会导致编译失败。
3. **TC-R-001 预期结果**（原 L157）：补 v1.0.0 基线 124/124 及来源，量化为"≥ 126"。原因：回归门槛缺少可量化基线。
4. **TC-R-002 预期结果**（原 L171）：补 v1.0.0 基线 119/119 及来源。原因：同上。

## 五、最终结论

- 状态：APPROVED_WITH_MINOR_FIXES
- 是否可进入 Gate 3 任务拆解：**是**（修订已在评审中直接落地，cases.md 现处于可执行状态）
- 需要后续 subagent 注意：
  - 任务拆解时把 TC-U-001 的"启动策略常量与 `SPUStandardUpdaterController(startingUpdater:)` 实参绑定"写入 done_definition。
  - TC-U-002 需在 `UpdateServiceTests.swift` 内新建 spy（不要试图 import 现有 private 类型）。
  - TC-M-002 按修订后的 Release 构建命令执行。
