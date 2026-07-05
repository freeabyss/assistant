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

---

## T-007 统一 Jade 组件库（presentation, P1)

### 状态
✅ 完成。`xcodebuild -project Qingniao.xcodeproj -scheme Qingniao -configuration Debug build` → **BUILD SUCCEEDED**。tasks.json T-007 passes=true。

### 新增文件（Qingniao/Views/Components/,均带 light+dark #Preview）
1. `JadeButton.swift` — `JadeButtonStyle: ButtonStyle`,四变体 primary/secondary/destructive/ghost;hover/pressed/disabled 三态;水平 fixedSize。便捷 API `.jadePrimary/.jadeSecondary/.jadeDestructive/.jadeGhost`。primary=primary 底白字、secondary=surface2 底主色前景+border 描边、destructive=systemRed、ghost 透明底 hover 出 surface2。
2. `JadeTextField.swift` — `@Binding<String>`+`LocalizedStringKey` placeholder,可选左图标 `Image?`,右 xmark.circle.fill 清空;`@FocusState` 驱动:focus 1.5pt primary 边框/未 focus 1pt border;JadeRadius.md、JadeFont.body、内边 12×9。
3. `HotkeyRecorder.swift` — 包 `KeyboardShortcuts.Recorder`,jade 圆角/边框/focus primary;**不做冲突检测**(T-008),暴露 `isConflicting: Binding<Bool>`+`conflictMessage: Binding<String?>` 外部传入,冲突时行内红色 exclamationmark.triangle 警告。
4. `JadeListRow.swift` — 泛型 `JadeListRow<Content>`;`selected`(primaryFill 底+lg 圆角)、`rowSize: .compact(44)/.comfortable(64)`、`actions: [JadeRowAction]`(hover 右侧图标按钮组,支持 isDestructive)。附带 `JadeRowAction`/`JadeRowSize` 类型。
5. `JadePill.swift` — 文本胶囊/徽标,6 配色 neutral/primary/info/success/warning/danger(前景色+15% 底);短内容(≤2 字符)/toolbar 用 capsule,其余 JadeRadius.sm;`.regular`/`.toolbar` 尺寸;`JadeBadge` 为其 typealias。
6. `StatCard.swift` — 图标(Image)+值(title1)+标题(LocalizedStringKey),JadeRadius.lg+surface2 底,hover 切 surface3,可选 tint。
7. `PermissionGate.swift` — 空权限态:systemImage+标题+描述+jadePrimary 引导按钮,全部 LocalizedStringKey。
8. `JadeConfirmationDialog.swift` — `View.jadeConfirmationDialog(_:isPresented:confirmTitle:cancelTitle:message:onConfirm:)` helper,封装系统 confirmationDialog 为红色 destructive+cancel 双按钮,不重复造轮子。

### 改写文件
- `ToastView.swift` → **重写为 JadeToast**:变体 .info/.success/.error(各自图标+语义色)、position .bottom/.center、slide+fade、3s 自动消失(error 不自动)。保留旧 `.toast(message:isShowing:)` 签名(内部转 JadeToastModifier,.info/.bottom)兼容现有调用;新增完整版 `.jadeToast(_:isShowing:variant:position:)`。
- `ScreenshotToolbarController.swift` → 删除内联 toast TODO,改用 `JadeToast(toast, variant:.info)`(该预览是独立 NSHostingView,直接渲染 JadeToast,自动消失仍由 ScreenshotPreviewViewModel.showToast 处理)。

### pbxproj
- 手工加 9 个文件(8 新增+ToastView 已存在无需重复),用 **F007 前缀** UUID(对齐 Design 层 F004 惯例)。四处:PBXBuildFile(F007...101-108)、PBXFileReference(F007...001-008)、PBXGroup Components children、PBXSourcesBuildPhase。

### commit（3 次)
1. `feat(T-007): 新增 Jade 组件库 8 个组件`
2. `feat(T-007): 重写 ToastView 为 JadeToast + 迁移截图内联 toast`
3. `build(T-007): 注册 9 个 Jade 组件文件到 Qingniao.xcodeproj`
（+本次 progress/tasks 记录 commit）

### 留给后续 agent 的提示
- **本任务只做组件本身,未把现有 View 切到新组件**(那是 T-015)。例外:ToastView 被就地重写(API 兼容)+ ScreenshotToolbar 内联 toast 已迁移。
- **HotkeyRecorder 冲突检测是 T-008**:组件只渲染 isConflicting/conflictMessage,检测逻辑由 T-008 监听 KeyboardShortcuts 变更后写入 binding。Recorder 无原生 focus 回调,当前用 onHover 近似高亮,T-008 若需精确 focus 态可再增强。
- **JadePill capsule 判定**用 `text.count <= 2`(计数/短徽标),中文字符也按 count 计;如需更精确可换度量。
- pbxproj 仍是手工 group 型工程,新增 .swift 记得四处接线(SwiftPM 侧 glob 自动)。

---

## T-008 全局快捷键管理（全屏热键 ⌃⌥⌘3 + 冲突检测 + 默认键修正, services, P0)

### 状态
✅ 完成。`xcodebuild -project Qingniao.xcodeproj -scheme Qingniao -configuration Debug build` → **BUILD SUCCEEDED**。新增 8 个单测全绿。tasks.json T-008 passes=true。

### 快捷键默认值清单（PRD §9.6 / FR-UI-HOTKEYS，均用户可重绑）
| Name | 功能 | 默认键 | 说明 |
|------|------|--------|------|
| togglePanel | 打开命令栏 | ⌥ Space | 保留 |
| captureRegion | 区域截图 | ⇧⌃⌘4 | 修正（原 ⇧⌘A） |
| captureWindow | 窗口截图 | ⇧⌃⌘5 | 修正（原 ⇧⌘W） |
| captureFullscreen | 全屏截图 | ⌃⌥⌘3 | **新增** |
| openClipboardHistory | 剪贴板历史 | ⌥⌘C | **新增** |
| openSettings | 打开设置 | ⌥⌘, | **新增** |

### 新增文件
1. `Qingniao/Services/Hotkey/GlobalShortcutManager.swift`（@MainActor）— 统一注册 6 个热键回调（setupShortcuts / registerXxx / unregisterAll / resetAllShortcutsToDefaults / refreshConflicts）。全屏截图接 `ScreenshotWindowController.captureFullScreen()`（内部走既有 `ScreenshotService.captureScreen()`，命名保持不动，仅在 controller 层用 captureFullScreen 别名编排）；剪贴板历史接 `clipboardHistoryWindowController.show()`；设置接 `settingsWindowController.show(route:.settings)`。持有 `conflictDetector`。
2. `Qingniao/Services/Hotkey/HotkeyConflictDetector.swift`（@MainActor, ObservableObject）— 基础版冲突检测：①与启用中的 macOS 符号热键冲突（复用 `HotkeyValidationService.enabledSystemShortcuts`）②我方 6 个热键之间重复绑定。`@Published conflictingNames: Set<Name>` + `conflictMessages: [Name:String]`。`scan()` 全量刷新；`evaluate(_:for:)` 单键评估返回 `.registered/.conflict(String)`。附 `HotkeyAction`（含 name 映射 + init?(name:)）与 `HotkeyRegistrationOutcome`（对齐 api.md §17）。init 为 nonisolated 以便默认参数求值。
3. `QingniaoTests/HotkeyConflictDetectorTests.swift` — 8 测试：6 项默认值断言（SHORTCUT-001..004）、managedGlobalShortcuts 覆盖 6 槽、HotkeyAction<->Name 往返、系统冲突/内部重复 flagged、evaluate free/system。

### 改写文件
- `Qingniao/Utilities/KeyboardShortcuts+Names.swift` — 修正 captureRegion/Window 默认键，新增 captureFullscreen/openClipboardHistory/openSettings，新增 `static managedGlobalShortcuts: [Name]`（6 项）。
- `Qingniao/App/Controllers/AppContainer.swift` — 注入 `globalShortcutManager` lazy 依赖。
- `Qingniao/App/AppDelegate.swift` — 删除内联 3 键注册，改为 `container.globalShortcutManager.setupShortcuts()`；移除已无用的 KeyboardShortcuts import。
- `Qingniao/ViewModels/SettingsViewModel.swift` — 注入 HotkeyConflictDetector；新增 `@Published conflictWarnings: [Name:String]`、`isShortcutConflict(_:)`、`conflictMessage(for:)`、`refreshShortcutConflicts()`、`resetAllShortcutsToDefaults()`（**供 T-013 绑定**）；`load()` 末尾刷新冲突。
- `Qingniao/Views/Settings/SettingsView.swift` — 快捷键 section 补齐 6 项行，shortcutRow 加 name 参数：录制变更 onChange 刷新冲突 + 行内红色 exclamationmark.triangle 警告；重置按钮改走 `viewModel.resetAllShortcutsToDefaults()`。（未重写 UI，符合任务约束）
- `Qingniao/Resources/Localizable.xcstrings` — 新增 management.shortcuts.captureFullscreen/clipboardHistory/openSettings + conflict.system/conflict.internal + shortcuts.reset（en/zh-Hans）。
- `Qingniao.xcodeproj/project.pbxproj` — C014 前缀 UUID 接线 3 个新文件（2 源 + 1 测试），四处：PBXBuildFile / PBXFileReference / PBXGroup / PBXSourcesBuildPhase。

### 暴露给 T-013 的 API（SettingsViewModel）
- `@Published var conflictWarnings: [KeyboardShortcuts.Name: String]`
- `func isShortcutConflict(_ name: KeyboardShortcuts.Name) -> Bool`
- `func conflictMessage(for name: KeyboardShortcuts.Name) -> String?`
- `func refreshShortcutConflicts()` — 录制变更后调用
- `func resetAllShortcutsToDefaults()` — “重置为默认”按钮
- 冲突文案 key：`management.shortcuts.conflict.system` / `management.shortcuts.conflict.internal`
- T-007 的 `HotkeyRecorder` 组件已备好 `isConflicting`/`conflictMessage` binding，T-013 可用 `isShortcutConflict`/`conflictMessage` 驱动。

### commit（3 次）
1. `feat(T-008): GlobalShortcutManager + HotkeyConflictDetector service layer`
2. `feat(T-008): expose shortcut conflict API to settings + inline warnings`
3. `test(T-008): HotkeyConflictDetectorTests + pbxproj registration`
（+本次 progress/tasks 记录 commit）

### 留给后续 agent 的提示
- **持久化**：KeyboardShortcuts 库自动经 UserDefaults 存用户自定义键，未自写持久化。
- **⌥Space 与 Spotlight**：仅在设置页显示冲突提示，**未在代码里自动改键**（按任务约束）。检测依赖“启用中的系统符号热键”列表，Spotlight 是否被检出取决于系统是否将其登记为 symbolic hotkey。
- **全屏截图命名**：ScreenshotService 协议方法仍是 `captureScreen()`，未改名；controller 层 `captureFullScreen()` 已是既有别名，GlobalShortcutManager 直接调它。
- **HotkeyConflictDetector 有两个实例**：GlobalShortcutManager 持一个（用于启动期日志/刷新），SettingsViewModel 持一个（用于 UI）。二者都基于同一份 UserDefaults 持久化状态，读值一致；如需单例可后续收敛，但当前无状态共享问题（纯读 + @Published 各自驱动各自 UI）。
- **预存在失败**：`FileSearchSourceTests` 3 处 `/var` vs `/private/var` 软链路径断言失败，属 FileSearchSource 任务遗留（工作区未提交改动），与 T-008 无关，未处理。

---

## T-009 文件搜索接入 FileSearchSource（2026-07-05）

### 完成内容
将 `FileSearchSource` 从旧的 Spotlight/`NSMetadataQuery` + 拼音实现重写为**固定三目录 + FileManager 一次性内存缓存**方案，并接入 `SearchService`。⌥Space 现在能搜到 `~/Desktop`、`~/Documents`、`~/Downloads` 下文件，⏎ 打开、⌘R Finder 显示、⌘C 复制路径，权重 75。

### 改写/新增文件
- `Qingniao/Services/SearchEngine/FileSearchSource.swift` — 完全重写：
  - 默认索引根 `~/Desktop`、`~/Documents`、`~/Downloads`（`defaultRoots(home:)`，`SettingKey.fileSearchPaths` 扩展点预留，v1.2 固定）。
  - 构造时 `Task.detached(.utility)` 后台 `FileManager.enumerator` 一次性遍历建缓存 `[FileIndexItem]`（name/path/normalizedName/normalizedPath/uti/size/mtime）；完成后发 `.fileSearchIndexReady`。首次查询若索引未就绪则懒加载 `rebuildIndex()`，不阻塞其他源（SearchService 并发 fan-out）。
  - 排除：隐藏文件/目录（`.skipsHiddenFiles`）、bundle 包内部（`.skipsPackageDescendants`）、bundle 本体（`isPackage`）；深度上限 `maxDepth=8`；文件数上限 `maxIndexedFiles=100_000`。
  - 匹配:大小写 + 变音符 + 全半角不敏感（folding），名称 exact/prefix/contains + 路径 contains 四档 + 最近修改加分；**无拼音**（FR-SEARCH-13）；≥2 字符触发（FR-SEARCH-17）。
  - `FileIndexItem` 结构体取代旧 `FileInfo`；`FileSearchSourceProtocol` 契约改为 `indexedRoots` + `rebuildIndex()`（对齐 api.md §5）。
  - 结果 `SearchResult`：title=文件名、subtitle=`~相对目录 · 大小`、icon=`.appIcon(url)`(经 NSWorkspace 取系统文件图标)、typeLabel=`searchPanel.type.file`(文件/File)、baseScore=`SourcePriority.file`=75、primary=`.openFile`、secondary=`[.revealInFinder, .copyText(path)]`。
- `QingniaoTests/FileSearchSourceTests.swift`（新增，10 条测试，全部临时目录，不扫用户家目录）：索引三目录、搜索结果+动作、权重 75、≥2 字符触发、isEnabled 开关（用 Mock SettingsService 避免 Core Data 并发争用）、大小写/变音不敏感、prefix > contains 排序、跳过隐藏文件、不索引 bundle 内容、默认三目录。

### 被并发 T-008 提交顺带纳入的改动（非本次单独 commit，但属 T-009 接线）
以下文件在本任务执行期间被并发运行的 T-008 流程的 commit 一并提交（内容为 T-009 接线，已核对无误）：
- `Qingniao/App/Controllers/AppContainer.swift` — 新增 `private let fileSearchSource = FileSearchSource()`；`makeSearchPanelViewModel` 里 `SettingsBackedSearchSource(..., settingKey: .fileSourceEnabled)` 包装并加入 `sources` 数组（第 5 位，clipboard 之前）。
- `Qingniao/ViewModels/SettingsViewModel.swift` — 搜索源开关新增「文件」项（`.file` / `.fileSourceEnabled` / icon `doc`）；`resetSettingsToDefaults` 列表补 `.fileSourceEnabled`。
- `Qingniao/Resources/Localizable.xcstrings` — 新增 `searchPanel.type.file`、`management.source.file`、`management.source.file.subtitle`（en/zh-Hans）。
- `Qingniao.xcodeproj/project.pbxproj` — FileSearchSource.swift 补进 Qingniao target 的 PBXBuildFile + Sources 构建阶段（此前只有 group 引用，从未编译进 target，这正是它"从未被实例化"的根因之一）；FileSearchSourceTests.swift 加入 QingniaoTests target 四处接线。

### 说明 / 遗留
- `SettingKey.fileSourceEnabled` 及默认值 `"true"`、`SearchAction.openFile/.revealInFinder`、`SearchResultIcon` 渲染均已存在（T-005/前序任务已备），本次直接复用，未改 UI（SearchPanelView 仍走 `.appIcon` 分支渲染文件图标，符合"不改 UI"约束，交 T-011）。
- v1.2 不做 FS 监听/增量索引、不做拼音、不做内容全文检索（均按约束）。
- build Debug SUCCEEDED；xcodebuild test 全绿（142 tests, 0 failures，含新增 10 条 FileSearchSourceTests）。
- 修复了 T-008 progress 中提到的 `FileSearchSourceTests` `/var` vs `/private/var` 软链断言问题（改为按 lastPathComponent/resolved path 比较）。

---

## T-010 Onboarding 单屏重构（辅助功能按需 + 屏幕录制前置）（2026-07-05）

### 完成内容
将旧的 7 步向导 Onboarding 重构为 PRD §9.4 P-06 单屏布局（720×520），辅助功能权限由强制改为按需（`onDemandAccessibilityCheck()`），屏幕录制作为主流程前置（可「暂不开启截图」跳过），完成后写 `onboarding.completedAt` 时间戳，重启不重弹（AC-6）。

### 改写/新增文件
- `Qingniao/Services/Permissions/PermissionService.swift` — 协议 + 实现新增 `@MainActor onDemandAccessibilityCheck() -> Bool`：已授权直接返回 true；未授权弹 NSAlert（说明用途 + 「打开系统设置」/「取消」），点「打开系统设置」调 `openSystemSettings(for: .accessibility)`（内部走 `requestAccessibilityPromptIfNeeded` + 打开隐私页）。Onboarding **不**触发辅助功能 TCC。
- `Qingniao/ViewModels/OnboardingViewModel.swift` — 完全重写为单屏状态机：移除 `OnboardingStep`/`step`/`continueToNextStep`/`completeIfPossible`/`canContinueCurrentStep`。新状态：`hotkeyValidation`、`clipboardEnabled`(默认 true)、`launchAtLoginEnabled`(默认 false)、`screenRecordingAuthorized`、`screenshotSkipped`、`completionErrorMessage`。核心规则 `canStart = screenRecordingAuthorized || screenshotSkipped`（简单明确，不卡死）。`requestScreenRecording()` 触发 TCC 并刷新；`skipScreenshot()` 置跳过；`start()` 写 hotkey+clipboard+launchAtLogin+`markCompleted()`；`skipOnboarding()` 显式写 `clipboardEnabled=false`+`markCompleted()`。`markCompleted()` 写 `onboardingCompletedAt`(ISO8601 时间戳) + legacy `onboardingCompleted=true`（双写，兼容旧读取路径）。构造函数新增可注入 `now: () -> Date`。
- `Qingniao/Views/Onboarding/OnboardingView.swift` — 完全重写为单屏：VStack 720×520 + `JadeRadius.xl` + `JadeShadow.xl` + padding x8（32）。顶部 SF Symbol `bird` 80pt jade 色 + display 标题 + body 副标题；中段 3 张 `surface2` + `JadeRadius.md` 卡片（HotkeyRecorder 绑 `.togglePanel` / 剪贴板 Toggle / 开机启动 Toggle，均 tint primary）；屏幕录制段（说明 + primary「授予屏幕录制权限」/ ghost「暂不开启截图」，已授权显示「已授予 ✓」success）；辅助功能段（说明 + ghost「稍后再说」）；footer（ghost「跳过设置」带 `jadeConfirmationDialog` / primary「开始使用」disabled=`!canStart` / Link「隐私政策」）。全 token 化，无硬编码。#Preview 更新为单屏 Light/Dark。
- `Qingniao/App/Controllers/AppContainer.swift` — `loadOnboardingCompletionState()` 改为优先读 `onboarding.completedAt`（非空即完成），回落 legacy 布尔（AC-6 重启不重弹核心）。
- `Qingniao/App/AppDelegate.swift` — onboarding 窗口 680→720 宽；`OnboardingViewModel(onComplete:)` 显式标签。
- `Qingniao/Resources/Localizable.xcstrings` — 新增 17 键（en + zh-Hans）：onboarding.hotkey.title / clipboard.toggle(.subtitle) / launchAtLogin.toggle.subtitle / screenRecording.explain/.grant/.granted/.skip/.skipped / accessibility.explain/.later / start / error.screenRecordingRequired / permission.onDemand.accessibility.title/.message/.openSettings/.cancel。
- `QingniaoTests/OnboardingViewModelTests.swift` — 重写为单屏断言（12 条）：canStart 规则、skipScreenshot、requestScreenRecording 触发一次、onboarding 全程 0 次辅助功能申请、start 被 canStart 阻塞、start 写 completedAt+legacy+settings+launchAtLogin、clipboard=false 分支、skipOnboarding 写 false、hotkey 持久化、onAppear 刷新。MockPermissionService 补 `onDemandAccessibilityCheck` 计数替身。
- `QingniaoTests/PermissionServiceProtocolConformanceTests.swift` — 补 PERM-OD-003：Mock/Static 两 conformer 的 `onDemandAccessibilityCheck` 断言（编译即验证真实服务已实现）。
- `QingniaoTests/SettingsSourceTests.swift` — `StaticPermissionService` 补 `onDemandAccessibilityCheck`。

### 验证
- `xcodebuild -scheme Qingniao -configuration Debug clean build` → **BUILD SUCCEEDED**。
- `xcodebuild ... test`（隔离 worktree @HEAD，干净 derivedData）→ **All tests passed / TEST SUCCEEDED**，140 test case 全绿，含 12 条 OnboardingViewModelTests + PERM-OD-003 conformance。
- disabled 规则正确：屏幕录制未授权且未点「暂不开启截图」时「开始使用」disabled；授权后或点跳过后 enabled（`test_canStart_*` 覆盖）。
- AC-6（重启不重弹）：`start()`/`skipOnboarding()` 写 `onboarding.completedAt` 时间戳；`AppContainer.loadOnboardingCompletionState()` 优先读该键非空即完成 → 重启 `isOnboardingCompleted=true` 直接进主界面，不再 `showOnboardingWindow()`。单测 `test_start_writesSettingsAndCompletedAt` / `test_skipOnboarding_writesFlagsAndInvokesCompletion` 断言 completedAt 非空。手工 E2E（重启真实验证）留待手工测试。

### 重要提示（留给后续 Agent）
- **并发施工冲突**：本任务执行期间，另一 Agent 在同一工作树并行处理 T-011（CommandBar）/T-012（剪贴板 UI，`isFavorite` 特性）。T-010 的源码改动（OnboardingView/ViewModel/PermissionService/AppContainer/xcstrings/SettingsSourceTests）被对方的 commit `3e5c445`（"T-011 rename"）**顺带一起提交**进 HEAD。本 Agent 的独立 commit `7fc70c1` 仅含剩余的测试重写 + AppDelegate onComplete 标签。两部分合起来即完整 T-010，功能与测试均已闭环。
- 对方未提交的 `isFavorite` WIP（PersistenceController/AssistantClipboardRepository/InMemorySearchIndex + Mock 未补 `toggleFavorite`）会让**工作树当前 test build 失败**，但那是 T-012 未完成状态，与 T-010 无关；隔离 worktree @HEAD 验证证明 T-010 代码本身 build+test 全绿。
- 辅助功能按需申请的**调用点接线**（在自动粘贴/模拟快捷键等能力首次触发时调 `onDemandAccessibilityCheck()`）本任务未接（这些能力属未来功能，v1.2 无实际触发点）；PERM-OD-002 的端到端 Alert 手工验证留待有真实触发点时。

---

## T-012 剪贴板历史窗口（P-02 重写）+ RecentContent 改造（2026-07-06）

### 状态
✅ 完成。`xcodebuild -project Qingniao.xcodeproj -scheme Qingniao -configuration Debug build` → **BUILD SUCCEEDED**。剪贴板相关测试全绿（ClipboardListViewModelTests 4 + AssistantClipboardRepositoryTests 10 + InMemorySearchIndexTests 5 + DatabaseManagerTests 4 = 23/23）。tasks.json T-012 passes=true。

### 数据层（isFavorite 全链路）
- `PersistenceController`：ClipboardRecord 实体新增 `isFavorite`（Bool，默认 false，`shouldMigrateStoreAutomatically` 已开，轻量迁移自动加列）；`CDClipboardRecord` 加 `@NSManaged var isFavorite`。
- `AssistantClipboardRepository`：`ClipboardRepositoryProtocol` 新增 `toggleFavorite(id:)`；`ClipboardRecordSnapshot` 加 `isFavorite`；`makeSnapshot` 回填；`cleanupExpired` 谓词改 `isPinned == NO AND isFavorite == NO`（收藏与置顶都免清理）。
- `InMemorySearchIndex`：`SearchIndexItem` 加 `isFavorite`；两处构造器（snapshot / CDRecord）同步；`IndexingClipboardRepository` 新增 `toggleFavorite`（转发 base + upsert 索引）。

### ViewModel（ClipboardListViewModel 重写）
- `Filter` 枚举 → `SidebarSelection`（typeCases: 全部/文本/图片/富文本/文件；specialCases: 置顶/收藏；timeCases: 今天/昨天/更早）。类型段约束 index 查询的 contentType；special/time 段加载全部后按 `includes(_:)` 后置过滤（时间用 `Calendar.isDateInToday/Yesterday`）。
- 新增：`toggleFavorite`、多选 `selectedIDs`/`selectAll`/`deleteSelected`、`previewItem`（sheet 驱动）、`enableClipboard`（写 `.clipboardEnabled=true` + post `.settingsDidChange`）、`retentionDays`/`clipboardEnabled` 运行态（`refreshRuntimeSettings` 读 SettingsService，load 时刷新）、`richTextData(for:)`。
- 注入新增可选 `settingsService`（默认 `SettingsService(.shared)`）。订阅 `.settingsDidChange` 刷新运行态。

### 视图
- **JadeClipboardRow.swift（新）**：合并旧 `ClipboardItemRow` + `ClipboardHistoryRow`。基于 `JadeListRow` comfortable(64)，40×40 radius-md 缩略图（图片→thumbnail、文本→首字、其余→SF Symbol），主标题 lineLimit 1 + 置顶/收藏/失败角标，副信息 `类型 · 大小 · 时间`；hover 右侧 4 个 action（置顶/复制/预览/删除）。删除旧 `ClipboardItemRow.swift`（含 RTFPreviewView，无其他引用）。
- **ClipboardHistoryView.swift（新，取代 ClipboardListView.swift）**：`NavigationSplitView`，侧栏 180pt（三段 List + `.safeAreaInset(.bottom)` 清空全部[jadeDestructive]/设置[jadeGhost]），detail = JadeTextField 搜索 + 总数 JadePill + LazyVStack(JadeClipboardRow) + Divider + 状态栏（`X 条 · 已用 X · 保留 X 天`）。空态三种（首次 tray / 关闭 hand.raised.slash+[开启] / 搜索无结果 magnifyingglass）。swipeActions（左滑收藏 .yellow / 右滑删除 .red）、contextMenu（复制/预览/置顶/收藏/删除/清空）。sheet 挂 PreviewPanel。JadeConfirmationDialog 清空确认。
- **PreviewPanel.swift（改造）**：入参从旧 `ClipboardItem`(GRDB) → `ClipboardRecordSnapshot`，图片/RTF 走异步 provider（`.task(id:)` 懒加载）；`NSTextView` 已是 guard（保留）；删除/复制按钮换 `.jadeDestructive`/`.jadePrimary`，Finder 按钮 `.jadeSecondary`；图片 MagnificationGesture 0.5–5x 保留。

### 快捷键实现清单（ClipboardHistoryView.keyboardShortcuts，隐藏按钮 + keyboardShortcut，macOS 13 兼容）
- ⌘F 聚焦搜索框（@FocusState）；⌘A 全选（selectedIDs=全部）；↑↓ 与 j/k 移动光标；⏎ 与 ⌘C 复制选中并关闭窗口（onCopyAndClose→window.close）；空格 与 ⌘Y 打开 PreviewPanel sheet（空格在搜索框聚焦时不触发）；⌫ 删除选中（搜索聚焦时不触发）。
- 点击行：复制并关闭窗口。

### 接线
- `ClipboardHistoryWindowController.show()`：改建 `ClipboardHistoryView`，注入 `onCopyAndClose`（window.close）+ `onOpenSettings`（settingsWindowController.show(.settings)）。
- `SettingsView.ManagementCenterView` 剪贴板页：`ClipboardListView` → `ClipboardHistoryView`。
- `Localizable.xcstrings`：新增 clipboard.filter.rtf/pinned/favorite/today/yesterday/earlier、clipboard.sidebar.types/special/time、clipboard.status.summary/retentionDays/retentionForever、clipboard.empty.disabled.title/enable（en + zh-Hans）。

### RecentContentView 决策
- **删/留**：无需删除。全工程（Qingniao + QingniaoTests + pbxproj）grep 无 `RecentContentView`/`RecentContentViewModel` 任何引用，文件本身也不存在（早期迭代已移除）。ClipboardHistoryView 即 P-02 唯一浏览/筛选/搜索/操作入口。

### pbxproj
- 手工 rename：A10000...012 ClipboardListView.swift→ClipboardHistoryView.swift、A10000...013 ClipboardItemRow.swift→JadeClipboardRow.swift（PBXBuildFile/PBXFileReference/PBXGroup/Sources 四处，复用原 UUID）。

### commit
- `6c8174f feat(T-012): 剪贴板历史窗口 P-02 重写 + isFavorite 数据链路`（单次 commit：因工作树被并发 T-011 Agent 占用，仅暂存本任务自有文件 + 仅含剪贴板 rename 的 pbxproj，避免混入对方 WIP）。

### 留给后续 Agent 的提示（重要）
- **并发施工**：本任务执行期间，另一 Agent 在同一工作树并行处理 **T-011（CommandBar）**，其未提交 WIP 包括 `CommandBarView.swift`(+433/-152)、`SearchPanelViewModel.swift`(+203)、`AppSearchSource.swift`、`CommandBarController.swift` 及新文件 `CommandBarHomeProvider.swift`。这些**未纳入**本次 commit，仍留在工作树未暂存，交 T-011 Agent 提交。
- **工作树 test build 当前失败**：`CommandBarController.swift:134` 引用尚不存在的 `SearchPanelView`（T-011 把 SearchPanelView 改名 CommandBarView 的过程未完成）。该失败**属 T-011 WIP，与 T-012 无关**——本任务的 `xcodebuild build`（app target）SUCCEEDED，且剪贴板相关 test 单独跑全绿。T-011 Agent 完成 rename 后 test build 会恢复。
- **本次 commit 的自洽性**：commit `6c8174f` 未引用任何 T-011 符号（`settingsWindowController.show`、`makeClipboardListViewModel` 在 HEAD 已存在），单独 checkout 即可 build。
- **isFavorite 迁移**：靠 Core Data 轻量迁移自动加列（已有库升级无损）；无手写 mapping model。
- **PreviewPanel 未做全量 Jade 迁移**：按任务约束只修强解包 + 换按钮 + 接 snapshot，T-015 会做全量样式迁移。

---

## T-011 Command Bar 重写（P-01，presentation, P0）（2026-07-03）

### 状态
✅ 完成。隔离 worktree（基于 HEAD，避免并发 T-012 未提交改动干扰）内 `xcodebuild -project Qingniao.xcodeproj -scheme Qingniao -configuration Debug build/test` → **BUILD SUCCEEDED / TEST SUCCEEDED（148 tests, 0 failures）**。tasks.json T-011 passes=true。

### 文件 rename
- `Qingniao/Views/SearchPanel/SearchPanelView.swift` → `CommandBarView.swift`（git mv + pbxproj 四处同步：PBXBuildFile/PBXFileReference/group/Sources，UUID B011...0003/0004 复用，仅改 path/注释）。
- `SearchPanelView`(struct) → `CommandBarView`；`SearchPanelResultRow` → `CommandBarResultRow`。
- **ViewModel 保留原名 `SearchPanelViewModel`**（扩展而非改名，减少 4 处引用面 + 测试改动；类型仍是命令栏后端）。

### 新增文件
- `Qingniao/Services/SearchEngine/CommandBarHomeProvider.swift` — 空态 home 内容聚合器（薄只读）：
  - `recentResults(limit:)`：读 `UsageStatRepository.recentlyUsed`（按 `lastUsedAt` 降序），按 targetType 解析为 app（经 AppSource.index 拿当前 path/名）/命令（catalog 查表）result；过量取 3×limit 容忍已卸载 app/未知命令。
  - `favoriteResults(limit:)`：`clipboardRepository.fetchHistory` 取 `isPinned` 记录（v1.2 D-036 只做置顶，无 favorites/tags；**注意**：working tree 里并发 T-012 给 snapshot 加了 `isFavorite`，本 provider 为对齐 HEAD 基线只依赖 `isPinned`，T-012 落地后可加 `|| isFavorite`）。
  - `CommandBarHomeProviding` 协议 + `StubHomeProvider` 测试替身。
  - pbxproj C011 前缀接线（4 处）。

### 改写文件
- `Qingniao/ViewModels/SearchPanelViewModel.swift`：
  - `CommandBarSource`(⌘1-6 枚举 all/app/command/clipboard/file/settings) + `activeSource` + `visibleResults`(按源过滤，calculator 归 all)。
  - home：`recentResults/favoriteResults/hasHomeContent/loadHomeContent()`；`open()` 触发加载；空 query searchNow 也刷新 home。
  - 危险命令：`isDangerous`(clearClipboardHistory/restartFinder/restartDock)、`trigger`(危险→`pendingDangerResult`,否则执行)、`confirmPendingDanger/cancelPendingDanger`。
  - `copyCurrentValue()`(⌘C：copyText/openFile/revealInFinder/app path/clipboard title→pasteboard,不执行,toast「已复制」)；`clearInput()`(⌘K)；`openSettings()`(⌘,)；`isCalculatorTopResult`(calculator 且 visibleResults 首行)。
  - **init 参数顺序**：`onOpenSettings` 放 `onClose` **之前**，保证尾随闭包仍绑定 `onClose`（否则 `SearchPanelViewModelTests.testConfirmSelection...` 的 `didClose` 尾随闭包会误绑到 onOpenSettings → 该测试一度红）。
- `Qingniao/Services/SearchEngine/AppSearchSource.swift`：`UsageStatRepositoryProtocol` + `UsageStatRepository` 新增 `recentlyUsed(limit:)`。
- `Qingniao/App/Controllers/AppContainer.swift`：`makeSearchPanelViewModel` 注入 `CommandBarHomeProvider` + `onOpenSettings`(settingsWindowController.show(route:.settings))。
- `Qingniao/Views/SearchPanel/CommandBarView.swift`：全新 P-01 Jade 视图（见下）。
- `Qingniao/App/Controllers/CommandBarController.swift`：NSPanel 680 宽 / 动态高 120-560 / y+120 居中；`titleVisibility=.hidden`、`titlebarAppearsTransparent=true`、`isOpaque=false`、`backgroundColor=.clear`、`isMovableByWindowBackground=true`、加 `.nonactivatingPanel`；圆角/material 交给 SwiftUI（`jadeMaterial(.commandBar, radius:.xxl)` + `jadeShadow(.xl)`），去掉旧 layer.cornerRadius=12。hosts `CommandBarView`。
- `Qingniao/Views/Components/AutoFocusTextField.swift`：仅更新注释（CommandBarView 改用原生 TextField + @FocusState）。
- `QingniaoTests/SearchPanelViewModelTests.swift`：+5 测试（切源过滤 / 危险命令二次确认 / ⌘C 复制不执行 / 计算器首行 / home 加载），+import AppKit。

### P-01 UI 要点（CommandBarView）
- VStack(spacing 0)：48px 输入框（jade 放大镜 focus 主色、commandBarInput 20pt、ProgressView/清空）→ Divider(border) → content → Divider → 44px hint bar；`.frame(width: 680)`。
- 结果行 44px：32×32 类型图标底（类型色 15%，PRD §9.2.9：app blue/command purple/calculator jade/convert pink/settings indigo/clipboard orange/file green），title3 主标题 + subhead 副标题 + 类型 badge（类型色 15% 底）+ ⏎；选中 `JadeColor.primaryFill` + `JadeRadius.lg` + 图标转主色。
- 空态两 section（最近使用/收藏，subhead 标题）；无结果 magnifyingglass + 「未找到匹配项」+「尝试换个关键词或检查搜索源设置」(§9.7)；home 全空 fallback sparkles+placeholder。
- ⌘1-6/⌘K/⌘C/⌘, 用隐藏 `Button().keyboardShortcut(...)` 层（opacity 0 / 不 hit test / a11y hidden）——**优先 SwiftUI .keyboardShortcut 而非 NSView 拦截**；↑↓⏎⎋ + Tab 唯一前缀补全仍走保留的 `KeyEventHandler`。
- 危险命令 ⏎ → `jadeConfirmationDialog`（标题=命令名、confirm「确认执行」、message「此操作可能不可撤销…」）。

### ⌘1-6 实现方式
`CommandBarView.shortcutButtons`：`ForEach(CommandBarSource.allCases)` 生成 6 个隐藏 Button，`.keyboardShortcut(KeyEquivalent("\(rawValue)"), modifiers: .command)` → `viewModel.selectSource(source)` 设 `activeSource`，`visibleResults` 计算属性据此过滤（`CommandBarSource.matches`）。sources 无需 controller 额外传入——过滤在 ViewModel 层对既有 `results` 做，`SearchService` 仍聚合全部源。

### 空态「最近/收藏」数据来源
- 最近使用：Core Data `CDUsageStat`（app 启动/命令执行的 useCount + lastUsedAt，本地记录，FR-SEARCH-10/10a），`recentlyUsed` 按 lastUsedAt 降序，解析回 app（AppSource 索引取当前 path）/命令（catalog）。
- 收藏：`AssistantClipboardRepository.fetchHistory` 的 `isPinned` 剪贴板记录（置顶排前）。

### commit（4 次 + 本次记录）
1. `refactor(T-011): rename SearchPanelView.swift → CommandBarView.swift`
2. `feat(T-011): 命令栏 ViewModel 扩展 + 最近/收藏 home provider`
3. `feat(T-011): CommandBarView P-01 Jade 重写 + NSPanel 680/20px/毛玻璃`
4. `docs(T-011): 更新 AutoFocusTextField 注释`

### 留给后续 agent 的重点提示
- **⚠️ 并发 T-012（剪贴板重写）在 working tree 有未提交改动**（ClipboardListView→ClipboardHistoryView、ClipboardItemRow→JadeClipboardRow，pbxproj 已在 HEAD 引用新名，但新 .swift 文件未提交 + AssistantClipboardRepository 加了 snapshot.isFavorite）。**主仓 xcodebuild 当前会因这些未提交文件失败**——这不是 T-011 的问题。本任务的 build/test 是在**基于 HEAD 的隔离 worktree**里把「我的文件 + T-012 working-tree 文件」一起 copy 进去验证通过的（148 tests 0 fail）。T-012 提交后主仓即可正常 build。
- Localizable.xcstrings 的全部 `commandBar.*` key（placeholder/section.recent/favorites/noResults.*/source.*/danger.*/hint/enter/copied/indexing）**HEAD 已存在**（早前任务预置），本任务未改 xcstrings（我一度重排后又 `git checkout` 还原，零改动）。
- `isCalculatorTopResult` 依据「calculator 源且排在 visibleResults 首行」判定（未新增 SearchResult flag，靠 SearchService 现有排序把 calculator matchScore=30 顶上去）。
- Tab 补全为「唯一标题前缀匹配」补全；未做多结果公共前缀补全。
- Loading：输入框内 `isLoading` 显示 ProgressView；FileSearchSource 索引态未单独在命令栏画 ProgressView（可后续接 `.fileSearchIndexReady` 通知），`commandBar.indexing` key 已备。
