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
