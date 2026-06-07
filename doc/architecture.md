# SnapVault 架构设计

## 修订记录

| 日期       | 修改人 | 备注     |
| :--------- | :----- | :------- |
| 2026-06-05 | Claude | 初始版本 |
| 2026-06-05 | Claude | v2：增加应用搜索、文件搜索，重构为 Spotlight 类启动器 |

## 系统概述

SnapVault 是一款 **macOS 统一效率入口**，将应用启动、文件搜索、截图 OCR、剪贴板管理四大高频能力集成到一个轻量级桌面工具中。

当前 Mac 用户通常需要安装多个工具（Alfred、Shottr、CleanShot X、Maccy）来完成日常效率操作，存在学习成本高、快捷键冲突、数据分散、资源占用增加等问题。SnapVault 通过一个全局搜索面板 + 快捷键体系，替代上述工具 80% 的核心使用场景：

| 能力           | 说明                                         | 替代产品              |
| :------------- | :------------------------------------------- | :-------------------- |
| **应用启动**   | 搜索已安装应用，即时启动                     | Alfred                |
| **文件搜索**   | 基于 Spotlight 索引的文件名/内容搜索         | Alfred、Finder        |
| **截图 OCR**   | 区域截图、窗口截图、OCR 文字识别             | Shottr、CleanShot X   |
| **剪贴板管理** | 历史记录、全文搜索、置顶、去重               | Maccy、Paste          |

面向普通办公人员、产品经理、开发者等所有 Mac 用户，解决"文件难找、OCR 步骤繁琐、剪贴板记录缺失"的核心痛点。

## 设计目标

- **即时响应**：搜索结果 < 200ms 返回，快捷键唤起面板 < 150ms，应用启动 < 500ms
- **低资源占用**：常驻内存 < 50MB，CPU 空闲占用 < 1%，数据库文件 < 500MB（默认保留 30 天）
- **统一入口**：一个搜索框同时匹配应用、文件、剪贴板，结果按类型分组展示
- **截图能力**：支持区域截图、窗口截图，截图后自动 OCR 并存入剪贴板历史
- **原生体验**：100% SwiftUI 构建，遵循 macOS Human Interface Guidelines，支持 Dark Mode、VoiceOver
- **数据安全**：所有数据仅存本地 SQLite，不联网传输；数据库文件使用 macOS Data Protection
- **可扩展性**：模块化架构，各子系统（搜索源、OCR、截图、存储）独立可替换

## 整体架构

### 分层结构

系统采用 **MVVM + 服务层 + 统一搜索管线** 的分层架构：

```
┌──────────────────────────────────────────────────────────┐
│                    表现层 (Presentation)                   │
│          UnifiedSearchView + ResultGroupView              │
├──────────────────────────────────────────────────────────┤
│                    业务层 (Business)                       │
│  UnifiedSearchService ──┬── AppSearchSource               │
│                         ├── FileSearchSource              │
│                         ├── ClipboardSearchSource         │
│                         └── ScoreAggregator               │
├──────────────────────────────────────────────────────────┤
│                    数据层 (Data)                           │
│          GRDB Repository + AppIndex Cache                 │
├──────────────────────────────────────────────────────────┤
│                    平台层 (Platform)                       │
│  NSWorkspace / NSMetadataQuery / NSPasteboard / Vision    │
└──────────────────────────────────────────────────────────┘
```

### 模块划分

| 模块                   | 职责                                           | 关键类型                         |
| :--------------------- | :--------------------------------------------- | :------------------------------- |
| **App Shell**          | 应用生命周期、菜单栏图标、全局快捷键注册       | `AppDelegate`, `MenuBarView`     |
| **UnifiedSearch**      | 统一搜索入口，聚合多个搜索源，结果排序分组     | `UnifiedSearchService`           |
| **AppSearchSource**    | 已安装应用搜索，基于 /Applications 索引        | `AppSearchSource`                |
| **FileSearchSource**   | 本地文件搜索，基于 Spotlight NSMetadataQuery   | `FileSearchSource`               |
| **ClipboardSearchSource** | 剪贴板历史搜索，基于 GRDB FTS5              | `ClipboardSearchSource`          |
| **ScreenshotService**  | 区域截图、窗口截图，截图后自动触发 OCR        | `ScreenshotService`              |
| **ClipboardMonitor**   | 监听系统剪贴板变化，去重过滤，触发存储         | `ClipboardMonitor`               |
| **ContentStore**       | 数据持久化、查询、清理过期数据                 | `ContentRepository`              |
| **OCRService**         | 图片文字识别，提取可搜索文本                   | `OCRProcessor`                   |
| **PreviewPanel**       | 内容预览窗口（文本/图片/富文本/文件）          | `PreviewView`                    |
| **SettingsModule**     | 偏好设置界面与持久化                           | `SettingsView`, `Settings`       |
| **UpdateService**      | 自动更新检查与安装                             | `SparkleUpdater`                 |

### 搜索源协议（SearchSource Protocol）

所有搜索源遵循统一协议，实现可插拔架构：

```swift
protocol SearchSource {
    var sourceType: SearchResultType { get }
    func search(query: String, limit: Int) async throws -> [SearchResult]
}

enum SearchResultType: String, CaseIterable {
    case application   // 已安装应用
    case file          // 本地文件
    case clipboard     // 剪贴板历史
}
```

### 交互关系

**核心数据流 —— 统一搜索：**

```
用户输入快捷键 ⌘+Space ──> 浮动搜索面板
                              │
                              ├─ 输入关键词 ──> UnifiedSearchService.search()
                              │                      │
                              │                      ├─> AppSearchSource.search()
                              │                      │     └─ 内存索引匹配（前缀+模糊）
                              │                      │
                              │                      ├─> FileSearchSource.search()
                              │                      │     └─ NSMetadataQuery（Spotlight）
                              │                      │
                              │                      └─> ClipboardSearchSource.search()
                              │                            └─ GRDB FTS5 全文搜索
                              │
                              ├─ ScoreAggregator ──> 合并去重、按相关度排序
                              │
                              ├─ 结果分组展示 ──> 🖥 应用 | 📁 文件 | 📋 剪贴板
                              │
                              └─ 用户选择 ──>
                                    ├─ 应用 → NSWorkspace.launchApplication()
                                    ├─ 文件 → NSWorkspace.open() / Finder 定位
                                    └─ 剪贴板 → NSPasteboard.write() + 粘贴
```

**核心数据流 —— 截图 OCR：**

```
用户按快捷键 ⌘+Shift+A ──> ScreenshotService
                              │
                              ├─ 区域截图 ──> ScreenCaptureKit.capture()
                              ├─ 窗口截图 ──> ScreenCaptureKit.captureWindow()
                              │
                              └─> 截图完成
                                    ├─ 图片 ──> OCRService ──> 提取文字
                                    ├─ 存入剪贴板历史（imageData + ocrText）
                                    └─ 可选：复制到系统剪贴板
```

**核心数据流 —— 剪贴板捕获：**

```
NSPasteboard ──poll/changeCount──> ClipboardMonitor
                                       │
                                       ├─ 去重（与最近一条比对 hash）
                                       ├─ 分类（纯文本/RTF/图片/文件）
                                       ├─ 图片 ──> OCRService ──> 提取文字
                                       │
                                       └─> ContentStore.save()
                                             │
                                             └─> SQLite (GRDB)
```

## 技术选型

| 领域     | 选择                  | 理由                                                                       | 备选方案                  |
| :------- | :-------------------- | :------------------------------------------------------------------------- | :------------------------ |
| UI 框架  | SwiftUI               | 声明式 UI，macOS 原生支持，Apple 生态未来方向，代码量少于 AppKit            | AppKit（更成熟但更冗长）  |
| 系统桥接 | AppKit                | SwiftUI 部分能力不足（如 NSWindow 控制、全局事件监听），需 AppKit 补充       | 纯 SwiftUI（能力不够）    |
| 应用搜索 | NSWorkspace + 内存索引 | 直接枚举 /Applications 目录，内存中前缀+模糊匹配，零延迟                   | LaunchServices API（较重）|
| 文件搜索 | Spotlight (NSMetadataQuery) | 系统级全文搜索，零额外索引成本，与 macOS 深度集成          | 自建倒排索引（复杂度高）  |
| OCR      | Vision (VNRecognizeTextRequest) | 系统内置，无需额外依赖，支持中英文，离线可用               | Tesseract（需打包模型）   |
| 截图     | ScreenCaptureKit      | macOS 12+ 原生 API，高性能，支持窗口/区域捕获                              | CGWindowListCreateImage   |
| 剪贴板   | NSPasteboard          | macOS 标准剪贴板 API，changeCount 监听变化                                 | 无备选                    |
| 存储     | SQLite + GRDB         | GRDB 是 Swift 生态最成熟的 SQLite 封装，类型安全，支持 FTS5 全文搜索、Migration | Core Data（过重）、Realm  |
| 快捷键   | KeyboardShortcuts     | 轻量级 Swift 库，macOS 原生快捷键注册，支持录制                            | HotKey（较老）            |
| 自动更新 | Sparkle                | macOS 应用更新事实标准，支持 Delta更新、签名验证、静默更新                   | 自建更新（工作量大）      |
| 日志     | OSLog                 | 系统内置，统一日志系统，支持 Console.app 查看，性能极佳                     | CocoaLumberjack、SwiftLog |

### 已知局限

- **SwiftUI**：部分高级窗口控制（如 Panel 样式、精确的窗口层级）需回退到 AppKit
- **ScreenCaptureKit**：最低要求 macOS 12.3，需在 Info.plist 中声明最低系统版本
- **Vision OCR**：复杂排版（如表格、多栏）识别率有限，后续可考虑 VisionKit 增强
- **Spotlight 文件搜索**：依赖系统索引，首次使用或外接磁盘可能有延迟；应用搜索不依赖 Spotlight
- **应用搜索覆盖范围**：仅索引 /Applications 和 ~/Applications，非标准路径安装的应用需手动配置

## 详细方案索引

| 领域     | 文档                                     | 说明                       |
| :------- | :--------------------------------------- | :------------------------- |
| 数据库设计 | [architecture_db.md](architecture_db.md) | SQLite 表结构、索引、迁移策略 |
| 接口设计  | [architecture_api.md](architecture_api.md) | 模块间内部接口定义          |

## 关键设计决策

### 1. 统一搜索架构（SearchSource 模式）

采用 **可插拔搜索源** 架构，而非单一搜索引擎：

```
UnifiedSearchService
    ├── AppSearchSource      （内存索引，< 10ms）
    ├── FileSearchSource     （NSMetadataQuery，< 200ms）
    ├── ClipboardSearchSource（GRDB FTS5，< 50ms）
    ├── SystemCommandSource  （内置命令清单，< 1ms）
    ├── CalculatorSource     （NSExpression 数学表达式求值，< 1ms）
    └── UnitConverterSource  （Foundation Measurement + 静态汇率表，< 1ms）
```

优势：
- 新增搜索源只需实现 `SearchSource` 协议
- 各源独立搜索，并行执行，结果由 `ScoreAggregator` 合并
- 搜索结果按类型分组展示，用户可快速切换

### 2. 应用搜索方案：内存索引而非 Spotlight

应用搜索 **不依赖 Spotlight**，而是直接枚举文件系统：

- 启动时扫描 `/Applications` 和 `~/Applications`（递归查找 `.app` bundle）
- 构建内存索引：`[{name, bundleID, path, icon}]`
- 搜索算法：前缀匹配 > 包含匹配 > 模糊匹配（Levenshtein）
- 索引刷新：每 5 分钟增量检查，监听 `NSWorkspace.didInstallApplicationNotification`

理由：Spotlight 对应用搜索有延迟（索引未完成时搜不到），内存索引首次启动即可用。

### 3. 剪贴板监听策略

采用 **定时轮询 changeCount** 的方式而非 `NSPasteboard` 的 `changeCount` KVO（macOS 不可靠）。

- 轮询间隔：500ms（平衡响应速度与 CPU 占用）
- 去重逻辑：对内容计算 SHA256 hash，与最近 10 条记录比对
- 空闲优化：应用失去焦点时降低轮询频率至 2s

### 4. 数据库选型理由

使用 GRDB 而非 Core Data 的原因：
- Core Data 的 `NSFetchedResultsController` 在 SwiftUI 中适配不自然
- GRDB 原生支持 FTS5 全文搜索，满足搜索需求
- GRDB 的 Migration 机制更适合版本迭代
- 更轻量，编译速度更快

### 5. 浮动面板 vs 独立窗口

采用 **NSPanel（浮动面板）** 而非普通 NSWindow：
- 面板在失去焦点时自动隐藏（`becomesKeyOnlyIfNeeded`）
- 可设置为 `NSPanel.Level.floating`，覆盖其他应用
- 不出现在 Dock 和 Mission Control 中
- 样式仿照 Spotlight：居中显示、圆角搜索框、结果列表

### 6. 图片 OCR 流程

```
图片进入 ──> 检查尺寸（跳过 < 50x50 的图标）
         ──> VNRecognizeTextRequest（支持中英文混合识别）
         ──> confidence > 0.5 的结果拼接为文本
         ──> 存入 clipboard_items.ocr_text 字段
         ──> 同步到 FTS5 索引
```

### 7. 截图方案：ScreenCaptureKit

采用 **ScreenCaptureKit** 实现截图能力：

- **区域截图**：用户框选屏幕区域，捕获为 PNG 图片
- **窗口截图**：自动检测鼠标所在窗口，一键捕获
- **截图后流程**：图片自动存入剪贴板历史 → 触发 OCR → 文本存入 ocr_text
- **快捷键**：`⌘+Shift+A`（区域截图）、`⌘+Shift+W`（窗口截图）
- **截图编辑**：v1 不做标注编辑，后续版本可考虑

理由：ScreenCaptureKit 是 macOS 12.3+ 原生 API，性能优于 CGWindowListCreateImage，支持高质量捕获。

### 8. 搜索结果排序策略

四种搜索源的结果合并后，按以下规则排序：

1. **类型权重**：应用 > 系统命令 > 文件 > 剪贴板（应用启动最常用；系统命令权重 0.8 紧随其后，保证 sleep/restart 等可被精准命中）
2. **相关度分数**：各源内部的匹配分数归一化到 0-1
3. **使用频率**：记录用户选择次数，高频结果提升排名
4. **时效性**：剪贴板按时间衰减，文件按修改时间排序

最终分数 = 类型权重 × 0.3 + 相关度 × 0.4 + 使用频率 × 0.2 + 时效性 × 0.1

### 9. 系统命令搜索源（SystemCommandSource）

将系统级操作（sleep / restart / shutdown / lock / empty trash / show desktop）
作为一个独立搜索源接入 UnifiedSearchService，遵循 `SearchSource` 协议：

- **命令清单**：内置 7 条命令，含 `primaryKeyword`、`aliases`（中英文混合）、`title`、`subtitle`、`iconName`
- **匹配策略**：primaryKeyword 前缀匹配 > primaryKeyword 包含匹配 > aliases 前缀/包含匹配
- **执行方式**：
  - `sleep` / `restart` / `shutdown` / `emptyTrash` / `showDesktop`：`NSAppleScript`
  - `lock`：调用 `/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession -suspend`
  - `lockScreen`：`/usr/bin/pmset displaysleepnow`（display sleep，配合系统"需密码解锁"实现锁屏）
- **安全确认**：`restart` / `shutdown` / `emptyTrash` 标记 `requiresConfirmation = true`，执行前弹 `NSAlert` 二次确认
- **新增类型**：`SearchResultType.systemCommand`（displayName "System", iconName "gearshape", typePriority 0.8）
- **新增 Action**：`SearchResultAction.runSystemCommand(SystemCommand)`

### 10. 计算器搜索源（CalculatorSource）

将数学表达式求值作为独立搜索源接入 UnifiedSearchService，遵循 `SearchSource` 协议：

- **表达式识别**：先用正则限定字符集（仅允许数字 / `.,` / `+ - * / % ^` / `( )` / 空白），再要求同时存在数字和真正的运算符（排除单纯的 `-5`/`+3`）。命中后才进入 NSExpression 求值。
- **求值**：`NSExpression(format:)`。`^` 在交给 NSExpression 前替换为 `**`（NSExpression 原生支持 `**` 作为幂运算）。
- **防御性语法校验**：括号平衡 + 禁止 `()`、`(*`、首字符为二元运算符、尾字符为运算符或 `(`、连续二元运算符（仅允许 `**` 和紧随其后的一元 `+/-`）。这层防御用于在 Swift 侧拦截那些会让 NSExpression 抛 Obj-C 异常的输入。
- **失败 → 空结果**：除零（结果为 ±∞）、非数字结果、解析失败统一返回 `[]`，让其他搜索源接管，不污染 UI。
- **格式化**：`NumberFormatter`（en_US_POSIX、最多 10 位小数、去尾零、无千分位）。
- **结果展示**：title 为 `= <result>`，subtitle 为原表达式，icon 为 SF Symbol `function`，action 为 `.copyText(<result>)`。
- **typePriority 1.0**：与 application 并列最高，配合排序后实际会因为评分聚合（score 1.0 × relevanceWeight + 1.0 × typeWeight）排到最顶部。
- **新增类型**：`SearchResultType.calculator`（displayName "Calculator", iconName "function", typePriority 1.0）
- **新增 Action**：`SearchResultAction.copyText(String)`（同时供 US-020 单位/货币换算源复用）
- **复制反馈**：UnifiedSearchViewModel 新增 `showToast` / `toastMessage` 状态，复制后通过 `ToastModifier`（与 ClipboardListView 共用）展示 1.5s "Copied: <text>"。

### 11. 单位 / 货币换算搜索源（UnitConverterSource）

将"数字 + 单位 → 常见目标单位"作为独立搜索源接入 UnifiedSearchService，遵循 `SearchSource` 协议：

- **输入识别**：正则 `^\s*(-?\d+(?:\.\d+)?)\s*([a-zA-Z°]+)\s*$` 解析"数值 + 单位"组合（单位 token 不区分大小写）。
- **单位族（Foundation Measurement）**：
  - **长度** UnitLength：mm/cm/m/km/in(inch/inches)/ft(feet/foot)/yd(yard/yards)/mi(mile/miles)
  - **质量** UnitMass：mg/g/kg/lb(lbs/pound/pounds)/oz(ounce/ounces)/ton(t/tons)
  - **温度** UnitTemperature：c/°c/celsius、f/°f/fahrenheit、k/kelvin
  - **体积** UnitVolume：ml/l(liter/liters/litre/litres)/gal(gallon/gallons)/cup(cups)/floz
  - **时间** UnitDuration：s(sec/second/seconds)/min(mins/minute/minutes)/h(hr/hour/hours)
- **货币**：静态汇率表（USD 基准）`{USD:1.0, CNY:7.25, EUR:0.92, JPY:151.0, GBP:0.79, HKD:7.82}`，非实时。换算路径 `src → USD → tgt`，每行 subtitle 附"汇率为静态参考值"提示。
- **结果生成**：对每个单位族预定义 3-5 个常见目标单位（按 family 候选列表 prefix(5)，并排除源单位）。每个目标作为一条 `UnifiedSearchResult`：title `"100 cm = 1 m"`、subtitle `"Length 长度 · cm → m"`、action `.copyText("1 m")`（带单位的数值串）。
- **typePriority 0.95**：介于 application(1.0) 与 systemCommand(0.8) 之间，与 calculator 一样"只在用户真的输入数字+单位时才返回结果"，无关键字时返回 `[]` 不污染普通搜索。
- **数值格式化**：`NumberFormatter`（en_US_POSIX、最多 4 位小数、去尾零、无千分位）。
- **复用范式**：完全复用 US-019 已建立的 `.copyText(String)` action 与 Toast 反馈，无需新增 action 类型。
- **失败 → 空结果**：解析失败、未知单位、非有限数值（NaN/Inf）一律返回 `[]`。

## 变更记录

| 日期       | 变更内容 |
| :--------- | :------- |
| 2026-06-05 | 初始版本：基于 PRD 创建总体架构设计 |
| 2026-06-05 | v2：重构为统一效率入口，增加应用搜索、文件搜索、统一搜索管线 |
| 2026-06-05 | v3：对齐 PRD 产品定位，增加截图模块（ScreenCaptureKit），修正系统概述为"统一效率入口"，修正默认快捷键为 ⌘+Shift+V，内存指标统一为 < 50MB |
| 2026-06-07 | v4（US-017）：按 PRD 对齐默认快捷键 —— Command Bar 由 ⌘+Shift+V 改为 ⌘+Space（提示与 Spotlight 冲突，可在偏好设置改）；区域截图由 ⌘+Shift+S 改为 ⌘+Shift+A；窗口截图保持 ⌘+Shift+W。仅修改 `KeyboardShortcuts.Name` 的 `default:`，已自定义过的用户配置不受影响。 |
| 2026-06-07 | v5（US-018）：新增 `SystemCommandSource` 系统命令搜索源（sleep/restart/shutdown/lock/emptyTrash/showDesktop/lockScreen），扩展 `SearchResultType.systemCommand`（typePriority 0.8，紧邻 application）与 `SearchResultAction.runSystemCommand(SystemCommand)`。restart/shutdown/emptyTrash 执行前弹 NSAlert 二次确认。 |
| 2026-06-07 | v6（US-019）：新增 `CalculatorSource` 计算器搜索源，使用 NSExpression 实时求值数学表达式（支持 `+ - * / % ^ ( )`，`^` 自动转 `**`）。扩展 `SearchResultType.calculator`（typePriority 1.0，置顶）与 `SearchResultAction.copyText(String)`。失败静默返回空结果。MenuBarView 新增 Calculator Tab 与 Toast 复制反馈。`copyText` action 亦预留给 US-020 单位/货币换算复用。 |
| 2026-06-07 | v7（US-020）：新增 `UnitConverterSource` 单位/货币换算搜索源。输入 `数字+单位`（如 `100 cm`/`100 usd`/`98 f`），使用 Foundation Measurement（UnitLength/UnitMass/UnitTemperature/UnitVolume/UnitDuration）执行换算，货币使用静态汇率表（USD 基准：USD/CNY/EUR/JPY/GBP/HKD）。每个换算结果作为一行（最多 5 个目标单位），回车通过已有 `.copyText(...)` action 复制带单位的结果。新增 `SearchResultType.unitConversion`（typePriority 0.95，介于 application 与 systemCommand 之间）。MenuBarView 新增 Convert Tab。 |
| 2026-06-07 | v8（US-021）：剪贴板项目新增 `is_favorite` 收藏字段，与 `is_pinned` 解耦。注册 GRDB migration `v2_favorites`：`ALTER TABLE clipboard_items ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0` + `idx_clipboard_items_is_favorite` 索引。`ClipboardItem`、`ExportItem` 都新增 `isFavorite` 字段，`ExportItem` 实现自定义 `init(from:)` 兼容旧 JSON（缺失字段默认 false）。`ContentRepository` 新增 `toggleFavorite(id:) -> Bool` 与 `fetchFavorites(limit:offset:)`；`cleanupExpired` / `cleanupStorage` / `clearAllHistory` 全部增加 `AND is_favorite = 0` 条件以保护收藏。列表排序更新为 `is_pinned DESC, is_favorite DESC, created_at DESC`（pin 优先于 favorite）。ViewModel 新增 `toggleFavorite`，本地 re-sort 同步反映两层优先级。视图增加 star.fill 黄色图标（与 pin.fill 蓝色并列，可同时显示）、右键菜单与左滑 swipeAction「Favorite/Unfavorite」。 |
| 2026-06-07 | v9（US-022）：新增 `PinyinHelper`（Utilities），使用 `CFStringTransform(kCFStringTransformMandarinLatin + kCFStringTransformStripDiacritics)` 把中文转拼音；ASCII-only 短路；`NSCache` 5,000 条目上限。`AppSearchSource` 的 `IndexedApp` 索引时缓存 `pinyin` + `initials`，搜索新增三层（pinyinPrefix 0.65、initials 0.55、pinyinContains 0.5），优先级低于精确 contains（0.7）高于 fuzzy（0.4）。`FileSearchSource` 在 Spotlight 结果之外，对 ASCII 查询额外扫描 ~/Desktop / ~/Documents / ~/Downloads（顶层 200 entries × 3 scope，按 mtime 倒序），对 CJK 文件名做客户端拼音匹配补全；同时对所有 Spotlight 结果加拼音 bonus（+0.5 / +0.4 / +0.3），结果 cap 在 0.95 以保留精确名称匹配优先。`ClipboardSearchSource` 当前未做拼音 rerank（需要新建拼音物化列才能扩大召回，本期跳过，FTS5 + 文本片段已足够 90% 用例）。 |
| 2026-06-07 | v10（US-023）：新增「最近内容中心」面板（`RecentContentView` + `RecentContentViewModel`，分别位于 `Views/RecentContent/` 与 `ViewModels/`），数据源仍是 `clipboard_items` 表（不新增 schema/字段）。`MenuBarView` 顶部增加 `Picker(.segmented)` 切换 `PanelDisplayMode`（`.search` / `.recent`），`.recent` 为默认模式 —— 打开面板即可看到按 `DateGroup`（今天/昨天/本周周一-周日/更早 `M月d日`）分组的统一记录。`searchText` 非空时强制覆盖回 `.search`，清空后恢复 `userPreferredMode`。Recent 模式专属过滤 Tab：All / Screenshot / OCR / Clipboard；Screenshot 启发式 = `contentType == .image && ocrText 非空`（截图自动 OCR 后会有文本，纯设计图通常不会），避免新建 `source` 字段触发 v3 migration。`RecentContentView` 复用 `ClipboardItemRow` / `PreviewPanel` / 左右 swipeActions / `contextMenu`（Copy / Pin / Favorite / Delete）保持与 `ClipboardListView` 一致体验。一次最多 fetch 500 条做内存分组（典型用户场景充足，超期数据走 Search Tab 检索）；监听 `.clipboardItemSaved` 通知自动刷新。`ClipboardListView` 保留未删（其他场景仍可单独使用）。面板默认高度由 72pt 改为 500pt（Recent 模式预渲染需要），`resizePanelForSearchState` 改为始终保持 500pt。 |
| 2026-06-07 | v11（US-024）：截图捕获完成后弹出「后置工具条」（PRD 模块二要求 OCR 由显式按钮触发）。新增 `ScreenshotToolbarController`（`Views/Components/`，`@MainActor`，AppDelegate 持单例并注入 `ContentStore`），内含 `NonActivatingPanel`（`[.borderless, .nonactivatingPanel, .utilityWindow]` styleMask，`canBecomeKey=false`，`orderFrontRegardless()` 不抢焦点）+ SwiftUI `ScreenshotToolbarView`（5 个 SF Symbol 按钮：`textformat` OCR / `doc.on.doc` Copy / `square.and.arrow.down` Save / `pencil` Annotate(disabled, "Coming in US-025") / `xmark` Discard）。位置策略：屏幕底部居中（`visibleFrame.midX, visibleFrame.minY + 64pt`），CleanShot/Shottr 同款。生命周期：5 秒空闲定时器自动关闭，鼠标 hover 暂停计时，离开重置；ESC 关闭（通过 `KeyCatcher` NSViewRepresentable + `NSEvent.addLocalMonitorForEvents(keyDown)`，因 nonactivating panel 不进响应链）。按钮行为：OCR 优先用已 cache 的 `ocrText`，否则弹独立 NSWindow（titled+closable+resizable, 520x420, 标题 "OCR Result"）显示 `ProgressView` 后异步调 `ContentStore.recognizeOCR(itemId:)`，结果窗内 `TextEditor` 可编辑选择 + stats bar（行数+置信度）+ Copy All（写 string + 1.4s "Copied" toast）；Copy 同时写 `.tiff`（NSImage.tiffRepresentation）+ `.string`（ocrText）入 `NSPasteboard.general`；Save 弹 `NSSavePanel.begin`（异步非 modal），文件名 `Screenshot YYYY-MM-DD HH.mm.ss.png` 写 PNG；Discard 调 `ContentRepository.delete(id:)` + 发 `.clipboardItemSaved` 通知；Annotate 现为 stub（`disabled = true` + `help("Coming in US-025")`）。`ContentStore` 新增 `recognizeOCR(itemId:) async throws -> OCRResult`（绕过 `ocr_enabled` 开关，非空结果写回 `ocr_text` 触发 FTS5 trigger 同步）。`AppDelegate.performRegionCapture/performWindowCapture` 改为先 `await contentStore.processScreenshot(result)` 接 itemId，再 `await MainActor.run { screenshotToolbar.show(itemId:imageData:sourceType:) }` —— 保留「截图自动入库」契约，工具条只是显式 UI 入口。截图历史与 OCR 索引行为完全不变。OCRResultViewModel 通过 `objc_setAssociatedObject` 挂在 NSWindow 上实现异步回填，避免子类化 NSWindow。 |
| 2026-06-07 | v12（US-025）：接入完整截图标注编辑器。新建 `Views/Annotation/` 目录，包含 4 个文件：`AnnotationShape.swift`（`enum AnnotationShape` 定义 arrow/rectangle/mosaic/text 四种 case + `AnnotationTool` 工具枚举 + `AnnotationPalette` 调色板 + `AnnotationRenderer` 统一绘制函数）、`AnnotationCanvas.swift`（`AnnotationCanvasState` ObservableObject 持有 shapes 数组和 undoManager + `AnnotationCanvasNSView` 自定义 NSView 处理 mouseDown/Dragged/Up 和 drawRect + `AnnotationCanvasView` NSViewRepresentable 桥接 SwiftUI + `AnnotationFlattener` 离屏合成 PNG）、`AnnotationToolbar.swift`（`AnnotationTopToolbar` 工具选择 pills + 颜色圆点 + 线宽滑杆 + Undo/Redo 按钮 + `AnnotationBottomToolbar` Save/Copy/Cancel 三按钮）、`AnnotationEditorWindow.swift`（`NSWindowController` 子类，标题 "Annotate Screenshot"，初始化尺寸为图片原始像素但上限为屏幕 80%）。关键技术决策：(1) 坐标系统——shapes 存储 image-space 坐标（bottom-left origin, 1pt=1px），canvas 的 `draw(_:)` 内通过 `CGContext.translateBy` + `scaleBy` 做坐标系映射，保证编辑器内渲染与 PNG 导出完全一致；(2) Arrow 绘制——实线 stroke + 在 end 点计算 30° 夹角 15pt 长的三角形 head 并用 fill 填充；(3) Rectangle 绘制——`NSBezierPath(rect:).stroke` 标准化 rect（支持任意方向拖拽）；(4) Mosaic 绘制——`CIPixellate` 滤镜 scale 默认 8.0，center 对齐 rect 中心，`CIContext.createCGImage` 裁剪到 rect 后 `CGContext.draw` 合成；(5) Text 绘制——点击后弹 NSAlert 输入文本，以 18pt semibold 系统字体在点击位置渲染 `NSAttributedString`；(6) Undo/Redo——`AnnotationCanvasState` 持有 `UndoManager`，每次 `append(shape)` 注册 `registerUndo(withTarget:)` 逆操作，NSView 通过 `override var undoManager` 暴露到响应链，⌘Z/⌘⇧Z 自动生效；(7) 保存——`AnnotationFlattener.flatten` 离屏 `NSGraphicsContext` 合成原图 + shapes → TIFF → `NSBitmapImageRep.png` 后写入 `ContentRepository.updateImageData` + 清空 `ocr_text`（标注改变视觉内容），同时弹 `NSSavePanel` 提供文件保存；(8) Copy——合成后同时写 `.tiff` 和 `public.png` 入 `NSPasteboard.general`；(9) 与 US-024 集成——`ScreenshotToolbarController` 的 Annotate button 移除 `disabled=true`，点击调 `performAnnotate` 创建 `AnnotationEditorWindow(image:itemId:)` 并 `present()`；(10) `ContentRepository` 新增 `updateImageData(id:imageData:)` 方法直接写 `image_data` BLOB。 |
