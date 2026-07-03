# v1.1.0 架构评审记录

- **评审时间**：2026-07-02
- **评审对象**：doc/iterations/v1.1.0/architecture/design.md
- **评审人**：architecture-review subagent
- **评审结论**：APPROVED_WITH_MINOR_FIXES

## 一、术语一致性
- 结论：一致，无冲突。design.md §一直接引用 PRD 五术语（request / preflight / skip / on-demand / completion），未重定义。"completion" 明确统一到 `SettingKey.onboardingCompleted`，与 PRD P-2.3/P-2.5 吻合。

## 二、方案选择
- 结论：A 推荐合理。A/B/C 对比公允：B（PermissionOrchestrator）被 PRD 第六节"记录延后权限为可选优化"排除，C（状态机 DAG）收益不匹配。
- "只修 bug 不加跳过分两 PR"这一显而易见方案未被显式讨论——但迭代 README 已说明本迭代刻意合并（代码触点重叠、修复互补），可接受，无需改。
- 推荐 A 的四条理由（改动局部 / 与 accessibility 对称 / 无新抽象 / 复用现有 NSAlert 入口）均成立。

## 三、影响范围完整性
| 模块 | 判定 | 说明 |
|------|------|------|
| PermissionService(+Protocol) | 命中 | 新增 `requestScreenRecordingPrompt()`，源码触点准确 |
| OnboardingViewModel | 命中 | 进入 .screenRecording 触发 request + skipOnboarding()；行号对齐现状 |
| OnboardingView footer | 命中 | footer 与 step 无关，天然满足 AC-4；行号 100-111 准确 |
| AppDelegate.ensureScreenRecordingPermission() | 命中 | 现状在 766-783，design 引用准确；确认覆盖 |
| MockPermissionService | 命中 | 需补新方法 |
| **StaticPermissionService** | **原遗漏→已补** | SettingsSourceTests.swift:187 亦 conform，缺则编译失败（AC-8）。已直接修订 design.md |
| **SettingsViewModel** | **原遗漏→已补注** | 设置面板"权限"页(213) 是 AC-7 的申请入口之一,同样存在 TCC 缺口;本迭代不强制改造,但需知悉 |
| HotkeyManager/触发路径 | 无独立模块 | 只有 HotkeyValidationService;快捷键回调集中在 AppDelegate.registerGlobalShortcuts,截图前均过 ensureScreenRecordingPermission 守卫(见 §十) |
| Localizable.xcstrings | 命中 | 单一 catalog,en+zh 同文件,确认路径存在 |
- 不影响模块声明（Sparkle / 剪贴板核心 / Core Data schema / 网络搜索）核查准确。

## 四、接口/协议契约
- `requestScreenRecordingPrompt() -> Bool`：签名合理，返回值语义（当前是否已授权）清晰，与 `CGRequestScreenCaptureAccess()` 一致。
- 主线程约束：§八明确"必须主线程调用"，并论证 OnboardingViewModel(@MainActor) 与 AppDelegate 截图入口(@MainActor) 天然满足。契约表也标注。合格。
- 副作用（弹系统 UI + TCC 注册 + 同步返回）已在 §五契约表文档化。合格。
- `skipOnboarding()` vs `completeIfPossible()`：§4.2 差异表清晰、可预测（前置校验 / clipboardEnabled / launchAtLogin / 权限四维度对比），与现状代码 completeIfPossible(103-130) 一致。

## 五、按需申请路径决策
- **判定：偏差属"修正"而非降级，接受。** design 选择复用 `AppDelegate.ensureScreenRecordingPermission()`（已是 NSAlert 守卫，且已守在三个截图入口前）比 PRD 假设的"AppState banner + ScreenshotService 内守卫"更集中、改动更小，且 §4.4 已论证 ScreenshotService 无需下沉守卫——合理。
- 现状 `ensureScreenRecordingPermission()` "权限缺失→openSettings 但未 request" 的 bug，design §4.4 明确要求在 openSystemSettings 前补一次 `requestScreenRecordingPrompt()`，与 onboarding 复用同一逻辑，妥善集成 AC-7。
- **`new PermissionService()`（非注入）是否本迭代顺手改注入：建议作为 P2 遗留，不动。** 理由：该入口是 AppDelegate 内部私有方法，注入需改造 AppDelegate 依赖装配，超出"最小侵入"；且其单测本就靠手工验收，改注入不解锁新单测价值。design §三方案A缺点已如实披露此局限，可接受。

## 六、可测性
- 覆盖度：单测策略覆盖 P-1.1(request 被调)/P-1.2(true→前进)/P-1.3(false→停留)/P-2.3(skip 写 flag、不写 clipboardEnabled、持久化 hotkey、onComplete 触发)。P-2.4/P-2.5/AC-1~3/AC-6 依赖真实 TCC/重启，归手工验收，合理。
- MockPermissionService 补方法可行（spy 形态 §五已给样例代码）。StaticPermissionService 也需补（已在 §三修订标注）。
- spy 指引：§五给了 `requestScreenRecordingCallCount` + `requestScreenRecordingResult` 样例，且 §六要求断言 openPermissionSettings 的 request→openSettings 调用顺序，对齐现有 `opened: [PermissionKind]` spy 模式。合格。

## 七、本地化与 UI
- 文案键清单化：§八列出 5 键（onboarding.skip / skip.confirm.title|message|action|cancel）+ en/zh-Hans 参考值，完整。
- Skip 按钮位置：§4.3 明确左下角、与 Quit 并列、远离右下 Continue，满足 PRD 交互约束。
- Alert role：§4.3 代码示例给出 `.destructive`(Skip) / `.cancel`(Cancel)，标签明确。合格。

## 八、非功能与回滚
- 线程约束明确（§八，@MainActor 论证）。
- 回滚可行：无 schema 变更，revert commit 即可（§七）；新增方法向后兼容。
- 既有 onboardingCompleted=true 用户不重弹：§七明确，且 AppDelegate.loadOnboardingCompletionState(225-236) 现状支撑。合格。

## 九、边界与遗留
- L-1~L-5 与 PRD 第七节逐条一致，无篡改。
- 无把 L-* 拉进本迭代的迹象；方案 B/C 明确留后。边界干净。

## 十、死角/风险
1. **CGRequestScreenCaptureAccess 首次调用两种行为**（未决→弹窗 / 已决→仅返回不弹）：design §4.1/§4.2 通过"返回 true 直接前进、返回 false 停留 + preflight 复检"覆盖了两种返回值分支,行为闭环。**已 handle。严重度 P2（仅建议补充：首次调用与"已 denied 后再调不再弹、只能去设置"的差异可在 test/cases.md 手工用例注明）。**
2. **系统设置授权后回 app 的自动检测**：design 依赖用户手动点 "Recheck" 按钮触发 refreshPermissions（OnboardingView 140-142 现状有 recheck 按钮），**未**引入 NSWorkspace didActivateApplication 监听。全仓确认当前无任何 app-activation observer。这是常见踩坑点但**当前 onboarding 已用 recheck 按钮规避**,可接受。**部分 handle。严重度 P2（建议:在 review 备注中提示 ⑤ 阶段确认 recheck 按钮在 screenRecording 步骤可见且文案引导用户"授权后点重新检查";可选增强 activation 监听留后续迭代）。**
3. **跳过后按 hotkey 触发截图**：`registerGlobalShortcuts`→`performRegionCapture/Window` 均先 `guard ensureScreenRecordingPermission() else { return }`(AppDelegate 640/682/738)。权限缺失→弹 NSAlert 不 crash、不空截图。**已 handle。严重度 无（设计正确,现状已守卫）。**
4. **跳过后 clipboard 相关快捷键**：clipboardEnabled 默认 false→`syncAssistantRuntimeSettings` 调 `pauseRecording`,录制暂停;toggle 命令(handleCommandToggleClipboardRecording)仍可翻转。design 未显式讨论"跳过后剪贴板快捷键触发到什么",但现状链路是"静默不录制",无 crash 风险。**未显式 handle 但现状安全。严重度 P2（建议 ⑤ 补一句:跳过后 clipboardEnabled=false 时剪贴板监听 pause,不影响其它快捷键)。**
5. **重复初始化幂等**：跳过路径与正常路径都走 `onComplete`→`startFullExperienceServices`。该方法每次会 new searchPanelViewModel/screenshotToolbar、start cleanupService、registerGlobalShortcuts。正常流程只调用一次(onboardingWindow 关闭后不再触发),跳过也只触发一次,**单次会话内不会重复调用**(onComplete 后 window 关闭+置 nil)。**已 handle(天然单次)。严重度 P2(建议:确认 startFullExperienceServices 不被二次调用;当前 isOnboardingCompleted 分支+onboardingWindow=nil 保证之,无需改)。**

## 十一、修订记录
1. design.md §二"影响的模块"：将原单条 `MockPermissionService` 扩展为——① MockPermissionService(补 spy)、② StaticPermissionService(SettingsSourceTests.swift:187,补固定返回,否则协议新增方法致编译失败/AC-8 回归失败)、③ SettingsViewModel(213,AC-7 设置面板入口,知悉 TCC 缺口,本迭代不强制改造)。此为阻塞级补充(缺 StaticPermissionService 会编译失败)。

## 十二、最终结论
- 状态：APPROVED_WITH_MINOR_FIXES
- 阻塞级问题：1 条（协议新增方法遗漏 StaticPermissionService conformer）——已在评审中直接修订 design.md，下一环输入已自洽。
- 是否可进入 ⑤ 开发测试：是
- 死角部分 5 条均给出严重度判定（1×无 / 4×P2），无 P0/P1 遗留；P2 项均为"建议在 ⑤ test/cases.md 补充说明或手工用例注明"，不阻塞开发。
