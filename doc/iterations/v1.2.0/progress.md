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
