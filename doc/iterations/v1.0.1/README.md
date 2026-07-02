# v1.0.1 迭代

- **主题**：修复启动时 Sparkle updater 弹窗错误
- **状态**：in_progress
- **当前节点**：① Bug 分析
- **模式**：manual（精简 bug 版）
- **Issue**：#1
- **分支**：v1.0.1
- **PR**：-
- **开始日期**：2026-07-02
- **上线日期**：-

## 精简说明

本迭代为 patch 级 bug 修复，改动仅 1 行代码 + 无架构影响，按 leader 精简 bug 流程执行：
- 用 `bug.md` 替代 `prd.md`（① Bug 分析产物）
- **跳过 architecture/**（无架构改动，无需设计与评审）
- 保留 test/、tasks.json、progress.md、reviews/ 完整流程

## 状态推进

- [ ] ① Bug 分析 —— bug.md
- [ ] ⑤ 开发测试
  - [ ] 测试用例生成 —— test/cases.md
  - [ ] 用例评审 —— test/review.md
  - [ ] 任务拆解 —— tasks.json（Gate 3）
  - [ ] 单任务开发 → code review → 测试
- [ ] ⑤ 收尾 —— 开 PR（Gate 4）
- [ ] ⑥ 上线部署（Gate 5，用户触发）

## 关键节点

（待填）
