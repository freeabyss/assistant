# Assistant 全局文档

Mac Super Assistant 项目的最新累积文档。所有内容随每次迭代 ⑥ 上线归档更新。

## 目录

- [onboarding.md](onboarding.md) — 新工程师上手指南（先读这个）
- [prd.md](prd.md) — 产品需求
- [architecture/design.md](architecture/design.md) — 架构总设计
- [architecture/api.md](architecture/api.md) — 内部接口设计
- [architecture/db.md](architecture/db.md) — 数据模型设计
- [architecture/review.md](architecture/review.md) — 架构评审记录
- [test/cases.md](test/cases.md) — 测试用例
- [test/report.md](test/report.md) — 测试执行摘要
- [iterations/](iterations/) — 各迭代历史（含 v1.0.0 追溯归档）

## 版本记录

| 版本 | 上线日期 | 主题 | 关键变更 |
|------|---------|------|---------|
| v1.2.0 | 2026-07-07 | 产品全面审视 + 品牌改名青鸟 Qingniao | 品牌定名青鸟 Qingniao；文件搜索接入（FileSearchSource）；全屏截图全局热键 ⌃⌥⌘3；版本号三源一致；Onboarding 单屏 + 辅助功能按需申请；关闭 Sandbox 改 Developer ID 分发；死代码清理；Jade 设计系统；AppContainer DI 拆分；Command Bar 重写；剪贴板历史独立窗口；设置 11 页；截图标注 pill 工具条；CHANGELOG 格式统一 |
| v1.0.0 | 2026-07-02 | Mac Super Assistant MVP | 首次上线：菜单栏应用形态；Core Data + 文件系统数据层；剪贴板监控与历史；应用/文件/单位换算搜索源；命令白名单；截图与标注；设置/权限入口；发布材料（README、隐私政策、CHANGELOG、Third-Party Notices） |
| v1.0.1 | 2026-07-02 | Bug 修复 | 修复启动时“无法启动更新程序”弹窗（Issue #1、PR #2）；产品行为不变，“检查更新”继续跳转 GitHub Releases |
| v1.1.0 | 2026-07-03 | Onboarding 死锁修复 | 修复 onboarding 屏幕录制权限申请断点（TCC 权限申请触发，App 出现在系统设置列表）+ 新增 onboarding “跳过设置”入口（Issue #3、PR #4）；AC-6/AC-7 端到端待下一迭代验证 |
