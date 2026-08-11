# v1.1.0 架构设计 —— Onboarding 死锁修复：屏幕录制权限申请 + 跳过向导

> 本迭代目标输出文件。`doc/architecture/design.md`（全局累积版）仅作背景参考，本文件不写入/不覆写它。
> 架构变更为**局部性**：仅涉及 `PermissionService`、`OnboardingViewModel`、`OnboardingView`、以及 `AppDelegate` 现有的按需申请路径。不重设计整体应用架构。
> 关联：PRD `doc/iterations/v1.1.0/prd.md`（US-1/US-2、P-1.1~1.3、P-2.1~2.5、AC-1~8）· Issue #3 · 分支 v1.1.0 · 模式 auto

---

## 一、术语澄清

（引用 PRD 术语，不重定义）

- **权限申请 (permission request)**：调用触发 TCC 弹窗的 API，如 `CGRequestScreenCaptureAccess()`（首次调用会弹系统 UI 并把 App 注册进 TCC 数据库/设置候选列表）。
- **权限预检 (permission preflight)**：只读检查权限状态，不弹窗，如 `CGPreflightScreenCaptureAccess()`。当前 `PermissionService.status(for:.screenRecording)` 走此路径（`PermissionService.swift:40`）。
- **跳过 (skip)**：用户主动放弃 onboarding 剩余步骤，写入 `onboardingCompleted=true`，但**不强制授权**任何权限。
- **按需申请 (on-demand request)**：跳过后，首次使用需要该权限的功能时触发权限申请弹窗。
- **onboarding 完成 (completion)**：无论走完 7 步（`completeIfPossible`）还是跳过（`skipOnboarding`），都写入同一持久化 flag `SettingKey.onboardingCompleted=true`。

---

## 二、影响范围与不影响范围

### 影响的模块
- `PermissionServiceProtocol` / `PermissionService`（`SnapVault/Services/Permissions/PermissionService.swift`）—— 新增 `requestScreenRecordingPrompt() -> Bool`。
- `OnboardingViewModel`（`SnapVault/ViewModels/OnboardingViewModel.swift`）—— 进入 `.screenRecording` 前触发 request；新增 `skipOnboarding()`。
- `OnboardingView`（`SnapVault/Views/Onboarding/OnboardingView.swift`）—— footer 增加 "Skip Setup" 按钮 + 确认 `.alert`。
- `AppDelegate.ensureScreenRecordingPermission()`（`SnapVault/App/AppDelegate.swift:766-783`）—— 现有 NSAlert 按需申请路径，需在打开系统设置前补一次 request（修复对称 TCC bug，满足 AC-7 "复用同一 request 逻辑"）。
- **协议所有实现方**（新增方法会破坏所有 conformer，缺一即编译失败 → 波及 AC-8）：
  - `MockPermissionService`（`SnapVaultTests/OnboardingViewModelTests.swift:114`）—— 补齐新方法 + spy 计数/可控返回值。
  - `StaticPermissionService`（`SnapVaultTests/SettingsSourceTests.swift:187`）—— 补齐新方法（返回固定 `true` 即可，无需 spy）。
- `SettingsViewModel`（`SnapVault/ViewModels/SettingsViewModel.swift:213`）—— 设置面板"权限"页也走 `openSystemSettings`，是 AC-7 声明的"设置面板"申请入口之一；本迭代**不强制**改造它触发 request（见评审 §五判定），但需知悉它同样存在 TCC 对称缺口。
- `Localizable.xcstrings`（单一 String Catalog，en + zh-Hans 同文件）—— 新增 skip 相关文案键。

### 不影响的模块
- Sparkle updater（上一迭代刚修，本迭代不动）。
- 剪贴板核心逻辑（本迭代只影响首启 skip 时 `clipboardEnabled` 的默认取值，不改监听/存储链路）。
- 数据持久化层（Core Data schema 不动，仅复用现有 `SettingKey.onboardingCompleted`；不新增字段）。
- 网络 / 更新流程 / 搜索链路。

---

## 三、架构方案对比

### 方案 A：最小侵入（推荐）
- `PermissionService` 增加 `requestScreenRecordingPrompt() -> Bool`，内部调 `CGRequestScreenCaptureAccess()`；`status(for:)` 保留 preflight 不变。
- `OnboardingViewModel` 在进入 `.screenRecording` 时先调 request；`openPermissionSettings(.screenRecording)` 打开设置前也先调一次 request（防止用户绕过 continue 直接点"打开设置"）。新增 `skipOnboarding()` 只写 `onboardingCompleted=true` 并回调 `onComplete()`。
- `OnboardingView` footer 左下角加 Skip 按钮 + SwiftUI `.alert` 二次确认。
- 按需申请：**复用 `AppDelegate` 已存在的 `ensureScreenRecordingPermission()`**（当前已是 NSAlert 弹窗），只需在其 `openSystemSettings` 前补一次 `requestScreenRecordingPrompt()`。
- **优点**：改动局部、可测、与既有 accessibility 权限流程对称（`AXIsProcessTrustedWithOptions` 已在 `PermissionService.swift:60-63`）、不引入新抽象、复用现存按需申请入口。
- **缺点**：`AppDelegate.ensureScreenRecordingPermission()` 目前直接 `PermissionService()` new 实例（非注入），此路径的单测覆盖有限，主要靠手工验收。

### 方案 B：抽出 `PermissionOrchestrator` 中间层
统一编排所有权限的 request / 延后申请策略，记录"哪些权限被延后"。
- **优点**：未来扩展新权限（相机、麦克风）时集中管理；延后申请语义显式化。
- **缺点**：本迭代改动放大，超出 PRD 范围（PRD 第六节明确"记录延后权限为可选优化，非本迭代硬需求"）。过度设计。

### 方案 C：Onboarding 状态机重构为 DAG
把 `OnboardingStep` 从硬串行改成 DAG，每步声明 required/optional/skippable。
- **优点**：跳过语义显式化，未来增删步骤成本低。
- **缺点**：改动巨大、风险高，与本迭代"解死锁 + 加跳过按钮"的收益严重不匹配。

### 推荐：方案 A
理由：改动最小且集中在四个已知触点；与既有 accessibility 权限触发逻辑对称，便于对齐审查；不引入新的抽象层或状态机，回归风险低；按需申请复用 `AppDelegate` 现有 NSAlert 入口，无需新增 UI 编排。方案 B/C 的扩展性收益在本迭代无兑现场景，留待后续权限扩展迭代评估。

---

## 四、详细设计（方案 A）

### 4.1 PermissionService 变更

```swift
protocol PermissionServiceProtocol {
    // 已有：
    func status(for permission: PermissionKind) -> PermissionStatus      // preflight，只读
    func openSystemSettings(for permission: PermissionKind)              // 打开系统设置 URL
    func refreshStatuses() async -> [PermissionKind: PermissionStatus]
    // 新增（本迭代）：
    func requestScreenRecordingPrompt() -> Bool                          // 触发 TCC 注册 + 系统弹窗
}
```

实现要点：
- `requestScreenRecordingPrompt()` 调 `CGRequestScreenCaptureAccess()`（CoreGraphics，同步返回 `Bool`）：首次调用会弹系统权限 UI 并把 App 注册进 TCC 候选列表；返回值 = 当前是否已授权。这正是 P-1.1 修复死锁的关键 API。
- `status(for:.screenRecording)` 继续走 `CGPreflightScreenCaptureAccess()`（不弹窗），用于快速判断按钮 enable 状态与 `canContinueCurrentStep`。
- 与 accessibility 现状对称：accessibility 用 `AXIsProcessTrustedWithOptions(prompt:true)` 触发注册，screenRecording 之前缺了对称 request，本迭代补齐。

### 4.2 OnboardingViewModel 变更

- `continueToNextStep()` 中，`.clipboardPrivacy → .screenRecording` 分支（当前 `OnboardingViewModel.swift:69-72` 只 `refreshPermissions()`）在进入 `.screenRecording` 后追加一次 `permissionService.requestScreenRecordingPrompt()`：
  - 返回 `true`：直接可继续（P-1.2）；后续 `refreshPermissions()` 预检也为 authorized。
  - 返回 `false`：保持在 `.screenRecording` 步骤，用户去系统设置授权后回来点 recheck / Continue，此时 preflight = true，`canContinueCurrentStep` 放行（P-1.3）。
- `openPermissionSettings(_ kind:)`（`OnboardingViewModel.swift:95-97`）在 `kind == .screenRecording` 时，先调 `requestScreenRecordingPrompt()` 再 `openSystemSettings`（防止用户绕过 `continueToNextStep` 直接点"打开设置"仍触发注册）。
- 新增 `skipOnboarding()`：
  ```
  func skipOnboarding() async {
      // 1. hotkey：若已录入有效值则持久化，否则保持默认 option+space（persistCurrentShortcutString 已含默认逻辑）
      // 2. settingsService.set(true, for: .onboardingCompleted)
      // 3. settingsService.set(hotkeyService.persistCurrentShortcutString(), for: .searchHotkey)
      // 4. 不写 clipboardEnabled（保持默认 false / 已有值，决策见 PRD 关键决策）
      // 5. 不强制 launchAtLogin、不强制任何权限
      // 6. onComplete()  → 触发 AppDelegate.startFullExperienceServices()
  }
  ```
- 与 `completeIfPossible()`（`OnboardingViewModel.swift:103-130`）的差异：

  | 项 | completeIfPossible（正常完成） | skipOnboarding（跳过） |
  |----|-------------------------------|------------------------|
  | 前置校验 | `isCompleteReady`（4 项全绿）| 无，任意步骤可跳 |
  | onboardingCompleted | true | true |
  | clipboardEnabled | 强制 true | **不写**（保持默认 false / 已有值）|
  | searchHotkey | 持久化 | 持久化（默认 option+space）|
  | launchAtLoginEnabled | 写用户选择值 + 注册 | **不强制**（保持默认）|
  | 权限 | 必须已授 | 延后按需申请 |

### 4.3 OnboardingView 变更

- Footer HStack（`OnboardingView.swift:100-111`）左侧在 `Quit` 旁增加：
  ```swift
  Button(L10n.localized("onboarding.skip")) { showSkipConfirmation = true }
  ```
  位置：左下角（远离右下角主 CTA Continue，避免误触）。7 步全局可见（footer 与 step 无关，天然满足 AC-4）。
- `@State private var showSkipConfirmation = false`
- 确认 Alert：
  ```swift
  .alert(L10n.localized("onboarding.skip.confirm.title"), isPresented: $showSkipConfirmation) {
      Button(L10n.localized("onboarding.skip.confirm.action"), role: .destructive) {
          Task { await viewModel.skipOnboarding() }
      }
      Button(L10n.localized("onboarding.skip.confirm.cancel"), role: .cancel) {}
  } message: {
      Text(L10n.localized("onboarding.skip.confirm.message"))
  }
  ```

### 4.4 主界面按需申请路径

现状：`AppDelegate.ensureScreenRecordingPermission()`（`AppDelegate.swift:766-783`）已在每个截图入口（`performRegionCapture` / `performWindowCapture` / `performScreenCapture`）前守卫，未授权时弹 `NSAlert` 引导去系统设置。**但它当前与 onboarding 有同一 TCC bug：打开设置前从未调用 request API**，App 可能不在设置列表中。

方案对比：
- **方式 A（AppState banner）**：全局 AppState 暴露 `permissionRequestBanner` 状态，SwiftUI 订阅显示。UI/服务解耦、更可测。
- **方式 B（NSAlert 直接弹）**：由 AppKit 层直接 `NSAlert.runModal()`。侵入 UI 但**本项目已实现**。

本迭代选择：**增强现有方式 B**（最小侵入）。在 `ensureScreenRecordingPermission()` 用户点"打开设置"分支中，`openSystemSettings(for:.screenRecording)` 前先调 `requestScreenRecordingPrompt()`，与 onboarding 复用同一 request 逻辑（AC-7）。将"AppState banner（方式 A）"记为后续可选重构，不在本迭代范围。

> 注：`ScreenshotService` 自身不做权限检查，守卫集中在 `AppDelegate`，这比 PRD 假设的"在 ScreenshotService 内守卫"更集中，无需下沉。

### 4.5 数据流示意

- **正常 onboarding（含 bug 修复）**：
  `user → OnboardingView.Continue → VM.continueToNextStep（进入 .screenRecording）→ requestScreenRecordingPrompt() → 系统弹窗 / App 入 TCC 列表 → 用户授权 → refreshPermissions（preflight=true）→ canContinueCurrentStep=true → Continue`
- **跳过**：
  `user → Skip Setup → 确认 Alert → VM.skipOnboarding → 写 onboardingCompleted=true（不写 clipboardEnabled）→ onComplete → AppDelegate 关窗 + startFullExperienceServices → 主界面`
- **按需申请**：
  `跳过后主界面 → 用户按 hotkey 截图 → AppDelegate.ensureScreenRecordingPermission（preflight 未授）→ NSAlert →「打开设置」→ requestScreenRecordingPrompt() + openSystemSettings → 用户授权 → 重新按 hotkey → 截图成功`

---

## 五、接口 / 协议契约

`PermissionServiceProtocol` 完整签名：

| 方法 | 输入 | 输出 | 副作用 | 可 mock |
|------|------|------|--------|---------|
| `status(for:)` | `PermissionKind` | `PermissionStatus` | 无（preflight，只读，不弹窗）| 是（现有 Mock）|
| `openSystemSettings(for:)` | `PermissionKind` | Void | 打开系统设置 URL；accessibility 分支触发 prompt | 是（现有 Mock 记录 opened）|
| `refreshStatuses()` | 无 | `[PermissionKind: PermissionStatus]` | 无 | 是 |
| **`requestScreenRecordingPrompt()`（新增）** | 无 | `Bool`（是否已授权）| **弹系统 TCC UI + 注册 App 到 TCC**；同步返回；**必须主线程调用** | 是（Mock 返回可控 Bool + 记录调用次数）|

新增方法在 `MockPermissionService` 中的 spy 形态（供 §六测试）：
```swift
var requestScreenRecordingResult = false
private(set) var requestScreenRecordingCallCount = 0
func requestScreenRecordingPrompt() -> Bool {
    requestScreenRecordingCallCount += 1
    return requestScreenRecordingResult
}
```

---

## 六、测试策略（简要，详细在 ⑤ test/cases.md）

单元测试：
- `PermissionServiceProtocol.requestScreenRecordingPrompt()` 存在且返回 `Bool`；**不真调 CG API**，用 `MockPermissionService` spy 替换。
- `OnboardingViewModel.continueToNextStep()` 进入 `.screenRecording` 时调用了 `requestScreenRecordingPrompt`（断言 `requestScreenRecordingCallCount >= 1`）。
- request 返回 true → 步骤可前进；返回 false → 停留在 `.screenRecording`。
- `OnboardingViewModel.skipOnboarding()`：断言 `onboardingCompleted` 被写 true；断言 `onComplete` 回调触发；断言 `clipboardEnabled` **未**被强制 true；断言 searchHotkey 被持久化。
- `openPermissionSettings(.screenRecording)` 先调 request 再 openSettings（spy 顺序/计数）。
- 回归：既有 `OnboardingViewModelTests` 全绿（补 Mock 新方法后编译通过）。

手工验收（AC-1~AC-7）：
- Clean 构建（`tccutil reset ScreenCapture <bundleid>` 后）首启走 screenRecording 步骤 → 系统弹窗、App 出现在设置列表。
- 跳过路径 → 进入主界面、重启不再弹 onboarding。
- 跳过后按 hotkey 截图 → 按需申请 Alert → 授权 → 截图成功。

---

## 七、变更影响与回滚

- 无 Core Data schema 变更 → 回滚仅需 revert commit。
- 既有已完成 onboarding 的用户：`onboardingCompleted=true` 已存在，升级不重弹向导（回归风险低）。
- 若 skip 路径异常：可删除 Core Data 库或手动重置 `onboardingCompleted` 恢复。
- `requestScreenRecordingPrompt` 为纯新增方法，不改现有方法签名，向后兼容。

---

## 八、非功能考量

- **线程**：`CGRequestScreenCaptureAccess()` 同步返回，但首次调用触发系统弹窗可能短暂阻塞。要求**在主线程调用**（`OnboardingViewModel` 为 `@MainActor`，`AppDelegate` 截图入口均标 `@MainActor`，天然满足）。
- **可测性**：所有 `CG*` / `AX*` API 必须封装在 `PermissionService` 之下，View / VM 不得直接调用。新增方法必须能被 spy 替换。
- **本地化**：新增所有用户可见文案（`onboarding.skip`、`onboarding.skip.confirm.title/message/action/cancel`）必须在 `Localizable.xcstrings` 中补 en + zh-Hans 两份。
- **文案参考值**（PRD 第五节）：
  - `onboarding.skip` = "Skip Setup" / "跳过设置"
  - `onboarding.skip.confirm.title` = "Skip onboarding?" / "跳过引导？"
  - `onboarding.skip.confirm.message` = "You can configure permissions and preferences later in the app settings. Some features may require additional permissions before they work." / "你可以稍后在应用设置中配置权限和偏好。部分功能可能需要在使用前授予额外权限。"
  - `onboarding.skip.confirm.action` = "Skip" / "跳过"，`onboarding.skip.confirm.cancel` = "Cancel" / "取消"

---

## 九、遗留（对齐 PRD 第七节，仅复述不重复分析）

- L-1：`CFBundleShortVersionString=0.1.0` 与 tag 脱节 → 下个 release 号统一。
- L-2：`build_and_run.sh` 用 `pgrep -x SnapVault` 但可执行文件是 `Assistant` → 顺手改 patch。
- L-3：entitlements `com.apple.security.screencapture` 键可能非官方 → 真自动更新迭代核实。
- L-4：`UpdateServiceTests.swift` 未入 Xcode target → 下个 patch 顺手加。
- L-5：Sparkle 相关 v1.0.1 遗留 → 独立迭代处理。

---

## 自评审

- 是否给了 2-3 个方案？✔️（A/B/C）
- 是否明确推荐？✔️（方案 A，理由已列）
- 每个方案是否列了优缺点？✔️
- 术语是否与 PRD 一致？✔️（§一引用 PRD）
- 是否有可测性说明？✔️（§五 spy 契约 + §六测试策略）
- 是否有回滚策略？✔️（§七）
- 是否偏离局部性约束？无，仅 4 触点 + Mock + 文案。
