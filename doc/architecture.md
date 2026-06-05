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
用户输入快捷键 ⌘+Shift+V ──> 浮动搜索面板
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
用户按快捷键 ⌘+Shift+S ──> ScreenshotService
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
    └── ClipboardSearchSource（GRDB FTS5，< 50ms）
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
- **快捷键**：`⌘+Shift+S`（区域截图）、`⌘+Shift+W`（窗口截图）
- **截图编辑**：v1 不做标注编辑，后续版本可考虑

理由：ScreenCaptureKit 是 macOS 12.3+ 原生 API，性能优于 CGWindowListCreateImage，支持高质量捕获。

### 8. 搜索结果排序策略

四种搜索源的结果合并后，按以下规则排序：

1. **类型权重**：应用 > 文件 > 剪贴板（应用启动最常用）
2. **相关度分数**：各源内部的匹配分数归一化到 0-1
3. **使用频率**：记录用户选择次数，高频结果提升排名
4. **时效性**：剪贴板按时间衰减，文件按修改时间排序

最终分数 = 类型权重 × 0.3 + 相关度 × 0.4 + 使用频率 × 0.2 + 时效性 × 0.1

## 变更记录

| 日期       | 变更内容 |
| :--------- | :------- |
| 2026-06-05 | 初始版本：基于 PRD 创建总体架构设计 |
| 2026-06-05 | v2：重构为统一效率入口，增加应用搜索、文件搜索、统一搜索管线 |
| 2026-06-05 | v3：对齐 PRD 产品定位，增加截图模块（ScreenCaptureKit），修正系统概述为"统一效率入口"，修正默认快捷键为 ⌘+Shift+V，内存指标统一为 < 50MB |
