# v1.0.0 架构评审（追溯说明）

## 版本记录

| 版本 | 上线日期 | 说明 |
|------|---------|------|
| v1.0.0 | 2026-07-02 | 首次上线，Mac Super Assistant MVP（22 个用户故事） |

> 本文件由 v1.0.0 追溯归档整改生成。

## 追溯说明

v1.0.0 迭代事实上**未按 leader 规范执行独立架构评审环节**（无独立评审会、无评审记录）。当时的开发采用「文档先行 + 代码实现 + 测试验收」的一体化流程，架构正确性由后续的 **code review 与集成测试**（`swift test` 124/124、`xcodebuild test` 119/119 全绿，22/22 任务通过）事实性代替架构评审。

本文件作为追溯补录，从 `design.md`、`api.md`、`db.md` 中提炼关键设计决策，作为回顾性评审要点。从 v1.0.1 / v1.1.0 起将严格按 leader 六状态规范走独立架构评审（④）。

## 追溯评审要点（关键设计决策回顾）

1. **分层架构**：采用 `SwiftUI/AppKit Shell + MVVM + Service + Provider + Local Data` 分层，所有核心能力通过统一搜索框（`⌥ Space`）触发，复杂/低频操作由管理中心承载；产品形态为菜单栏 App，无 Dock 图标（`LSUIElement=true`）。

2. **数据存储选型**：主存储采用 **Core Data + 文件系统**，明确放弃 SQLite/GRDB/FTS5。结构化数据入 Core Data，图片原图/缩略图/RTF/HTML 大对象以 UUID 命名落文件系统，Core Data 只存相对路径/资源标识与 contentHash。

3. **轻量内存搜索索引**：剪贴板搜索使用 Core Data 持久化 + 启动时全量加载的轻量内存索引（不加载大对象），而非 FTS5；搜索命中后按需回源加载详情，兼顾冷启动 ≤1s、搜索响应 ≤100ms、常驻内存 ≤150MB 的非功能目标。

4. **SearchSource Provider 聚合架构**：统一搜索由多个 Provider（AppSource / ClipboardSource / CommandSource / CalculatorSource / SettingsSource）聚合，按「来源基础优先级 + 文本匹配分 + 最近使用加权」排序，总上限 12 条，不分组。

5. **安全边界**：内置命令严格白名单（14 个），中风险命令强制二次确认，明确禁止任意 shell、sudo、关机/重启系统/注销、删除文件、杀进程；数据默认仅本地保存，不上传/同步/训练。MVP Scope Guard 明确排除 OCR、文件搜索、货币换算、账号/支付、自动安装更新、签名公证等。
