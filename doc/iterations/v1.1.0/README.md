# v1.1.0 迭代

- **主题**：Onboarding 死锁修复 —— TCC 权限申请触发 + 允许跳过向导
- **状态**：in_progress
- **当前节点**：① 需求分析
- **模式**：auto
- **Issue**：#3
- **分支**：v1.1.0
- **PR**：-
- **开始日期**：2026-07-02
- **上线日期**：-

## 迭代说明

本迭代同时处理一个 P0 bug（阻塞用户进入应用）和一个新功能，两者代码触点重叠、修复路径互补，合并为同一 minor 迭代：

- **T-001 类**（Bug）：修复屏幕录制权限申请断点 —— `PermissionService` 增加 `CGRequestScreenCaptureAccess()` 触发
- **T-002 类**（Feature）：Onboarding 增加"跳过设置"入口 —— 状态机加 skip 分支 + footer 加按钮

**走全六状态**（不精简）：既涉及新功能（跳过后的行为、被延后权限的申请策略）需要产品设计，也涉及权限状态机、按需申请触发点的架构变更，需要架构设计与评审。

## 状态推进

- [ ] ① 需求分析 —— prd.md（含 Bug 部分复述根因）
- [ ] ② 产品设计 —— prd.md
- [ ] ③ 架构设计 —— architecture/design.md
- [ ] ④ 架构评审 —— architecture/review.md（Gate 2）
- [ ] ⑤ 开发测试
  - [ ] 测试用例生成 —— test/cases.md
  - [ ] 用例评审 —— test/review.md
  - [ ] 任务拆解 —— tasks.json（Gate 3）
  - [ ] 单任务开发 → code review → 测试
- [ ] ⑤ 收尾 —— 开 PR（Gate 4）
- [ ] ⑥ 上线部署（Gate 5，用户触发）

## 关键节点

- 2026-07-02 迭代初始化，issue #3 创建，分支 v1.1.0 创建
