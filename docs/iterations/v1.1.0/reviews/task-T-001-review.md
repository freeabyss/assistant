# T-001 Code Review

- **审查时间**：2026-07-02
- **审查人**：code-review subagent
- **审查对象**：`git diff HEAD -- SnapVault/ SnapVaultTests/`（含未跟踪新建文件 `SnapVaultTests/PermissionServiceProtocolConformanceTests.swift`）
- **审查结论**：APPROVED（可带 P2 遗留进入下一环）
- **进入 Step 3 测试环节**：是

## 一、done_definition 逐条核对

| # | 条目 | 状态 | 证据 |
|---|------|------|------|
| 1 | 协议有 `requestScreenRecordingPrompt()` 声明，无默认实现 | ✅ PASS | `PermissionService.swift:30-31` 声明；`grep -rn "extension PermissionServiceProtocol"` 全仓 0 命中 → 无 protocol extension 默认实现，编译期强制 conformer |
| 2 | 三 conformer 均实现该方法 | ✅ PASS | PermissionService `:66-69`；MockPermissionService `OnboardingViewModelTests.swift:133-136`；StaticPermissionService `SettingsSourceTests.swift:191` |
| 3 | Mock 提供 spy 基础设施（callCount + 可配返回值） | ✅ PASS | `requestScreenRecordingResult: Bool = false`（:118）+ `private(set) var requestScreenRecordingCallCount: Int = 0`（:119），方法自增计数并返回配置值（:133-136） |
| 4 | TC-U-001 单元测试通过 | ✅ PASS | `swift test` 输出 `PermissionServiceProtocolConformanceTests` 2 用例全 passed |
| 5 | swift test 全绿且用例数 ≥ 127 | ✅ PASS | `Executed 128 tests, with 0 failures`（基线 126 +2）|
| 6 | 未改动 View / VM / AppDelegate | ✅ PASS | `git diff HEAD --name-only -- SnapVault/ViewModels/* SnapVault/Views/* SnapVault/App/*` = NONE。仅改 PermissionService.swift + 2 测试文件 + 1 新建测试文件 |

**结论：6/6 全部满足。**

## 二、协议契约
- **@MainActor**：协议方法声明为 `@MainActor func requestScreenRecordingPrompt() -> Bool`（:30-31），满足 design §八主线程约束，编译期即强制主线程调用。合格。
- **无默认实现**：确认全仓无 `extension PermissionServiceProtocol`，符合评审 §三阻塞级要求（编译期强制所有 conformer 实现），缺任一实现即编译失败（AC-8 兜底成立）。合格。
- **doc comment**：清晰，标注返回值语义（当前是否已授权）、副作用（首次弹 UI）、主线程要求，并引用 Issue #3 与 architecture §4.1（:27-29）。合格。
- **与既有风格对称**：`requestAccessibilityPromptIfNeeded` 是 private 无返回值的内部辅助，而新方法是协议方法带 Bool 返回值——因需求不同（一个进协议供注入 spy，一个是内部实现细节），非严格对称，但符合 design §五契约表设计。可接受。

## 三、真实实现（PermissionService）
- `requestScreenRecordingPrompt()` 直接 `return CGRequestScreenCaptureAccess()`（:67-68），无吞异常、无多余包装、无副作用扩散。合格。
- `import CoreGraphics` 已在文件头 `:3` 就位（既有，非本次新增，progress.md 已注明）。合格。
- `status(for:)` 的 preflight 逻辑保持不变（:43-50），未被误改。合格。

## 四、Mock spy 质量
- `requestScreenRecordingResult` 公开可配（默认 false，对齐 design §五样例）；`requestScreenRecordingCallCount` 为 `private(set)`——外部只读、内部可写，封装正确。合格。
- **线程安全**：无锁保护，但单测在 @MainActor 串行上下文中运行，非并发访问；且真实使用场景（VM/AppDelegate）均 @MainActor。无实际隐患。合格。
- **可见性提升（private → internal）**：MockPermissionService 与 StaticPermissionService 由 `private` 提升为 `internal`（去 private），使 TC-U-001 跨文件引用。检查确认无其它测试依赖其 private 性（两类均为 test-only 辅助类），提升不破坏既有封装或用例。合格。
- **StaticPermissionService 返回固定 true**：`SettingsSourceTests` 不涉及权限申请逻辑，返回 true 不干扰 settings 用例（128 全绿佐证）。合格。

## 五、新测试文件质量
- 位置合理：`SnapVaultTests/PermissionServiceProtocolConformanceTests.swift`（tasks.json step 5 指定路径）。
- `@MainActor` 类级注解（:4），保护对 @MainActor 协议方法的调用。合格。
- 断言精确：mock 断言 `XCTAssertTrue(result)` + `XCTAssertEqual(callCount, 1)`（:16-17）；static 断言 `XCTAssertTrue(...)`（:22）。合格。
- 无测试污染：两个测试各自 new 实例，不触碰单例或共享状态。合格。
- 意图注释清晰（:7-10）：明确 mock 走 spy 路径、static 走 stub 路径、真实 PermissionService 不测（会真弹 UI），并引用 review.md 阻塞级发现。合格。

## 六、Xcode target 归属判定
- 新建 `PermissionServiceProtocolConformanceTests.swift` 未加入 Xcode SnapVaultTests target（progress.md 已记录：xcodebuild 用例数保持 119，SPM 侧 128 已含）。
- **判定：APPROVED（P2 遗留，与 v1.0.1 处理一致）**。理由：SPM `swift test` 已覆盖该文件（128 全绿），手改 pbxproj 引入破坏风险高于收益；v1.0.1 已将同类问题定为 P2 遗留，本迭代保持一致。TC-R-002 用例本身已标注"未入则保持 119"为可接受。

## 七、边界与安全
- diff 仅涉及 `files_touch_hint` 列出的三文件 + 允许的新建测试文件 + progress.md（未跟踪）。无越界修改。
- 无 dead code、无 TODO、无 print 遗留。
- 无 hardcoded 应本地化字符串（TC-U-001 不涉及 UI 文案，符合预期）。
- `git diff --stat`：PermissionService.swift +11 / OnboardingViewModelTests.swift +10-1 / SettingsSourceTests.swift +3-1，改动量与任务范围吻合。

## 八、前瞻性（对 T-002/T-003 的接口稳定性）
- **TC-U-002（call count）**：`requestScreenRecordingCallCount` 已就绪，T-002 可直接断言从 0→1，接口充足。
- **TC-U-003（顺序断言）**：当前 Mock **未**提供 `callLog: [String]` 数组。progress.md 开发注记称"顺序断言可用现有 `opened` + `callCount` 实现"。
  - 评审判断：此策略**部分可行但不够严格**。`opened` 只记录 `openSystemSettings` 调用，`callCount` 只记录 request 次数，二者无法可靠表达"request 先于 openSettings"的**时序**（只能证明两者都发生、各发生几次）。cases.md TC-U-003 的通过判定明确要求 `callLog == ["request", "openSettings"]`（顺序数组）。
  - **前瞻结论：T-002 开发时需在 MockPermissionService 补一条 `callLog: [String]`**，在 `requestScreenRecordingPrompt` 追加 `"request"`、在 `openSystemSettings` 追加 `"openSettings"`（test/review.md §二 TC-U-007 意见亦已提示此点）。这属 T-002 的正常实现范围，**不构成 T-001 的阻塞**（T-001 done_definition 未要求 callLog，TC-U-003 归 T-002）。
- **StaticPermissionService 返回 true 是否误导其它测试**：不会。SettingsSourceTests 不触发权限申请分支，返回 true 无影响。

## 九、发现的问题

### 阻塞级
- 无。

### 非阻塞级
1. **Mock 缺 `callLog`（T-002 需补）**：当前 spy 不足以支撑 TC-U-003 的严格顺序断言，T-002 开发须补 `callLog: [String]`。已在 §八说明，属 T-002 范围，不阻塞 T-001。
2. **新测试文件未入 Xcode target（P2 遗留）**：与 v1.0.1 一致处理，不阻塞。
3. **design §4.2 差异表已知缺陷（clipboardEnabled 默认值）**：与 T-001 无关（属 T-002 skipOnboarding），test/review.md 已修订 TC-U-004，此处仅记录，T-002 时以 cases.md 为准。

## 十、最终结论
- **APPROVED**
- T-001 done_definition 6 条全满足，无阻塞级问题，swift test 128/128 全绿。
- 唯一前瞻性提醒：T-002 实现 TC-U-003 时须为 MockPermissionService 补 `callLog` 时序数组（现有 `opened`+`callCount` 不足以做严格顺序断言）。此为 T-002 范围，不打回 T-001。
- 可进入 T-001 测试环节（Step 3）。
