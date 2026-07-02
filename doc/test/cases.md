# Mac Super Assistant（Assistant）v1.0.0 测试用例

> 本文件为 v1.0.0 迭代的测试用例与测试方案定义（测试目标、分层、用例定义：Case ID、前置条件、步骤、期望结果、优先级）。执行结果与统计见同目录 [report.md](report.md)。

## 版本记录

| 版本 | 上线日期 | 说明 |
|------|---------|------|
| v1.0.0 | 2026-07-02 | 首次上线，Mac Super Assistant MVP（22 个用户故事） |

## 修订记录

| 日期 | 修改人 | 备注 |
| :--- | :--- | :--- |
| 2026-06-11 | Claude | 重写为当前 Mac Super Assistant / Assistant MVP 测试方案，对齐 `doc/prd.md` |
| 2026-07-02 | Claude | v1.0.1：新增 TC-U-001（常量断言）/TC-U-002（checkNow spy）2 条自动化用例 + TC-M-001/002/003 手工验收记录 |

---

## 1. 测试目标

Mac Super Assistant（工程内部代号：Assistant）是 macOS 原生效率工具，MVP 核心能力包括统一搜索入口、应用启动、剪贴板历史、截图与轻量标注、内置命令、计算/单位换算、设置与权限管理。

测试目标：

1. **验证核心用户路径可用**：首次 Onboarding 后，用户可以通过 `⌥ Space` 使用搜索、剪贴板、截图和内置命令。
2. **保护本地数据链路**：剪贴板监听、Core Data 持久化、文件系统大对象、内存索引、去重、清理策略必须稳定。
3. **验证搜索体验**：Provider 聚合、拼音搜索、排序评分、最近使用加权、黑名单过滤必须符合 PRD。
4. **验证权限和隐私边界**：屏幕录制和辅助功能权限必须强制完成；剪贴板默认开启但需用户确认知晓；数据默认仅本地保存。
5. **控制高风险操作**：内置命令只允许白名单；需要确认的命令必须弹确认；不执行任意 shell。
6. **支持发布级体验**：中英文、本地化、关于页、隐私政策、反馈邮件、检查更新、官网/项目主页信息完整。

---

## 2. 测试分层

| 层级 | 范围 | 策略 | 运行方式 |
| :--- | :--- | :--- | :--- |
| 单元测试 | 搜索评分、Provider、拼音、计算器、单位换算、hash、黑名单、使用统计 | 尽量抽离纯 Swift 逻辑测试 | XCTest / Swift Testing |
| 数据集成测试 | Core Data 模型、剪贴板记录、去重、置顶、保留时间、资源路径 | 使用临时 Core Data store 和临时文件目录 | XCTest |
| 服务集成测试 | 剪贴板监听、内存索引同步、Provider 聚合、设置持久化 | 使用 mock pasteboard / mock provider / mock filesystem | XCTest |
| UI 构建验证 | SwiftUI/AppKit 窗口、菜单栏、搜索框、管理中心、Onboarding | 构建验证 + 可测试 ViewModel | Xcode build/test |
| 手动验收 | 权限、真实截图、全局快捷键、菜单栏、系统设置跳转 | 按手动清单逐项验证 | 人工执行 |
| 发布验收 | 关于页、隐私政策、反馈邮件、检查更新、官网/项目主页 | 文档/链接/流程检查 | 人工执行 |

---

## 3. 测试入口与基线命令

### 3.1 必跑自动化命令

| 命令 | 目的 | US-021 基线要求 |
| :--- | :--- | :--- |
| `swift test --skip-update` | SwiftPM 单元/集成测试入口，覆盖纯逻辑、Provider、Core Data 临时 store、文件资源临时目录、Repository 和内存索引 | 必须通过；如失败必须修复或按阻塞流程记录 |
| `xcodebuild -project /Users/abyss/workspace/abyss/assistant/SnapVault.xcodeproj -scheme SnapVault -configuration Debug build` | macOS App Debug 构建验证，覆盖 SwiftUI/AppKit/Xcode target 集成 | 环境允许时必须运行并通过 |
| `xcodebuild test -project /Users/abyss/workspace/abyss/assistant/SnapVault.xcodeproj -scheme SnapVault -configuration Debug` | Xcode XCTest 入口，验证 Xcode target 中测试文件和资源配置 | 环境允许时必须运行并通过 |

### 3.2 当前自动化测试目标映射

| 覆盖主题 | 测试文件 | 验证方式 |
| :--- | :--- | :--- |
| SearchSource Provider、触发规则、排序、总上限、执行后关闭 | `SnapVaultTests/SearchServiceCoreTests.swift` | mock sources 聚合测试；验证空输入、分来源 canSearch、`baseScore + matchScore + usageScore` 排序、12 条截断、主动作执行返回关闭搜索框 |
| AppSource 应用索引、拼音、黑名单、使用统计 | `SnapVaultTests/AppSearchSourceTests.swift` | 临时 `.app` bundle 目录；验证 MVP 三目录范围、中文应用拼音/首字母、黑名单隐藏/恢复、启动统计加权 |
| CommandSource 白名单、双语别名、拼音、确认、使用统计 | `SnapVaultTests/SystemCommandSourceTests.swift` | 验证 14 个内置命令、危险命令不可搜、确认门禁、中文/英文/拼音/首字母搜索和命令选择加权 |
| SettingsSource 页面入口、拼音和设置源开关 | `SnapVaultTests/SettingsSourceTests.swift` | 验证设置/权限/剪贴板历史/搜索源/快捷键/截图/关于入口，且搜索结果只打开页面不直接切换设置 |
| 拼音工具与文本匹配 | `SnapVaultTests/PinyinHelperTests.swift`、`SnapVaultTests/SearchTextMatcherTests.swift` | 验证中文转拼音、首字母、混合中英文、英文别名和中文别名拼音匹配 |
| CalculatorSource 与单位换算 | `SnapVaultTests/CalculatorSourceTests.swift`、`SnapVaultTests/UnitConverterSourceTests.swift` | 验证四则、括号、小数、非法/除零/范围外输入拒绝；长度、重量、数据大小、温度换算；回车复制动作 |
| contentHash 去重策略 | `SnapVaultTests/AssistantClipboardRepositoryTests.swift` | 验证文本换行规范化、富文本格式参与 hash、图片二进制 hash、文件路径排序、重复复制只更新时间 |
| Core Data 临时 store 与模型 CRUD | `SnapVaultTests/PersistenceControllerTests.swift` | 使用 `.temporary` store；验证 ClipboardRecord/ClipboardResource/SearchBlacklistItem/UsageStat/AppSetting CRUD、唯一约束、级联删除、默认设置 |
| FileResourceStore 临时目录 | `SnapVaultTests/AssistantClipboardRepositoryTests.swift` | 使用临时 `AssistantFileSystem`；验证 Images/Thumbnails/RichText 写读删、UUID 相对路径、存储占用 |
| ClipboardRepository、置顶、保留时间、资源缺失 | `SnapVaultTests/AssistantClipboardRepositoryTests.swift` | 验证 upsert/fetch/history/delete/clearAll/togglePin/cleanupExpired/storageUsage，资源缺失和文件引用缺失 snapshot |
| InMemorySearchIndex 与剪贴板索引链路 | `SnapVaultTests/InMemorySearchIndexTests.swift` | 验证启动重建轻量字段、不加载图片/富文本大对象、upsert/delete/clear/pin 同步、索引命中后按需加载详情 |
| 搜索黑名单 Repository | `SnapVaultTests/SearchBlacklistRepositoryTests.swift` | 验证具体结果 add/list/contains/remove，以及 SearchService 过滤后移除恢复 |
| 设置服务、保留时间、语言、开机启动、截图目录 | `SnapVaultTests/SettingsServiceTests.swift` | 验证默认值、持久化、reset、语言 raw value 和截图保存目录 |
| Onboarding / 权限 / 快捷键 ViewModel | `SnapVaultTests/OnboardingViewModelTests.swift` | 使用 mock Permission/Hotkey/LaunchAtLogin，验证拒绝权限不能完成、重新检测、快捷键冲突和剪贴板知晓确认 |
| 搜索面板与剪贴板页面 ViewModel | `SnapVaultTests/SearchPanelViewModelTests.swift`、`SnapVaultTests/ClipboardListViewModelTests.swift` | 验证键盘选择、ESC/关闭、历史筛选、回车恢复、删除/清空确认等可自动化 ViewModel 行为 |
| 截图标注纯逻辑 | `SnapVaultTests/AnnotationTests.swift` | 验证标注模型、样式预设、撤销/重做等不依赖真实屏幕录制权限的逻辑 |

### 3.3 手动验收归档要求

P0/P1 手动用例执行时，应记录：执行日期、macOS 版本、构建方式、执行人、通过/失败、失败截图或日志、对应 Case ID。US-021 只建立可执行清单和自动化基线；US-022 才执行完整 MVP 集成验收并汇总所有手动结果。

---

## 4. 自动化测试范围

### 4.1 SearchSource / Provider

应覆盖：

- Provider 启用/禁用展示逻辑。
- AppSource 只索引 `/Applications`、`~/Applications`、`/System/Applications` 下的 `.app`。
- CommandSource 只返回内置白名单命令。
- CalculatorSource 只在表达式或单位模式时触发。
- SettingsSource 返回页面级和具体设置区块入口。
- 搜索黑名单过滤具体结果。
- SearchResult 支持 `primaryAction` 和 `secondaryActions`，但 MVP UI 只执行主动作。

### 4.2 搜索排序与触发规则

应覆盖：

- 空输入时不展示任何推荐、最近内容或剪贴板内容。
- 应用、命令、设置输入 1 个字符开始搜索。
- 剪贴板输入不少于 2 个字符开始搜索。
- 计算/换算仅在检测到表达式或单位模式时触发。
- 来源基础优先级：应用 100、命令 90、计算/换算 85、设置 80、剪贴板 70。
- 文本匹配分数参与综合排序。
- 应用和命令的使用次数、最后使用时间参与最近使用加权。
- 总结果上限为 12 条。
- 不显示分组标题，每条结果通过图标和类型标签标识来源。

### 4.3 拼音与中英文别名

应覆盖：

- 应用名称、命令名称、设置项名称支持拼音搜索。
- 应用名称、命令名称、设置项名称支持拼音首字母搜索。
- 剪贴板正文 MVP 不做拼音索引，只做原文搜索。
- 内置命令维护中英文别名。
- 无论当前界面语言，中文和英文关键词都能搜索到对应命令。

### 4.4 CalculatorSource / Unit Converter

应覆盖：

- 基础四则运算。
- 括号。
- 小数。
- 非法表达式不崩溃、不返回错误结果。
- 除零等非有限结果不返回。
- 长度、重量、数据大小、温度换算。
- 不支持货币换算、复杂函数、变量和计算历史。
- 回车主动作复制计算/换算结果到系统剪贴板。
- 计算/换算结果是否进入剪贴板历史遵循统一剪贴板监听与去重逻辑。
- CalculatorSource 表达式求值必须验证未使用 `NSExpression` 等可执行表达式机制；非法表达式、除零、NaN/Infinity、货币、复杂函数、变量、历史、体积/时长等范围外输入均返回空结果。

### 4.5 剪贴板数据模型与持久化

应覆盖：

- Core Data 存储结构化数据。
- 文件系统存储图片原图、缩略图、RTF/HTML 原始格式等大对象。
- 大对象目录至少包含：`Clipboard/Images/`、`Clipboard/Thumbnails/`、`Clipboard/RichText/`。
- 大对象文件名使用 UUID。
- Core Data 保存相对路径/资源标识和 contentHash。
- 文本、富文本、图片、文件引用均可保存。
- 富文本保存纯文本内容和 RTF/HTML 原始格式。
- 展示和搜索使用纯文本。
- 富文本复制回剪贴板时尽量恢复 RTF/HTML，失败则降级为纯文本。
- 文件剪贴板只保存引用/路径，不复制文件内容。
- 文件移动或删除后显示资源不可用提示。

### 4.6 剪贴板去重、置顶和清理

应覆盖：

- 基于 contentHash 去重。
- 重复复制相同文本、图片或文件引用时不新增记录，只更新时间。
- 去重后的记录按更新时间重新排序。
- 已置顶内容重复复制时更新时间但保持置顶。
- 支持置顶/取消置顶。
- 置顶项显示在列表顶部。
- 置顶项不受自动过期清理影响。
- 保留时间预设：7 天、30 天、90 天、永久。
- 默认保留 30 天。
- 只按时间淘汰，不按容量自动清理。
- 显示存储占用，并提供清空历史入口。
- 清空全部历史必须二次确认并提示不可撤销。
- 删除单条历史 MVP 可以不二次确认。

### 4.7 内存搜索索引

应覆盖：

- 启动时从 Core Data 全量加载轻量索引字段。
- 内存索引不加载图片原图、RTF/HTML 原始数据等大对象。
- 索引至少包含 id、纯文本摘要、内容类型、时间、置顶状态、hash、资源引用。
- 新增、更新、删除、置顶变化时同步更新内存索引。
- 剪贴板历史页面和统一搜索优先查询内存索引，再按需加载 Core Data 详情。

### 4.8 搜索黑名单

应覆盖：

- 只支持屏蔽具体搜索结果。
- 可隐藏某个 App、某条内置命令、某个设置入口。
- 不支持按关键词、路径、来源规则批量隐藏。
- MVP 只能通过设置页查看、添加、移除黑名单。
- 黑名单移除后对应结果重新展示。
- MVP 不实现搜索结果右键菜单或完整次级动作入口。

### 4.9 UpdateService（v1.0.1 起）

放置位置：`SnapVaultTests/UpdateServiceTests.swift`（`swift test` 覆盖）。

#### TC-U-001：UpdateService 启动期不主动启动 Sparkle updater

- **类型**：unit / P0
- **意图**：`UpdateService.setup()` 调用后，Sparkle updater 不在启动期主动 `startUpdater`，从代码级消除“无法启动更新程序”弹窗根因。
- **前置条件**：`UpdateService.swift` 采用 `startsUpdaterAutomatically = false` 常量并绑定 `SPUStandardUpdaterController(startingUpdater:)` 入参；测试目标 `@testable import SnapVault`。
- **步骤**：
  1. 读取 `UpdateService.startsUpdaterAutomatically` 常量。
  2. 断言其值为 `false`（该常量即 `SPUStandardUpdaterController(startingUpdater:)` 的唯一实参来源）。
- **预期结果**：启动策略常量为 `false`；测试进程内不弹出任何系统对话框。
- **通过判定**：断言通过，用例在 `swift test` 中 pass。

#### TC-U-002：checkNow() 仍触发 GitHub Releases 跳转

- **类型**：unit / P0
- **意图**：`UpdateService.checkNow()` 通过注入的 `UpdateCheckServiceProtocol` 打开 GitHub Releases 页（MVP“检查更新”跳转策略不被破坏）。
- **前置条件**：`UpdateService.init(updateCheckService:)` 支持注入；在测试文件内自建 spy（不复用其他文件内的 `private` spy 类型）。
- **步骤**：
  1. 构造 spy `UpdateCheckServiceProtocol`（记录 `openDownloadPage()` 调用次数）。
  2. 以注入方式构造 `UpdateService`。
  3. 调用 `checkNow()`。
  4. 断言 spy 记录到恰好一次跳转。
- **预期结果**：`openDownloadPage()` 被调用一次；不触发真实 `NSWorkspace.open`。
- **通过判定**：spy 断言通过（调用次数 == 1），用例在 `swift test` 中 pass。

---

## 5. 手动验收清单

### 5.1 首次 Onboarding

| Case ID | 场景 | 步骤 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| ONB-001 | 首次启动显示 Onboarding | 首次运行 App | 依次显示欢迎、搜索入口与快捷键、剪贴板说明、截图权限、辅助功能权限、开机启动、完成 | P0 |
| ONB-002 | 快捷键注册成功 | 默认 `⌥ Space` 未冲突 | Onboarding 尝试注册成功，可继续 | P0 |
| ONB-003 | 快捷键冲突处理 | 模拟默认快捷键注册失败 | 要求用户重新录制快捷键，直到成功后才能完成 | P0 |
| ONB-004 | 剪贴板默认开启确认 | 到剪贴板说明步骤 | 文案说明默认开启、仅本地保存、可暂停/清空；用户点击“我知道了，继续” | P0 |
| ONB-005 | 屏幕录制权限强制 | 拒绝屏幕录制权限 | 停留在权限页，不能完成 Onboarding | P0 |
| ONB-006 | 辅助功能权限强制 | 拒绝辅助功能权限 | 停留在权限页，不能完成 Onboarding，并解释用途边界与未来能力 | P0 |
| ONB-007 | 权限重新检测 | 授权后返回 App 点击重新检测 | 权限状态更新，可继续 | P0 |

### 5.2 菜单栏 App

| Case ID | 场景 | 步骤 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| MENU-001 | 菜单栏常驻 | 启动 App | 菜单栏显示单色 template 图标，无 Dock 图标 | P0 |
| MENU-002 | 菜单项完整 | 点击菜单栏图标 | 显示打开搜索、剪贴板、截图、设置、关于、退出 | P0 |
| MENU-003 | 菜单栏截图 | 点击“截图” | 直接进入区域截图 | P0 |
| MENU-004 | 退出 App | 点击“退出” | App 完全退出，快捷键监听和剪贴板记录停止 | P0 |

### 5.3 统一搜索入口

| Case ID | 场景 | 步骤 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| SEARCH-001 | 快捷键打开搜索 | 按 `⌥ Space` 或自定义快捷键 | 居中搜索框出现，输入框聚焦 | P0 |
| SEARCH-002 | 空输入状态 | 打开搜索框但不输入 | 不显示推荐结果、最近内容或剪贴板内容，仅显示输入提示 | P0 |
| SEARCH-003 | 应用搜索 | 输入应用名或拼音 | 返回匹配 `.app`，可回车启动 | P0 |
| SEARCH-004 | 命令搜索 | 输入 `截图`、`screenshot`、`jt` | 返回对应内置命令 | P0 |
| SEARCH-005 | 剪贴板搜索触发 | 输入 1 个字符 | 不触发剪贴板结果 | P0 |
| SEARCH-006 | 剪贴板搜索结果 | 输入不少于 2 个字符且匹配历史 | 返回剪贴板结果 | P0 |
| SEARCH-007 | 计算器结果 | 输入 `1+2*3` | 显示结果 `7`，回车复制到剪贴板 | P0 |
| SEARCH-008 | 单位换算结果 | 输入 `10 cm to inch` | 显示长度换算结果，回车复制 | P1 |
| SEARCH-009 | 搜索关闭 | 点击外部、切换 App、按 ESC、再次按快捷键、执行结果 | 搜索框关闭 | P0 |
| SEARCH-010 | 总结果上限 | 输入广泛关键词 | 最多展示 12 条结果 | P1 |

### 5.4 剪贴板历史页面

| Case ID | 场景 | 步骤 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| CLIP-001 | 文本记录 | 复制一段文本 | 历史中出现文本项 | P0 |
| CLIP-002 | 富文本记录 | 从网页/文档复制带格式文本 | 展示纯文本，复制回剪贴板时尽量保留格式 | P0 |
| CLIP-003 | 图片记录 | 复制图片 | 保存原图，生成缩略图，历史中可预览 | P0 |
| CLIP-004 | 文件引用记录 | Finder 中复制文件 | 历史中显示文件名、路径、类型、复制时间，不复制文件内容 | P0 |
| CLIP-005 | 文件丢失容错 | 复制文件后移动/删除原文件 | 历史项显示资源已丢失，恢复时提示失败原因 | P1 |
| CLIP-006 | 类型筛选 | 点击全部/文本/图片/文件 | 列表按类型过滤 | P0 |
| CLIP-007 | 独立搜索框 | 在剪贴板页面输入关键词 | 即时 debounce 搜索，仅搜索剪贴板历史 | P0 |
| CLIP-008 | 回车恢复 | 选择历史项按 Enter | 内容写入系统剪贴板，不自动粘贴到前台应用 | P0 |
| CLIP-009 | 置顶排序 | 置顶某条历史 | 置顶项在列表顶部，搜索时置顶匹配项优先 | P0 |
| CLIP-010 | 重复复制去重 | 重复复制相同内容 | 不新增记录，只更新时间并重新排序 | P0 |
| CLIP-011 | 存储占用 | 打开设置或剪贴板页面 | 显示剪贴板历史存储占用，并提供清空入口 | P1 |
| CLIP-012 | 清空确认 | 点击清空全部 | 显示二次确认，提示不可撤销 | P0 |

### 5.5 截图与标注

| Case ID | 场景 | 步骤 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| SHOT-001 | 区域截图 | 搜索/菜单触发区域截图 | 可选择区域，完成后进入预览工具栏 | P0 |
| SHOT-002 | 全屏截图 | 搜索触发全屏截图 | 完成截图并进入预览工具栏 | P0 |
| SHOT-003 | 窗口截图 | 搜索触发窗口截图 | 可选择窗口并截图，进入预览工具栏 | P0 |
| SHOT-004 | 标注工具 | 使用矩形框、箭头、文字、马赛克/模糊 | 标注显示正确，可撤销/重做 | P0 |
| SHOT-005 | 标注样式预设 | 切换颜色、线宽、文字大小 | 预设生效：红/黄/蓝/绿/白/黑，细/中/粗，小/中/大 | P1 |
| SHOT-006 | 复制截图 | 点击复制 | 截图写入系统剪贴板，并进入剪贴板历史 | P0 |
| SHOT-007 | 保存截图 | 点击保存 | 保存为 PNG 到 `~/Pictures/Screenshots`，文件名为 `Screenshot yyyy-MM-dd HH.mm.ss.png`，显示轻提示 | P0 |
| SHOT-008 | 保存不进剪贴板 | 点击保存但不复制 | 不额外写入剪贴板历史 | P1 |
| SHOT-009 | ESC 取消 | 区域/窗口选择、预览、标注中按 ESC | 始终取消当前截图流程；预览阶段丢弃并关闭 | P0 |

### 5.6 内置命令

MVP 内置命令权威清单以 `doc/architecture_api.md` 的“10.1 MVP 内置命令权威清单”为准，共 14 个命令。

| Case ID | 场景 | 覆盖 CommandID | 步骤 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| CMD-001 | 打开系统设置 | `openSystemSettings` | 搜索并执行 | 打开系统设置 | P0 |
| CMD-002 | 打开本应用设置 | `openAppSettings` | 搜索并执行 | 打开管理中心设置页 | P0 |
| CMD-003 | 打开目录 | `openDownloads` / `openApplications` / `openDesktop` | 分别搜索下载、应用程序、桌面目录命令 | Finder 打开对应目录 | P1 |
| CMD-004 | 截图命令 | `captureRegion` / `captureFullScreen` / `captureWindow` | 分别搜索区域/全屏/窗口截图 | 进入对应截图流程 | P0 |
| CMD-005 | 清空剪贴板历史确认 | `clearClipboardHistory` | 搜索并执行清空历史 | 弹确认，取消不清空，确认后清空 | P0 |
| CMD-006 | 暂停/恢复剪贴板记录 | `toggleClipboardRecording` | 搜索并执行 | 剪贴板记录状态切换 | P0 |
| CMD-007 | 检查权限状态 | `checkPermissions` | 搜索并执行 | 打开权限页或显示权限状态 | P1 |
| CMD-008 | 重启 Finder/Dock 确认 | `restartFinder` / `restartDock` | 分别搜索并执行重启 Finder、重启 Dock | 弹确认，取消不执行；真实执行仅限人工安全环境 | P0 |
| CMD-009 | 切换深浅色模式 | `toggleAppearance` | 搜索并执行 | 不弹确认，系统外观切换 | P1 |
| CMD-010 | 禁止高风险命令和任意 shell | 禁止项 | 输入疑似 shell、sudo、关机、重启系统、注销、删除文件、杀进程命令 | 不执行，不返回可直接执行的危险结果 | P0 |

### 5.7 设置、关于与发布信息

| Case ID | 场景 | 步骤 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| SET-001 | 搜索源开关 | 设置中关闭某搜索源展示 | 该来源结果不再出现在统一搜索中 | P0 |
| SET-002 | 剪贴板功能开关 | 关闭剪贴板记录 | 停止记录新剪贴板；重新开启后恢复 | P0 |
| SET-003 | 黑名单管理 | 设置页添加/移除具体结果 | 加入后不展示，移除后重新展示 | P1 |
| SET-004 | 开机启动 | 完成 Onboarding 后检查登录项 | 默认启用；设置中可关闭 | P1 |
| SET-005 | 语言切换 | 设置为中文/English/跟随系统 | 文案切换或提示重启后生效 | P1 |
| ABOUT-001 | 关于页信息 | 打开关于页 | 显示应用名称、版本号、构建号、官网/项目主页、隐私政策、检查更新、反馈入口、第三方许可、版权信息 | P0 |
| ABOUT-002 | 检查更新 | 点击检查更新 | 打开官网下载页或 GitHub Release 页面 | P1 |
| ABOUT-003 | 邮件反馈 | 点击反馈问题 | 打开邮件客户端，预填应用版本、macOS 版本、错误摘要和用户补充说明 | P1 |
| PRIV-001 | 隐私政策入口 | 关于页点击隐私政策 | 打开隐私政策，说明本地保存、不上传、不同步、不训练、关闭记录和清空方式 | P0 |

### 5.8 本地化

| Case ID | 场景 | 步骤 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| L10N-001 | 系统中文 | macOS 语言为中文 | App 默认显示简体中文 | P0 |
| L10N-002 | 系统英文 | macOS 语言为英文 | App 默认显示 English | P0 |
| L10N-003 | 手动切换语言 | 设置中选择语言 | 核心 UI、Onboarding、权限说明、隐私说明、错误提示、关于页语言一致 | P0 |
| L10N-004 | 双语命令搜索 | 中文界面输入英文命令，英文界面输入中文命令 | 均能搜索到对应内置命令 | P1 |

### 5.9 更新检查（v1.0.1 起）

| Case ID | 场景 | 步骤 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| TC-M-001 | Debug 启动无 Sparkle 弹窗 | Debug 构建启动后观察 3 秒 | 不出现“无法启动更新程序”系统对话框 | P0 |
| TC-M-002 | Release 启动无 Sparkle 弹窗 | Release 构建启动后观察 3 秒 | 不出现“无法启动更新程序”系统对话框 | P0 |
| TC-M-003 | 检查更新跳转浏览器 | 点击“检查更新” | 默认浏览器打开 `https://github.com/abyss/assistant/releases`，不出现 Sparkle 更新 UI 或错误弹窗 | P0 |

> v1.0.1（2026-07-02）·TC-M-001/002/003 由 @user 亲自执行通过（Debug + Release + 检查更新跳转），详见 `iterations/v1.0.1/test/report.md`。

---

## 6. P0/P1 验证方式总表

| 能力域 | P0/P1 Case ID | 自动化验证 | 手动验证 | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| Onboarding 与权限 | ONB-001 ~ ONB-007 | `OnboardingViewModelTests` 覆盖步骤流、权限拒绝/重新检测、快捷键冲突、剪贴板知晓确认 | 必须手动验证真实系统权限页、授权/拒绝后的系统状态变化 | 真实屏幕录制/辅助功能授权依赖 macOS 隐私数据库，不能只靠自动化替代 |
| 菜单栏 App | MENU-001 ~ MENU-004 | Xcode build 验证 App target、`LSUIElement`、菜单代码可编译 | 必须手动验证菜单栏图标、无 Dock 图标、菜单项和退出后后台服务停止 | 菜单栏与 Dock 状态属于系统 UI 行为 |
| 统一搜索入口 | SEARCH-001 ~ SEARCH-010 | `SearchServiceCoreTests`、`SearchPanelViewModelTests`、`AppSearchSourceTests`、`SystemCommandSourceTests`、`CalculatorSourceTests`、`UnitConverterSourceTests` | 必须手动验证全局快捷键唤起、失焦/切 App 关闭、真实 App 启动 | 核心排序/触发/上限自动化，系统快捷键和窗口行为人工验收 |
| 剪贴板历史 | CLIP-001 ~ CLIP-012 | `AssistantClipboardRepositoryTests`、`ClipboardMonitorTests`、`InMemorySearchIndexTests`、`ClipboardListViewModelTests` | 必须手动验证真实 NSPasteboard 文本/富文本/图片/Finder 文件复制恢复 | 数据层和 ViewModel 自动化，真实 pasteboard 格式兼容人工验收 |
| 截图与标注 | SHOT-001 ~ SHOT-009 | `AnnotationTests` 覆盖标注模型/样式/撤销重做；Xcode build 覆盖截图 target 集成 | 必须手动验证区域/全屏/窗口截图、屏幕录制权限缺失提示、复制/保存 PNG、ESC | 真实截图依赖屏幕录制权限和屏幕环境 |
| 内置命令 | CMD-001 ~ CMD-010 | `SystemCommandSourceTests` 覆盖 14 个白名单、确认门禁、危险命令拒绝、双语/拼音和使用统计 | 必须手动验证打开目录/系统设置/截图命令；重启 Finder/Dock 仅安全环境确认 | 自动化不得真实执行中风险系统操作 |
| 设置、黑名单、关于与发布信息 | SET-001 ~ SET-005、ABOUT-001 ~ ABOUT-003、PRIV-001 | `SettingsServiceTests`、`SettingsSourceTests`、`SearchBlacklistRepositoryTests`、`ReleaseInfoServiceTests` | 必须手动验证真实关于页、隐私政策链接、邮件客户端、检查更新 URL | US-020 官网素材与链接最终准备不属于 US-021 |
| 本地化 | L10N-001 ~ L10N-004 | `SettingsSourceTests`、`SettingsServiceTests`、`SystemCommandSourceTests` 覆盖语言设置 raw value 和双语搜索 | 必须手动验证中文/英文 UI 文案完整 | 自动化覆盖设置/搜索，完整文案需人工走查 |
| 性能 | 冷启动、搜索响应、CPU、内存、剪贴板响应 | SearchService elapsed 和索引单测可作为回归信号 | 必须用 Activity Monitor/Instruments 和人工计时验收 | US-021 建立验收方式；US-022 执行完整性能记录 |

---

## 7. 性能验收

| 指标 | 目标 | 验收方式 |
| :--- | :--- | :--- |
| 冷启动 | ≤ 1 秒 | 本地多次启动取平均，排除首次系统缓存异常 |
| 搜索响应 | ≤ 100ms | 输入关键词到结果刷新，覆盖应用/命令/剪贴板/计算器 |
| 后台空闲 CPU | ≤ 1% | Activity Monitor 或 Instruments 观察常驻空闲状态 |
| 后台常驻内存 | ≤ 150MB，理想 ≤ 100MB | 常驻 30 分钟后观察内存占用 |
| 剪贴板监听响应 | 复制后 1 秒内进入历史 | 文本、图片、文件分别验证 |
| 截图交互 | 区域选择/预览/复制/保存无明显卡顿 | 手动验证 |

---

## 8. 明确不测 / 不自动执行范围

MVP 自动化测试不得执行：

- 关机、重启系统、注销、删除文件、杀进程、sudo、任意 shell。
- 真实重启 Finder / Dock，除非在人工安全环境下确认。
- 未经用户确认的崩溃日志或诊断信息上传。
- 静默访问网络反馈接口。

MVP 暂不覆盖：

- OCR。
- 录屏。
- 长截图。
- 截图历史页。
- 插件系统。
- 账号系统。
- 支付/授权/订阅。
- Mac App Store 审核流程。
- Developer ID 签名和 Apple Notarization 公证流程。

---

## 9. 后续测试改进

1. 为 SearchSource、剪贴板索引、Core Data repository、文件资源管理建立依赖注入接口，降低测试对真实系统状态的依赖。
2. 将截图坐标转换、标注图层模型、搜索评分、单位换算、拼音匹配等逻辑抽成纯函数，提升单元测试覆盖率。
3. 增加 UI 自动化测试，覆盖 Onboarding、管理中心和搜索框基础交互。
4. 后续引入签名/公证后，增加发布包安装、Gatekeeper、更新检查的端到端验收。
5. 后续引入右键菜单、Action Panel、快捷数字键后，补充对应交互测试。

---
