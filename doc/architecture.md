# SnapVault 架构设计

## 修订记录

| 日期       | 修改人 | 备注     |
| :--------- | :----- | :------- |
| 2026-06-05 | Claude | 初始版本 |

## 系统概述

SnapVault（暂存区）是一款 macOS 原生剪贴板历史管理工具，面向需要频繁复制粘贴内容的开发者、设计师和文字工作者。系统通过全局监听剪贴板变化、OCR 识别图片文字、Spotlight 全文搜索等能力，解决 macOS 原生剪贴板"只能存一条"的痛点，让用户快速检索和复用历史复制内容。

## 设计目标

- **即时响应**：剪贴板监听延迟 < 100ms，搜索结果 < 200ms 返回，快捷键唤起面板 < 150ms
- **低资源占用**：常驻内存 < 50MB，CPU 空闲占用 < 1%，数据库文件 < 500MB（默认保留 30 天）
- **原生体验**：100% SwiftUI 构建，遵循 macOS Human Interface Guidelines，支持 Dark Mode、VoiceOver
- **数据安全**：所有数据仅存本地 SQLite，不联网传输；数据库文件使用 macOS Data Protection
- **可扩展性**：模块化架构，各子系统（OCR、搜索、存储）独立可替换

## 整体架构

### 分层结构

系统采用 **MVVM + 服务层** 的分层架构，分为四层：

```
┌─────────────────────────────────────────────────┐
│                   表现层 (Presentation)           │
│         SwiftUI Views + ViewModels               │
├─────────────────────────────────────────────────┤
│                   业务层 (Business)               │
│    ClipboardManager / SearchEngine / OCRService  │
├─────────────────────────────────────────────────┤
│                   数据层 (Data)                   │
│         GRDB Repository + Models                 │
├─────────────────────────────────────────────────┤
│                   平台层 (Platform)               │
│   NSPasteboard / Vision / ScreenCaptureKit / OSLog│
└─────────────────────────────────────────────────┘
```

### 模块划分

| 模块                 | 职责                                           | 关键类型                    |
| :------------------- | :--------------------------------------------- | :-------------------------- |
| **App Shell**        | 应用生命周期、菜单栏图标、全局快捷键注册       | `AppDelegate`, `MenuBarView`|
| **ClipboardMonitor** | 监听系统剪贴板变化，去重过滤，触发存储         | `ClipboardMonitor`          |
| **ContentStore**     | 数据持久化、查询、清理过期数据                 | `ContentRepository`         |
| **SearchEngine**     | 全文搜索、Spotlight 索引同步                   | `SearchService`             |
| **OCRService**       | 图片文字识别，提取可搜索文本                   | `OCRProcessor`              |
| **PreviewPanel**     | 内容预览窗口（文本/图片/富文本/文件）          | `PreviewView`               |
| **SettingsModule**   | 偏好设置界面与持久化                           | `SettingsView`, `Settings`  |
| **UpdateService**    | 自动更新检查与安装                             | `SparkleUpdater`            |

### 交互关系

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

**核心数据流 —— 用户检索：**

```
用户输入快捷键 ──> MenuBarView / FloatingPanel
                       │
                       ├─ 搜索框输入 ──> SearchService.query()
                       │                     │
                       │                     ├─ GRDB FTS5 全文搜索
                       │                     └─ Spotlight metadata 查询
                       │
                       ├─ 结果列表 ──> ClipboardItem 列表
                       │
                       └─ 用户选择 ──> NSPasteboard.write() ──> 粘贴到当前应用
```

## 技术选型

| 领域     | 选择                  | 理由                                                                       | 备选方案                  |
| :------- | :-------------------- | :------------------------------------------------------------------------- | :------------------------ |
| UI 框架  | SwiftUI               | 声明式 UI，macOS 原生支持，Apple 生态未来方向，代码量少于 AppKit            | AppKit（更成熟但更冗长）  |
| 系统桥接 | AppKit                | SwiftUI 部分能力不足（如 NSWindow 控制、全局事件监听），需 AppKit 补充       | 纯 SwiftUI（能力不够）    |
| OCR      | Vision (VNRecognizeTextRequest) | 系统内置，无需额外依赖，支持中英文，离线可用               | Tesseract（需打包模型）   |
| 截图     | ScreenCaptureKit      | macOS 12+ 原生 API，高性能，支持窗口/区域捕获                              | CGWindowListCreateImage   |
| 搜索     | Spotlight (NSMetadataQuery) | 系统级全文搜索，零额外索引成本，与 macOS 深度集成          | 自建倒排索引（复杂度高）  |
| 剪贴板   | NSPasteboard          | macOS 标准剪贴板 API，changeCount 监听变化                                 | 无备选                    |
| 存储     | SQLite + GRDB         | GRDB 是 Swift 生态最成熟的 SQLite 封装，类型安全，支持 FTS5 全文搜索、Migration | Core Data（过重）、Realm  |
| 快捷键   | KeyboardShortcuts     | 轻量级 Swift 库，macOS 原生快捷键注册，支持录制                            | HotKey（较老）            |
| 自动更新 | Sparkle                | macOS 应用更新事实标准，支持 Delta更新、签名验证、静默更新                   | 自建更新（工作量大）      |
| 日志     | OSLog                 | 系统内置，统一日志系统，支持 Console.app 查看，性能极佳                     | CocoaLumberjack、SwiftLog |

### 已知局限

- **SwiftUI**：部分高级窗口控制（如 Panel 样式、精确的窗口层级）需回退到 AppKit
- **ScreenCaptureKit**：最低要求 macOS 12.3，需在 Info.plist 中声明最低系统版本
- **Vision OCR**：复杂排版（如表格、多栏）识别率有限，后续可考虑 VisionKit 增强
- **Spotlight**：索引有延迟，新内容需通过 GRDB FTS5 作为主搜索，Spotlight 作为补充

## 详细方案索引

| 领域     | 文档                                     | 说明                       |
| :------- | :--------------------------------------- | :------------------------- |
| 数据库设计 | [architecture_db.md](architecture_db.md) | SQLite 表结构、索引、迁移策略 |
| 接口设计  | [architecture_api.md](architecture_api.md) | 模块间内部接口定义          |

## 关键设计决策

### 1. 剪贴板监听策略

采用 **定时轮询 changeCount** 的方式而非 `NSPasteboard` 的 `changeCount` KVO（macOS 不可靠）。

- 轮询间隔：500ms（平衡响应速度与 CPU 占用）
- 去重逻辑：对内容计算 SHA256 hash，与最近 10 条记录比对
- 空闲优化：应用失去焦点时降低轮询频率至 2s

### 2. 数据库选型理由

使用 GRDB 而非 Core Data 的原因：
- Core Data 的 `NSFetchedResultsController` 在 SwiftUI 中适配不自然
- GRDB 原生支持 FTS5 全文搜索，满足 PRD-05 的搜索需求
- GRDB 的 Migration 机制更适合版本迭代
- 更轻量，编译速度更快

### 3. 浮动面板 vs 独立窗口

采用 **NSPanel（浮动面板）** 而非普通 NSWindow：
- 面板在失去焦点时自动隐藏（`becomesKeyOnlyIfNeeded`）
- 可设置为 `NSPanel.Level.floating`，覆盖其他应用
- 不出现在 Dock 和 Mission Control 中

### 4. 图片 OCR 流程

```
图片进入 ──> 检查尺寸（跳过 < 50x50 的图标）
         ──> VNRecognizeTextRequest（支持中英文混合识别）
         ──> confidence > 0.5 的结果拼接为文本
         ──> 存入 clipboard_items.ocr_text 字段
         ──> 同步到 FTS5 索引
```

## 变更记录

| 日期       | 变更内容 |
| :--------- | :------- |
| 2026-06-05 | 初始版本：基于 PRD 创建总体架构设计 |
