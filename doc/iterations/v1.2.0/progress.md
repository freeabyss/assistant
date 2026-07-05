# v1.2.0 迭代进度

## ① 需求分析 + ② 产品设计 —— doc/prd.md 全面重写（青鸟 Qingniao）

**执行时间**：2026-07-03
**产出**：doc/prd.md 直接覆盖重写（1016 行，17 个一级章节）

### 关键产品决策（导航）

**补齐（列入 v1.2 开发范围，有验收标准）**
- 文件搜索接入：FileSearchSource 接线（此前 522 行代码从未实例化）。默认索引 `~/Desktop`/`~/Documents`/`~/Downloads`，只做文件名/路径匹配。FR-SEARCH-FILE / US-012 / D-105。
- 全屏截图全局快捷键：默认 `⌃⌥⌘3`，可重绑。FR-SHOT-FULLSCREEN / US-013 / D-107。
- 版本号三源修正：MARKETING_VERSION/Info.plist/CHANGELOG 统一 1.2.0，关于页一致。FR-UI-36 / FR-UI-ABOUT-VERSION / D-108。

**改（产品行为/策略调整）**
- onboarding 辅助功能由强制改为按需申请（取代旧 FR-ONBOARD-8/9）。FR-ONBOARD-ACCESSIBILITY-ONDEMAND / D-104。
- 关闭 App Sandbox → Developer ID 签名 + notarytool 公证 + GitHub Releases，非 MAS（取代 D-050）。FR-PERM-APPLE-EVENTS / §7.9 / §10.5 / D-103。
- 品牌名定案：青鸟 Qingniao，Bundle ID 保留 com.assistant.app。§2.0 / D-101 / D-102。反馈邮箱 feedback@qingniao.app。

**移除 / 诚实标注（不再声称已支持）**
- OCR：确认 MVP 不含，死代码 v1.2 删除，列入 V2.x。§5.3 / D-110。
- 标注"模糊"：v1.2 只保留 mosaic 马赛克；blur 独立工具列入 V1.x。FR-ANNOTATE-BLUR / D-019。
- 死代码清理：MenuBarView + UnifiedSearchViewModel/Service(legacy)、UnitConverterSource、OCRService/ContentStore。§10.7 / D-106。
- build_and_run.sh 的 `pgrep -x SnapVault` 改为 Qingniao。§10.7。

**延后（V1.x / V2.x）**
- 数据备份/导出（FR-DATA-EXPORT-BACKUP，v1.2 只说明存储位置+迁移策略，不做导出）。
- 存储栈统一（Core Data + GRDB 双栈技术债，v1.2 不重构，重点关注一致性）。§10.6 / D-109。
- iCloud 同步、插件/Workflow、Pro 模式、blur 工具、文件索引可配置化。§14。

### 新增章节（相对旧 PRD）
- 7.2a 文件搜索、7.9 分发与系统权限、7.10 数据备份与迁移、7.11 快捷键体系、7.12 空态与错误态、7.13 卸载与数据清理、7.14 无障碍(VoiceOver)。
- 新增 US-012/US-013；新增 D-101~D-111；标注旧 D-050/D-056/D-058/D-085 被取代关系；移除自指涉的 D-095~D-100。

### 文档交叉引用
- 全文改为 doc/test/cases.md、doc/architecture/design.md、doc/architecture/db.md、doc/architecture/api.md（唯一残留 doc/architecture.md 在 D-095~D-100 说明中作为"已失效旧路径"提及，属正确语境）。

### v1.2 必验项（写入 §12.1，后续同步 doc/test/cases.md）
AC-FILE 文件搜索 E2E、AC-FULLSCREEN 全屏热键、AC-VERSION 版本号 1.2.0、AC-ONBOARD-ACCESSIBILITY 不强制辅助功能、AC-6 重启不重弹、AC-7 按需申请 Alert、AC-CMD-SANDBOX 非 sandbox 命令可执行、AC-SIGN 签名公证。

### 留给后续 subagent 的提示
- ③ 架构设计：需在 doc/architecture/design.md 落实 FileSearchSource 接线、全屏热键、Sandbox 关闭 entitlements 变更、双栈技术债与统一方向、死代码清理清单。本 PRD 只做产品层，未改架构文档。
- ⑤ 开发：版本号/CHANGELOG/pgrep/Bundle ID 相关改动逐任务落地，注意 Bundle ID 必须保持 com.assistant.app。
- 第 16 章 9 条待解决问题需在架构/开发阶段逐一定案。

---

## ②b 视觉设计系统 + 页面规范 —— 写入 doc/prd.md 第 9 章

**执行时间**：2026-07-03
**产出**：doc/prd.md 由 1016 行扩展到 1343 行。UI 设计语言与页面规范已全部写入 PRD（未新建独立设计报告文件）。

### 主要改动
- **第 9 章「设计考量」整体重写为「设计语言与交互」**：原 9.1 统一入口交互 / 9.2 App 形态 / 9.3 管理中心页面 合并进新结构。新增 9.1 设计哲学、9.2 Design Tokens（品牌色/中性色/圆角/间距/字号/阴影/材质/动效/图标，Light+Dark 双模式表格）、9.3 核心交互范式、9.4 页面规范（P-01 命令栏 / P-02 剪贴板窗口 / P-03 设置窗口 / P-04 截图叠层 / P-05 截图标注 / P-06 Onboarding + 3 工具浮层）、9.5 通用组件、9.6 快捷键总表、9.7 空态错误态、9.8 无障碍、9.9 i18n、9.10 品牌资产清单。
- **第 7 章 FR-UI 新增 12 条**：FR-UI-DESIGN-TOKENS / COMMAND-BAR / CLIPBOARD-WINDOW / SETTINGS-WINDOW / SCREENSHOT-OVERLAY / SCREENSHOT-ANNOTATE / ONBOARDING / HOTKEYS / EMPTY-STATES / A11Y / I18N / ASSETS（均指向第 9 章细则）。
- **第 15 章新增决策 D-112 ~ D-120**（9 条）：设计语言定风格、品牌色 Jade、命令栏浮层形态、明暗跟随+ultraThinMaterial、Onboarding 单屏、blur 延后 v1.3、统一 DesignToken 层、组件去重（双行组件/双搜索/三套 Toast→单套）、命令栏空态最近使用+收藏。
- **第 16 章待解决问题**：移除已解决的"产品正式名/图标/Slogan"表述；新增第 8 条 AppIcon 最终设计（v1.2 用 SF Symbol 占位）、第 11 条 dmg 安装背景；保留官网/隐私政策 URL；从 9 条扩展到 11 条。

### 一致性说明
- 空态首页"最近使用+收藏"（D-120）与旧 FR-SEARCH-14/15"搜索空输入不展示推荐"在 9.3 与 D-120 中标注为演进关系（空态展示入口而非搜索推荐结果），未直接删改旧 FR。
- 未触碰 doc/architecture/ 与 doc/test/；所有实现细节（双栈/Core Data/GRDB）未写入产品 FR。
- blur 在标注工具中禁用并标注目标版本 v1.3（与 D-019/FR-ANNOTATE-BLUR 的 V1.x 表述一致，D-117 明确为 v1.3）。

### 留给后续 subagent 的提示
- ③ 架构设计：需在 doc/architecture/design.md 落实 DesignToken 枚举层（JadeColor/Radius/Space/Font/Shadow/Material）、通用组件（JadeButton/JadeTextField/HotkeyRecorder/StatCard/ListRow/Pill/Tooltip/Toast/ConfirmationDialog/PermissionGate）、P-01~P-06 页面结构与尺寸、组件去重（收敛双行组件/双搜索体系/三套 Toast）。

---

## ③ 架构设计 + ④ 架构评审 —— doc/architecture/ 三文档修订 + 评审记录

**执行时间**：2026-07-03
**产出**：
- `doc/architecture/design.md` 覆盖修订为 **v17**（约 470 行）
- `doc/architecture/api.md` 覆盖修订为 **v3**（约 560 行）
- `doc/architecture/db.md` 覆盖修订为 **v3**（约 300 行）
- 新建 `doc/iterations/v1.2.0/architecture/review.md`（本迭代详细评审，APPROVED_WITH_MINOR_FIXES）
- 追加 `doc/architecture/review.md` v1.2.0 摘要节（未覆盖历史）

### design.md（v17）主要新增/重写章节
- §2 架构总览：6 层职责边界表 + **§2.5 AppContainer（DI 根，拆解 955 行 AppDelegate god object）**
- §3 模块设计：Onboarding 单屏 + 辅助功能按需；Search 删 UnifiedSearch*、FileSearchSource 接入（权重 75）、删 UnitConverterSource、空态最近使用+收藏；Clipboard 收敛 AssistantClipboardRepository 单仓；Screenshot 全屏热键 + 悬浮 pill；**§3.7 UI/Design System（JadeToken + 统一组件 + 三套 Toast→JadeToast）**；§3.8 移除 Sparkle
- 新增章节：**§16 窗口管理（4 窗口+1 叠层的控制器/层级/生命周期）、§17 改名迁移、§18 分发与签名（entitlements 清单）、§19 无障碍支持**
- §4 数据架构：双栈技术债标注；§22 风险表更新（新增双栈/文件搜索性能/DesignToken/改名拆分回归/关闭 Sandbox/强制解包，移除已解决 3 项）；§23 变更记录追加 v1.2.0

### api.md（v3）接口清单
- **新增**：DesignTokens（JadeColor/Radius/Space/Font/Shadow/Material/Motion）、JadeButton/JadeTextField/HotkeyRecorder/ListRow/JadeToast 等统一组件、FileSearchSource/FileSearchResult + SearchAction.openFile/revealInFinder + 文件权重 75、AppContainer + StatusItemController + 5 类窗口控制器、GlobalShortcutManager(registerFullscreenCapture)、HotkeyConflictDetector、PermissionService.onDemandAccessibilityCheck()、OnboardingViewModel 单屏化、SettingKey/SettingsRoute 新增（appearance/data/feedback/fileSource/截图热键/onboardingCompletedAt）、QingniaoError 4 新 case
- **删除（§21 Removed 表）**：UnifiedSearchService/ViewModel/UnifiedResultRow/ResultGroupView/UnifiedResultList/UnifiedSearchTypes、MenuBarView、UnitConverterSource、OCRService/ContentStore/ContentRepository/GRDB ClipboardRepository、ClipboardRecordSnapshot.ocrText、OnboardingStep、三套 Toast、Sparkle 配置；AssistantError→QingniaoError
- **改名**：module→Qingniao、测试模块→QingniaoTests、类型前缀 Assistant→Qingniao（含 §2.1 改名清单，领域名 Clipboard*/Search* 保持）

### db.md（v3）主要变更
- 数据目录 `Assistant/`→`Qingniao/`（启动 move 迁移 + store 重命名 + lightweight migration，失败 fallback 备份旧库+新建空库）
- 删除 ClipboardRecord.ocrText 及 OCR 索引/表/迁移
- AppSetting 默认值更新（onboarding.completedAt 取代 onboarding.completed、appearance.mode、data.folderBookmark、三截图热键、search.source.file.enabled；clipboard.enabled=true 保持）
- UsageStat 保留用于概览页统计；新增"清空所有数据"+"打开数据目录"流程；双栈技术债说明（§14）；删 ContentRepository/ContentStore schema 标注历史

### 评审结论
- **APPROVED_WITH_MINOR_FIXES**：阻塞级 0（5 项原阻塞级已在评审中直接修订进文档）、改善级 6（M-1~M-6，见 review.md 第八节任务拆解建议 12–15 个任务）
- **发现 PRD 冲突（未改 PRD，留 leader 决定）**：FR-SEARCH-11"文件优先级 60"与 §9.3"75"矛盾，架构取 75 并标注，建议 PRD 把 60 改 75（唯一需改字点）；FR-SEARCH-14/15 与 D-120 空态语义建议加交叉引用

### 留给后续 subagent 的提示
- ⑤ 拆任务：参考 review.md §八 建议的 T-A~T-O（改名/版本、数据迁移、AppContainer、窗口拆分、死代码清理×2、UnitConverter 合并、FileSearch 接入、全屏热键、Onboarding 单屏、关 Sandbox+签名+移除 Sparkle、DesignToken、外观/数据页+冲突检测、健壮性整改、测试同步）。注意 AppDelegate 拆分与 DesignToken 迁移是最大回归面（M-1/M-2），建议分批。
- ⑤ 测试：FileSearchSourceTests 保留转为接线回归；UnitConverterSourceTests + OCR 相关测试删除。
- code review 必查：onDemandAccessibilityCheck 的 Mock/Static 两 conformer 补齐（否则编译失败）。

---

## ⑤.1 测试用例生成 + 用例评审 —— doc/test/cases.md 第 11 节 + report.md 占位 + review.md

**执行时间**：2026-07-03
**产出**：
- `doc/test/cases.md`：新增第 11 节「青鸟 Qingniao v1.2 测试用例」（+98 条 TC），并对第 5 节因 v1.2 UI 重设计受影响的旧 TC 就地标注「v1.2 修订」（6 处：Onboarding/菜单栏/搜索/剪贴板/截图/命令/关于），更新版本记录与修订记录表。文件由 471 行扩到约 1130 行。
- `doc/test/report.md`：追加 v1.2.0 节（**计划占位**，开发未开始，不含执行结果）。
- 新建 `doc/iterations/v1.2.0/test/review.md`：用例评审记录（APPROVED_WITH_MINOR_FIXES，阻塞级 0、改善级 4 已直接修订）。

### v1.2 新增 TC 结构（98 条，20 个模块前缀）
TOK(6) 设计 token / BRAND(7) 改名一致性 / DATA(5) 数据迁移 / DI(3) AppContainer / SEARCH-F(9) 文件搜索 / SEARCH-E(5) 命令栏空态增强 / SHOT-FS(4) 全屏热键 / SHOT-UI(5) 标注 UI / ONB-V2(8) Onboarding 单屏 / PERM-OD(3) 权限按需 / CODE(5) 死代码 / DIST(6) 分发签名 / UPD(3) 更新 / SHORTCUT(4) 快捷键 / SETNEW(5) 设置新页 / REG(7) 回归 / BUILD(2) 构建脚本 / ROBUST(2) 健壮性 / ACC(5) 无障碍 / I18N(4) 双语。
- P0=49、P1=42、P2=7。P0 覆盖改名/迁移/文件搜索/全屏热键/onboarding/分发/死代码核心路径。
- 每条含 关联 FR/AC、前置、步骤、预期、优先级、自动化类型、对应测试文件（或待建）。
- 含 v1.2 追溯矩阵（P0 FR/AC→TC）+ P0 统计表 + 架构 M-1~M-6 看护映射。

### 评审结论
- **APPROVED_WITH_MINOR_FIXES**：阻塞级 0；改善级 4（均为 PRD/架构文档内既存不一致的测试侧下游映射，已直接修订 cases.md 并选定测试基线）。
- 架构 6 改善级问题（M-1~M-6）每个至少 1 条 TC 看护，无遗漏。

### 发现的 PRD/架构不一致（未改源文档，转 leader 校准；测试已选基线）
1. FR-SEARCH-11 文件优先级 60 vs §9.3/D-121 的 75 —— 测试取 75（SEARCH-F-006）。
2. FR-SEARCH-14/15 空态 vs D-120 最近+收藏 —— 测试取 D-120（SEARCH-E-001）。
3. **[新]** 截图保存默认目录：FR-SHOT-10 `~/Pictures/Screenshots` vs §9.4 P-05 `~/Desktop` —— 测试取 FR-SHOT-10（SHOT-007）。
4. **[新]** 区域/窗口截图默认热键：§9.6 `⇧⌃⌘4/5` vs §7.11/US-013 示例 `⌃⌥⌘4/5` —— 测试取 §9.6（SHORTCUT-002）。
5. 文件搜索拼音/首字母：任务指令要求 vs FR-SEARCH-13「只做原文搜索」—— 测试以 FR-SEARCH-13 为准，拼音不作 P0 门禁（SEARCH-F-003）。

### 留给后续 subagent 的提示
- ⑤ 开发每完成一批任务（T-A~T-O），对应回填 report.md v1.2.0 节实际通过数/失败详情；swift/xcodebuild 基线在删 UnitConverter/OCR 用例 + 增 v1.2 新用例后重新核定。
- 待建测试文件：DesignTokenTests / BrandingConsistencyTests / DataMigrationTests / AppContainerTests / GlobalShortcutTests / HotkeyConflictDetectorTests / OnDemandPermissionTests；FileSearchSourceTests 转接线回归。
- 可入 CI 的脚本/静态校验：版本三源、entitlements、无 Sparkle、死代码 grep、强制解包 grep、build_and_run pgrep。
- 上线前专项：反馈邮箱 feedback@qingniao.app 可收件、qingniao.app 域名/隐私政策 URL 最终确定。

---

## T-001 工程与品牌改名（已完成 · 2026-07-03）

### 完成内容
1. **目录/文件 rename（git mv）**：`SnapVault/`→`Qingniao/`、`SnapVaultTests/`→`QingniaoTests/`、`SnapVault.xcodeproj`→`Qingniao.xcodeproj`、`SnapVault.entitlements`→`Qingniao.entitlements`、`SnapVaultApp.swift`→`QingniaoApp.swift`、`SnapVault.xcscheme`→`Qingniao.xcscheme`。
2. **project.pbxproj**：target `Assistant`→`Qingniao`、`SnapVaultTests`→`QingniaoTests`；`PRODUCT_NAME` Assistant→Qingniao；`PRODUCT_MODULE_NAME` SnapVault→Qingniao；`INFOPLIST_FILE`/`CODE_SIGN_ENTITLEMENTS` 指向 `Qingniao/`；`MARKETING_VERSION` 0.1.0→1.2.0；`CURRENT_PROJECT_VERSION` 1→120；产物 `Assistant.app`→`Qingniao.app`；TEST_HOST 同步。**Bundle ID `com.assistant.app` 保留不变**。scheme 内 BuildableName/BlueprintName/container 同步。
3. **Info.plist**：`CFBundleDisplayName`=Qingniao、`CFBundleName`=青鸟、`CFBundleShortVersionString`=1.2.0、`CFBundleVersion`=120；新增 `NSHumanReadableCopyright`（© 2026 青鸟 Qingniao）；`NSScreenCaptureUsageInfo`/`NSAppleEventsUsageDescription` 文案 Mac Super Assistant→青鸟 Qingniao；**删除 Sparkle 键** SUFeedURL/SUPublicEDKey/SUEnableAutomaticChecks/SUScheduledCheckInterval。
4. **Swift 用户可见字符串**：AppDelegate 状态栏 accessibilityDescription→青鸟 Qingniao；ReleaseInfoService `appName`=Qingniao、版权=青鸟 Qingniao、`feedbackEmail`=feedback@qingniao.app、邮件主题=「青鸟 Qingniao 反馈」、GitHub URL→github.com/freeabyss/assistant；Localizable.xcstrings 12 处 Mac Super Assistant→青鸟 Qingniao；appcast.xml 品牌+URL 更新。
5. **测试**：QingniaoTests 全部 `@testable import SnapVault`→`import Qingniao`；ReleaseInfoServiceTests URL/邮箱/主题断言同步更新。
6. **build_and_run.sh**：PROJECT_NAME/SCHEME_NAME/APP_PATH→Qingniao（pgrep 用 $PROJECT_NAME 自动生效）。
7. **Package.swift**：module Qingniao、testTarget QingniaoTests、path Qingniao/ & QingniaoTests/、exclude QingniaoApp.swift/Qingniao.entitlements。

### 验证结果
- `xcodebuild -project Qingniao.xcodeproj -scheme Qingniao -configuration Debug build` → **BUILD SUCCEEDED**。
- 产物 Qingniao.app/Info.plist：CFBundleDisplayName=Qingniao、CFBundleName=青鸟、ShortVersion=1.2.0、Version=120、Identifier=com.assistant.app（保留）、无 Sparkle 键。
- grep：产品源码/Info.plist/构建脚本/Package.swift 无 `Mac Super Assistant` 残留；无 `SnapVault` 残留（仅 `SnapVaultError.swift` 文件名/类型按任务约定保留）。

### 留给后续 agent 的提示
- **Swift 类型/文件名未改**：`SnapVaultError`（→QingniaoError, api.md §2.3）、`AssistantClipboardRepository`/`AssistantClipboardSource`/`AssistantFileSystem`、`AssistantApp` struct 名等品牌前缀类型仍在，按 api.md 由 T-004~T-015 逐步改，本任务未动以控制回归面。
- Logger subsystem 仍为 `com.assistant.app`（与 Bundle ID 一致，按约定保留）。
- entitlements 仍含 `com.apple.security.app-sandbox=true`，由 T-002 关闭。
- 数据目录仍为 Assistant/（PersistenceController 等），由 T-003 迁移到 Qingniao/。
- markdown 文档（README/PRIVACY/THIRD_PARTY_NOTICES/CHANGELOG）品牌未改，归 T-016；注意 ReleaseInfoServiceTests.testProjectHomepageContainsUS020... 仍断言 README 含 `feedback@assistant.app` 与旧 URL，README 改名时（T-016）需同步或该用例会失败（本任务未跑该用例；build 已通过）。

---

## T-002 关闭 Sandbox + Hardened Runtime + Developer ID 签名/entitlements（已完成 · 2026-07-03）

### 完成内容
1. **Qingniao/Qingniao.entitlements**：
   - `com.apple.security.app-sandbox` 由 `true` 改为 `false`（Developer ID 分发，非 Mac App Store）。
   - 新增 `com.apple.security.automation.apple-events`=`true`，使 restartFinder/restartDock/toggleAppearance 及控制其他 App 的 AppleEvents 在关闭沙盒后可靠执行。
   - 保留 `com.apple.security.files.user-selected.read-write`、`com.apple.security.screencapture`。
2. **Qingniao.xcodeproj/project.pbxproj**：Qingniao target 的 Debug 与 Release 配置均加入 `ENABLE_HARDENED_RUNTIME = YES`（公证要求）。Bundle ID 保持 `com.assistant.app`，CODE_SIGN_STYLE 仍 Automatic（本地 Debug 用 ad-hoc/Sign to Run Locally）。
3. **build_and_run.sh**：新增 `build_for_release` 函数与 `release` 子命令。流程：Release clean build → `codesign --force --deep --options runtime --timestamp --entitlements ... --sign "$DEVELOPER_ID_APP"` → `codesign --verify --deep --strict` → `ditto` 打 zip → `xcrun notarytool submit --keychain-profile "$AC_NOTARY_PROFILE" --wait` → `xcrun stapler staple` → `spctl --assess -vvv --type execute`。证书/公证凭据经环境变量 `DEVELOPER_ID_APP` / `AC_NOTARY_PROFILE` 注入。缺少 DEVELOPER_ID_APP 时快速失败；缺少 AC_NOTARY_PROFILE 时仅完成签名并告警（便于无证书环境验证前半程）。help 文本同步。

### 验证结果
- `xcodebuild -project Qingniao.xcodeproj -scheme Qingniao -configuration Debug build` → **BUILD SUCCEEDED**。
- 构建产物 Qingniao.app 的 `codesign -d --entitlements` 确认：`app-sandbox=false`、`automation.apple-events=true`。
- 14 条白名单命令目录（AssistantCommandCatalog.commands）数量不变仍为 14；SystemCommandSource 执行 restartFinder/restartDock 用 NSRunningApplication.terminate、toggleAppearance 切 NSApp.appearance——关闭 sandbox 后这些 NSWorkspace/AppKit 路径不再受沙盒限制。
- `bash -n build_and_run.sh` 语法 OK；`release` 在无 DEVELOPER_ID_APP 时正确快速失败（exit 1）。

### 未覆盖 / 待人工
- **signing + notarytool 实跑未执行**：本地无 Developer ID Application 证书与 notarytool keychain profile，无法真正签名/公证/staple，故 `spctl --assess ... accepted` 与 done_definition 中「Release 配置签名后 spctl 返回 accepted」需在具备证书的机器上由人工用 `DEVELOPER_ID_APP=... AC_NOTARY_PROFILE=... ./build_and_run.sh release` 验证。Debug 用的是 ad-hoc 签名（flags=0x2 adhoc），不体现 hardened runtime 标志，但 ENABLE_HARDENED_RUNTIME 已写入工程，真实 Developer ID 签名时生效。
- 白名单命令的「实机执行成功」（CMD-001/006/007/008 回归）属手工验收（需运行 App 实际点按），归 T-019 全量回归；本任务仅从代码路径 + entitlements 层面确认已解除沙盒限制。

---

## T-004 DesignToken 层建立（JadeColor/JadeRadius/JadeSpace/JadeFont/JadeShadow/JadeMaterial）（已完成 · 2026-07-03）

### 完成内容
新建 `Qingniao/Views/Design/` 目录，6 个 token 文件，全部按 PRD §9.2 精确取值实现，每个文件带 `#Preview` 可在 Xcode Canvas 查看：

1. **JadeColor.swift**：
   - 品牌色用 `NSColor(name:dynamicProvider:)` 实现明暗自动适配：jade500 `#0A9488`/`#2DD4BF`、jade600 `#087A70`/`#14B8A6`、jade50 `#E6F7F5`/`#0D3D39`。提供 NS 版（jade500NS 等）与 SwiftUI Color 版。
   - semantic：primary=jade500 / primaryHover=jade600 / primaryFill=jade50（含 NS 版）。
   - 文字色绑定系统动态色 textPrimary/Secondary/Tertiary = labelColor/.secondaryLabelColor/.tertiaryLabelColor。
   - surface1=windowBackgroundColor、surface2=controlBackgroundColor、surface3 自定义动态色 `#ECECEE`/`#3A3A3C`（比 surface2 深/浅一档）。
   - border 动态 rgba(0,0,0,0.08)/rgba(255,255,255,0.08)；overlay = black 0.4。
   - status/结果类型底色直接走系统色 systemGreen/Red/Orange/Yellow/Blue/Indigo/Purple/Pink/Gray。
   - 私有 `NSColor(srgbHex:)` 便捷初始化。
2. **JadeRadius.swift**：sm=6/md=8/lg=12/xl=16/xxl=20（enum:CGFloat）；`.value`、`.shape`（RoundedRectangle .continuous）；View 扩展 `.jadeRadius(.lg)`、`.jadeRadiusBorder(...)`。
3. **JadeSpace.swift**：x1=4/x2=8/x3=12/x4=16/x6=24/x8=32；View 扩展 `.jadePadding(.x3)`、`.jadePadding(.horizontal, .x2)`。
4. **JadeFont.swift**：display 40 bold / title1 28 semibold / title2 22 semibold / title3 17 semibold / body 13 regular / callout 12 regular / subhead 11 medium / caption 10 medium / commandBarInput 20 regular（Font.system(size:weight:)）。
5. **JadeShadow.swift**：sm(0 1px 2px 0.06)/md(0 4px 16px 0.10)/lg(0 8px 32px 0.18 + 1px border)/xl(0 24px 64px 0.28 + 1px border)；View 扩展 `.jadeShadow(.xl, radius: .xxl)`，lg/xl 自动附加 1px JadeColor.border 描边。
6. **JadeMaterial.swift**：commandBar/pill → .ultraThinMaterial，sheet → .thinMaterial；View 扩展 `.jadeMaterial(.commandBar, radius: .xxl)`。

**Assets**：新建 `Qingniao/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`，Light Jade500 `#0A9488` / Dark Jade600 系 Dark 主色 `#2DD4BF`（srgb 分量）。

**.tint 全局注入**：QingniaoApp.swift 的 Settings 场景、AppDelegate.swift 三处 NSHostingView rootView（OnboardingView / ManagementCenterView / SearchPanelView）均加 `.tint(JadeColor.primary)`。

**Xcode 工程接入**：项目为手工维护 pbxproj（objectVersion 56，非 synchronized group），仿 Onboarding 的 SOURCE_ROOT 全路径模式，用 `F004...` 前缀 ID 手工新增 6 条 PBXBuildFile + 6 条 PBXFileReference + 新建 `Design` PBXGroup 挂到 Views group + 加入 app target Sources build phase。

### 验证结果
- `xcodebuild -project Qingniao.xcodeproj -scheme Qingniao -configuration Debug build` → **BUILD SUCCEEDED**。
- 确认 6 个 Jade*.o 目标文件均在 DerivedData Objects-normal 下生成（未被静默排除）。
- 仅新增文件警告：无（仅存量 Swift6 NSLock/Sendable 警告，与本任务无关）。

### 留给后续 agent 的提示
- 本任务**不改现有 View 使其改用 token**（那是 T-015），只建立 token 本身与基础扩展。
- Swift 类型改名（AssistantError→QingniaoError 等）不在本任务，T-005/T-006 处理。
- AccentColor.colorset 已建立，macOS 会自动将其作为 App accent；同时代码层显式 `.tint(JadeColor.primary)` 双保险，二者一致（都是 Jade 主色，明暗自适应）。
- Preview 可在 Xcode Canvas 逐个查看：JadeColor（明暗色板）/JadeRadius/JadeSpace/JadeFont/JadeShadow/JadeMaterial。命令行 xcodebuild 无法渲染 Canvas，需人工在 Xcode 打开验证（TOK-001~006/ACC-005 的 Canvas 目视项）。

---

## T-003 数据目录迁移 Assistant/ → Qingniao/ 与清空所有数据 + 打开数据目录（已完成 · 2026-07-05）

### 完成内容

**1. 数据目录路径常量改名（Assistant → Qingniao）**
- `Qingniao/Database/AssistantFileSystem.swift`：新增静态常量 `directoryName="Qingniao"`、`legacyDirectoryName="Assistant"`、`storeFileName="Qingniao.sqlite"`、`legacyStoreFileName="Assistant.sqlite"`、`applicationSupportDirectory`；`.default` 与 `storeURL` 改用新常量。文件名保留 `AssistantFileSystem.swift`（db.md 允许保留；不重命名以免大面积改 pbxproj/引用，struct 名不变，仅路径常量改）。
- `Qingniao/Database/PersistenceController.swift`：`NSPersistentContainer(name:)` 由 "Assistant" → "Qingniao"（store 落到 Qingniao/Qingniao.sqlite）。lightweight migration 原本已开启（`shouldMigrateStoreAutomatically`/`shouldInferMappingModelAutomatically` = true，等价 NSMigratePersistentStoresAutomaticallyOption + NSInferMappingModelAutomaticallyOption），保持不动。
- `Qingniao/Database/DatabaseManager.swift`（GRDB legacy，保留）：`databaseURL()` 由 Assistant/assistant.db → Qingniao/assistant.db（用 `AssistantFileSystem.directoryName`）；文件名 assistant.db 不改（legacy 只读兼容，T-005 处理）。加 legacy 注释。
- `Qingniao/App/AppDelegate.swift`：`createApplicationSupportDirectory()` 目录名改用 `AssistantFileSystem.directoryName`。

**2. 启动时目录迁移（新文件 DataDirectoryMigrator.swift）**
- `Qingniao/Database/DataDirectoryMigrator.swift`（新建）：
  - `migrateIfNeeded() -> Outcome`：新目录存在→alreadyMigrated；无旧目录→freshInstall；旧目录存在且新目录不存在→`FileManager.moveItem` 整目录 rename + 重命名 store 文件 Assistant.sqlite(/-shm/-wal)→Qingniao.sqlite(...)（migrated）。
  - move 失败 fallback：`copyItem` 旧目录到 `Qingniao-migration-backup-<ISO8601 无冒号时间戳>/`，再建空 Qingniao/，返回 `.fallbackBackup(backupURL, underlying)`。永不抛错，保证启动不阻塞。
  - 可注入 applicationSupportDirectory/fileManager/now，便于测试。
- `AppDelegate.applicationDidFinishLaunching` 最前面（DatabaseManager.setup / PersistenceController.load 之前）调用 `migrateDataDirectoryIfNeeded()`；fallback 分支弹 NSAlert（data.migration.failed.* 本地化）并可在 Finder 显示备份目录。

**3. AppSetting 默认值更新（db.md §8.3）**
- `PersistenceController.AssistantSettingDefaults.values` 新增：`onboarding.completedAt`(空串=nil)、`hotkey.capture.region`(shift+ctrl+cmd+4)、`hotkey.capture.window`(shift+ctrl+cmd+5)、`hotkey.capture.fullscreen`(ctrl+option+cmd+3)、`search.source.file.enabled`(true)、`appearance.mode`(system)、`data.folderBookmark`(空串=nil)。
- **保留 `onboarding.completed`(false)**：现有 onboarding 门禁（AppDelegate.loadOnboardingCompletionState / OnboardingViewModel）仍读旧布尔键；切换到 completedAt 语义属后续任务，本任务只新增 completedAt 不破坏门禁。
- `Qingniao/Models/AppSetting.swift`：`SettingKey` 新增 case onboardingCompletedAt/captureRegionHotkey/captureWindowHotkey/captureFullscreenHotkey/fileSourceEnabled/appearanceMode/dataFolderBookmark；新增 `AppearanceMode` enum(system/light/dark) + SettingsService encode/decode 支持。

**4. DataManagementService（新文件，供 T-013 UI 接）**
- `Qingniao/Services/DataManagement/DataManagementService.swift`（新建，含 DataManagement 组）：
  - `resetAllData() async throws`：remove 已加载 persistent store → 删 Qingniao.sqlite(/-shm/-wal) → 删 Clipboard/Images|Thumbnails|RichText → `removePersistentDomain(forName: bundleIdentifier)`（用 com.assistant.app 域，不动 UserDefaults.standard 全局）→ post `.dataDidReset`。失败抛 `DataManagementError.dataResetFailed(reason:)`。
  - `openDataDirectory() -> Bool`：确保 Qingniao/ 存在后 `NSWorkspace.open`。
  - `exportData() throws`：v1.3 占位（assertionFailure + print + log），UI 侧 disabled+tooltip。
  - 新增 `Notification.Name.dataDidReset`（com.assistant.dataDidReset）。
  - 错误类型：因 QingniaoError 伞类型尚不存在（SnapVaultError→QingniaoError 改名属 T-005/T-006），本任务用局部 `DataManagementError.dataResetFailed`。

**5. SettingsViewModel 暴露给 T-013 的方法**
- `Qingniao/ViewModels/SettingsViewModel.swift`：注入 `DataManagementService`；新增 @Published `showResetAllDataConfirmation`/`showResetAllDataRestartAlert`/`isResettingAllData`；方法 `requestResetAllData()`、`confirmResetAllData() async`、`openDataDirectory()`、`exportData()`。

**6. 本地化**：Localizable.xcstrings 新增 data.reset.failed / data.migration.failed.{title,message,reveal,dismiss} / management.data.reset.done（中英）。

**7. Xcode 工程接入**：手工维护 pbxproj，用 `F005...` 前缀 ID 新增 3 个 SOURCE_ROOT 全路径 PBXFileReference（DataDirectoryMigrator.swift 挂 Database 组、DataManagementService.swift 挂新建 DataManagement 组、DataDirectoryMigratorTests.swift 挂 QingniaoTests 组）+ 对应 PBXBuildFile + app/test Sources build phase。

### 验证结果
- `swift build` → Build complete（仅存量 warning）。
- `xcodebuild -project Qingniao.xcodeproj -scheme Qingniao -configuration Debug build` → **BUILD SUCCEEDED**。
- `swift test`（Persistence/Settings/DatabaseManager）19 passed；`xcodebuild test`（DataDirectoryMigrator/Persistence/DatabaseManager）15 passed，含新增 3 条迁移测试（freshInstall/alreadyMigrated/move+rename）。
- 更新受路径改名影响的既有测试：PersistenceControllerTests storeURL 断言 Assistant.sqlite→Qingniao.sqlite；DatabaseManagerTests 路径断言 Assistant→Qingniao。

### 暴露给 T-013 的 API 签名
- `DataManagementService.resetAllData() async throws`
- `DataManagementService.openDataDirectory() -> Bool`（@discardableResult）
- `DataManagementService.exportData() throws`（v1.3 占位，UI disabled）
- `Notification.Name.dataDidReset`
- `SettingsViewModel.requestResetAllData()` / `.confirmResetAllData() async` / `.openDataDirectory()` / `.exportData()`
- `SettingsViewModel` @Published：`showResetAllDataConfirmation`、`showResetAllDataRestartAlert`、`isResettingAllData`
- 新枚举 `AppearanceMode`(system/light/dark) + `SettingKey` 新 case（appearanceMode/fileSourceEnabled/dataFolderBookmark/三截图热键/onboardingCompletedAt）

### 留给后续 agent 的提示
- **onboarding 门禁仍用旧 `onboarding.completed` 布尔**：本任务按"新增"要求加了 `onboarding.completedAt` 默认值与 SettingKey，但未切换 AppDelegate/OnboardingViewModel 的判定逻辑（避免破坏 v1.1 已修的 onboarding 死锁）。若要落实 db.md §8.3"completedAt 取代 completed"，需在专门任务里改门禁 + 迁移旧值 + 更新 OnboardingViewModelTests。
- 「清空所有数据后重启回到 onboarding」：resetAllData 会清 completed 键（随 UserDefaults 域 + Core Data store 一并没了），重启后 initializeDefaultSettings 重建默认（completed=false）→ 回到 onboarding。DataManagementService 只 post .dataDidReset，**实际重启由 UI（T-013）提示用户手动重启或调用 relaunch**，本任务不实现自动重启。
- DataManagementService 的 `resetAllData` 依赖 `PersistenceController.shared.container` 已加载；若在未 load 的实例上调用需注意。
- 截图热键默认值只写进了 AppSetting 默认表（字符串形式），**并未接到 KeyboardShortcuts.Name / 实际热键注册**（KeyboardShortcuts+Names.swift 里 captureRegion/captureWindow 仍是 cmd+shift+a/w，无 fullscreen Name）。热键实际绑定/注册属截图相关任务。
- 数据文件夹安全书签 `data.folderBookmark` 仅加了默认空值键，未实现书签解析/持久化逻辑（关闭 Sandbox 后的用户选择目录场景）。

---

## T-005 死代码清理（UnifiedSearch*/MenuBarView/UnitConverterSource/OCRService/ContentStore/Toast 收敛）— 完成

### 变更概要
按模块删除死代码 + 收敛重复实现，全程保持 Debug build / test-for-building / xcodebuild test 全绿。

**1. UnitConverterSource（独立死代码）**
- 删 `Services/SearchEngine/UnitConverterSource.swift`（仅 legacy UnifiedSearchSource 包装；单位换算已在 CalculatorSource 内）。
- 删 `QingniaoTests/UnitConverterSourceTests.swift`，把其中走 `CalculatorSource.search(query:)` 的换算覆盖（cm/kg/数据大小/温度/拒绝币种体积时长）迁进 `CalculatorSourceTests`；仅删掉走已删类的 legacy wrapper 测试。
- commit 1。

**2. OCR / ContentStore / GRDB ContentRepository / UnifiedSearch / MenuBar（一体化，互相耦合）**
- 删 orphan（pbxproj sources=0，从未编译）：`Services/OCRService/`、`Services/ContentStore/`。
- 删死 GRDB 路径：`Database/Repositories/ContentRepository.swift`、`Services/ExportService/ExportService.swift`、`Services/SearchEngine/SearchService.swift`（ClipboardFTSSearchService/SearchScope/ClipboardFTSSearchResult/ClipboardSearchServiceProtocol）、`Services/SearchEngine/ClipboardSearchSource.swift`。这些都未被实例化；live 剪贴板搜索走 `AssistantClipboardSource`(Core Data)。
- 删死 UI（仅经死的 MenuBarView #Preview 可达）：`Views/MenuBar/MenuBarView.swift`、`ViewModels/UnifiedSearchViewModel.swift`、`Views/SearchResults/UnifiedResultList|UnifiedResultRow|ResultGroupView.swift`、`Views/RecentContent/RecentContentView.swift`、`ViewModels/RecentContentViewModel.swift`（含 OCR 筛选段随文件删除）。
- 删 legacy 搜索栈：`UnifiedSearchService.swift`、`UnifiedSearchTypes.swift`（SearchResultType/SystemCommand/SearchResultAction/UnifiedSearchResult/UnifiedSearchSource/UnifiedSearchResponse）。
- **重接 live 消费者（不删）**：
  - `DataCleanupService` 改用 Core Data `ClipboardRepository.cleanupExpired(now:)`（保留期从 clipboard.retention 设置内部读取）；去掉 GRDB storage-limit 清理（Core Data 库无 max_storage_mb 概念）。
  - `AppDelegate.syncLaunchAtLoginPreference` 改用 `SettingsService`(Core Data) + `LaunchAtLoginService`，去掉 ContentRepository/LegacySettingKey。
  - 从 MenuBarView 抽出 `AutoFocusTextField` + `.focusSearchField`/`.checkForUpdates` 到新文件 `Views/Components/AutoFocusTextField.swift`（live SearchPanelView/AppDelegate 使用）。
  - 从 live 搜索源剥掉死的 UnifiedSearchSource 兼容段：AppSearchSource（删 AppSearchSourceProtocol/AppInfo/getAppInfo/sourceType/legacy search(query:limit:)）、SystemCommandSource（删 sourceType/legacy search/highlightRanges）、CalculatorSource（删 sourceType/legacy search）。
  - **FileSearchSource 移植到新 SearchSource 协议**（该文件 sources=0 未编译，但 T-009 要保留，且 done_definition 禁止 UnifiedSearch 引用）：新增 `SearchAction.openFile/.revealInFinder`、`SourcePriority.file=75`、`SearchSourceID.file`；SearchCore.DefaultSearchActionExecutor + SearchPanelViewModel.execute 补两个 case。
- 测试修正：删 `DatabaseManagerTests` 里两条 ExportItem 测试（ExportService 已删）；重写 `SystemCommandSourceTests` 的 legacy 测试到新 SearchSource 路径（.runCommand/CommandID）。
- commit 2。

**3. Toast 收敛**
- 保留 `Views/Components/ToastView.swift`（ToastView+ToastModifier+.toast()）为唯一实现，注释标记为 T-007 JadeToast 基础；ClipboardListView/SearchPanelView 仍用它。
- RecentContentView 内联 overlay toast 随死簇一并删除。
- ScreenshotToolbarController 内联预览 toast 加 `// TODO: T-007` 标记（预览是独立 NSHostingView 且 JadeToast 未实现，本任务保留功能不重构）。
- commit 3。

### 验证结果
- `xcodebuild -project Qingniao.xcodeproj -scheme Qingniao -configuration Debug build` → **BUILD SUCCEEDED**（每个模块删完都跑）。
- `xcodebuild ... build-for-testing` → **TEST BUILD SUCCEEDED**。
- `xcodebuild ... test` → **TEST SUCCEEDED**（全部测试套件通过）。
- done_definition grep 门禁：`grep -rn "UnifiedSearch|MenuBarView|UnitConverterSource|OCRService|ContentStore|ContentRepository" --include=*.swift` 仅剩解释性注释（无 live 引用）。

### 留给后续 agent 的提示
- **FileSearchSource 已可用但未接线**：已移植到 SearchSource 协议（id=.file、weight 75、primaryAction=.openFile、secondary=[.revealInFinder,.copyText(path)]），但**未加入 AppDelegate.makeSearchPanelViewModel 的 sources 数组**，且未接 fileSourceEnabled 开关 / 索引预热 —— 这些是 T-009 的工作。`FileInfo.icon` 字段现未使用（改用 .appIcon(path)）。
- **SearchAction 新增两 case**（.openFile/.revealInFinder）已在 SearchCore 默认执行器和 SearchPanelViewModel.execute 里实现（NSWorkspace.open / activateFileViewerSelecting）。若 T-009/T-011 有别的 SearchAction switch 记得覆盖。
- **LegacySettingKey**（Models/AppSetting.swift）现已无任何使用者（消费者全删），是死枚举；未删以避免动 T-006 会重构的共享文件，可在 T-006 顺手清掉。
- **Localizable.xcstrings 仍留 OCR 相关字符串**（recent.filter.ocr / preview.ocrText / "OCRService deallocated" 等）—— 孤立无害，未删（改 xcstrings 风险高且不影响 build/grep 门禁）；I18N 任务（T-017）可清理。
- **DataCleanupService 不再做存储上限清理**：Core Data 库无 max_storage_mb 概念，只按 clipboard.retention 过期清理。若产品要恢复容量上限清理需在 Core Data 仓库层新增能力。
- ClipboardMonitor 里 `ClipboardEvent`（legacy 形状）+ `.clipboardItemSaved` 声明保留（live ClipboardMonitor 仍 post 该通知，ClipboardListViewModel 订阅）。
- GRDB 依赖仍在（DatabaseManager/ClipboardItem/Tag/AppSetting 模型），api.md 说 v1.2 保留兼容不写入；未在本任务移除。
- ClipboardItemRow.swift / PreviewPanel.swift 保留（T-012 files_touch_hint 引用、各自有 #Preview 可独立编译），虽然当前无 live 调用点。

---

## T-006 AppContainer DI 容器 + 窗口控制器拆分（解耦 AppDelegate）（已完成 · 2026-07-05）

### 目标
把 ~600 行 god object `AppDelegate` 按职责拆成 AppContainer(DI 根) + 5 个 App Shell 控制器，AppDelegate 瘦身到 <200 行；顺带清掉 review 标注的强制解包点。不重写任何 UI 外观（SearchPanelView/ClipboardListView/ManagementCenterView 保持现状）。

### 新增文件（Qingniao/App/Controllers/）
- **AppContainer.swift**（@MainActor, NSObject）：依赖注入根。
  - 持有 Data/Repository/Service 单例：`clipboardSearchIndex`、`resourceStore`、`clipboardRepository`(IndexingClipboardRepository)、`clipboardMonitor`、`clipboardService`、`cleanupService`、`updateService`、`screenshotService`、三个 SearchSource(app/command/calculator)。
  - 惰性持有 5 个控制器（statusItem/commandBar/clipboardHistory/settings/screenshot）。
  - `bootstrapDataStack(onMigrationFallback:)`：目录迁移(T-003) → DatabaseManager.setup → PersistenceController.load → 索引重建 → 建 App Support 目录。
  - `startFullExperienceServices()` / `stopRuntimeServices()`：剪贴板监听 + 清理服务生命周期。
  - `syncRuntimeSettings()`（clipboardEnabled）/ `syncLaunchAtLoginPreference()` / `loadOnboardingCompletionState()`。
  - `registerCommandObservers()` + 全部命令通知处理（openManagementCenter/settingsDidChange/toggleClipboardRecording/checkPermissions/capture*/checkForUpdates），路由到对应控制器/服务。
  - 工厂：`makeSearchPanelViewModel(onClose:)`（原 AppDelegate.makeSearchPanelViewModel 全套 sources/executor 组装搬来）、`makeClipboardListViewModel()`。
  - init 标 `nonisolated override init()`，避免 AppDelegate 存储属性初始化时的 main-actor 隔离报错。
- **StatusItemController.swift**（NSObject）：NSStatusItem + NSMenu（打开搜索/剪贴板/截图/分隔/设置/关于/分隔/退出），菜单回调转 container 控制器；截图项通过 `onStartScreenshot` 闭包回调。
- **CommandBarController.swift**（NSObject）：Command Bar NSPanel（borderless、floating、hidesOnDeactivate=false、cornerRadius 12、宽 640）。`toggle()/show()/hide()/isVisible`；保留 resignKey + localEventMonitor(guard let) 双关闭、query 驱动的动态 resize（156↔560）、focusSearchField 通知。承载现有 SearchPanelView（UI 重写留 T-011）。含 `FloatingCommandPanel`(canBecomeKey/Main)。
- **ClipboardHistoryWindowController.swift**（NSWindowController）：min 880x600、title「剪贴板历史」、承载 ClipboardListView、首次创建复用（orderOut 隐藏，isReleasedWhenClosed=false）。
- **SettingsWindowController.swift**（NSWindowController）：min 920x640、title「管理中心」、承载 ManagementCenterView（viewModel 由控制器持有），`show(route:)` 直接调 `SettingsViewModel.select(route:)` 导航——**刻意不走 .openManagementCenter 通知**避免与 AppDelegate/AppContainer 的观察者递归。
- **ScreenshotWindowController.swift**：薄封装，惰性持有现有 `ScreenshotToolbarController`；`captureRegion/captureWindow/captureFullScreen` 共用一个 `performCapture` 流程（含权限校验弹窗、隐藏命令栏、捕获、预览、取消恢复）。UI 重写留 T-014。

### 搬移方法清单（AppDelegate → 去向）
| 原 AppDelegate 方法 | 去向 |
| :-- | :-- |
| makeSearchPanelViewModel / assistant* 组装 | AppContainer.makeSearchPanelViewModel + 存储属性 |
| makeSearchPanelViewModel 里 clipboard 组装（showManagementCenter 内） | AppContainer.makeClipboardListViewModel |
| setupStatusItem / makeStatusMenu / statusItemClicked / *FromMenu | StatusItemController |
| togglePanel / showPanel / closePanel / createPanel / resizePanelForSearchState / panelDidResignKey / start/stopMonitoringEvents | CommandBarController |
| showClipboardHistoryWindow | ClipboardHistoryWindowController.show |
| showManagementCenter(route:) | SettingsWindowController.show(route:) |
| performRegionCapture / performWindowCapture / performScreenCapture / ensureScreenRecordingPermission | ScreenshotWindowController |
| startClipboardMonitoring / startInitialClipboardIndexRebuild / syncAssistantRuntimeSettings | AppContainer |
| createApplicationSupportDirectory / migrateDataDirectoryIfNeeded / syncLaunchAtLoginPreference / loadOnboardingCompletionState | AppContainer（migration fallback alert 仍在 AppDelegate，因需 NSAlert/UI） |
| handleCommand* / handleOpenManagementCenter / handleSettingsDidChange / handleCheckForUpdates | AppContainer.registerCommandObservers + handlers |
| applicationDidFinishLaunching / applicationWillTerminate / showOnboardingWindow / ensureOnboardingGate / presentMigrationFallbackAlert / registerGlobalShortcuts / activateApp | **保留在 AppDelegate** |

AppDelegate 通过 `container.onboardingGate = { self.ensureOnboardingGate() }` 把 onboarding 门禁注入容器，控制器调用 `container.ensureOnboardingReady()` 决定是否放行（保留原「未完成 onboarding 则弹向导、不放行」行为）。

### 强制解包整改（review M-6）
- `localEventMonitor!` → CommandBarController 内 `guard let monitor = localEventMonitor`。
- `ReleaseInfoService` 4 个 `URL(string:)!` → 私有 `url(_:)` helper（`URL(string:) ?? URL(fileURLWithPath:"/")`）；`errorSummary!` → 可选绑定。
- `SystemCommandSource` `URL(string:"x-apple.systempreferences:")!` → guard let，失败 throw executionFailed。
- `CalculatorSource` `try! NSRegularExpression` → do/catch，编译失败记日志并禁用换算（regex 改可选，parse 首行 guard）。
- `PreviewPanel` `documentView as! NSTextView` → guard let 优雅降级。
- 剩余 fatalError 仅 4 处，全是 AppKit `init(coder:)` 样板。

### 验证结果
- `xcodebuild -project Qingniao.xcodeproj -scheme Qingniao -configuration Debug build` → **BUILD SUCCEEDED**。
- `xcodebuild ... build-for-testing` → **TEST BUILD SUCCEEDED**。
- `swift build` → Build complete；`swift test` → **133 tests, 0 failures**。
- `grep 'try!| as! |string:)!'` 非测试代码仅剩 ReleaseInfoService 注释里的说明字样，无 live 强解。
- AppDelegate.swift = **150 行**（< 200 目标）。

### commit
1. `refactor(T-006): extract AppContainer DI root + window controllers from AppDelegate`（新增 6 控制器文件 + AppDelegate 瘦身 + QingniaoApp Settings 场景清空 + pbxproj 接线）
2. `fix(T-006): remove force-unwraps flagged in v1.2 robustness pass`
3. 本次 progress/tasks 记录 commit

### 留给后续 agent 的提示
- **pbxproj 是手工维护的 group 型工程**（非 fileSystemSynchronized）。新增 .swift 必须同时：① SwiftPM 自动 glob `Qingniao/` 目录（无需改）；② **手动在 project.pbxproj 加 PBXBuildFile + PBXFileReference + PBXGroup children + Sources build phase 四处**。本次新控制器用 `G001...` 前缀 id，放在新建的 `App/Controllers` group。
- **AppState.swift 现已成为死代码**：QingniaoApp 原来靠它注入 SettingsView 的 environmentObject，本次 Settings 场景改 EmptyView 后无人引用。未删（避免动 pbxproj 引用、非 T-006 目标）；可在后续清理任务顺手删（需同步删 pbxproj 三处引用）。
- **SettingsWindowController 用直接 select(route:) 导航**，没订阅 .openManagementCenter；但 ManagementCenterView 自身仍订阅该通知（SearchPanelViewModel/SystemCommandSource 会 post）。AppContainer.handleOpenManagementCenter 收到通知后调 `settingsWindowController.show(route:)`，窗口已存在时再 select 一次——不会递归（控制器不再 post 通知）。
- **命令栏 UI 仍是 SearchPanelView**（T-011 会重写为 Jade 风格 CommandBarView，装进 CommandBarController 即可，无需再动窗口层）。
- **截图 UI 仍是 ScreenshotToolbarController/AnnotationEditorWindow/ScreenshotOverlay**（T-014 重写；ScreenshotWindowController 只搬了编排逻辑，未碰 UI）。
- **Onboarding 显示逻辑保持原样**（单屏化是 T-010）；AppDelegate 仍持 onboardingWindow 并通过 onboardingGate 闭包注入容器。
- api.md v3 里 CommandBarController 要求 `.ultraThinMaterial`、20px 圆角——本任务保留现状（borderless panel + cornerRadius 12 + SearchPanelView 自带外观），材质/圆角属于 T-011 UI 重写范畴，未提前引入。
- api.md 还列了 AnnotationWindowController / ScreenshotOverlayController / GlobalShortcutManager / HotkeyConflictDetector 作为独立类型——本任务按「薄封装、不重写」原则用 ScreenshotWindowController 统一封装现有截图窗口，热键仍用 KeyboardShortcuts 直接注册；独立的 GlobalShortcutManager/冲突检测/全屏热键注册留给热键相关任务。
