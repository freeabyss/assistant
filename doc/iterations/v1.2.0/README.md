# v1.2.0 迭代

- **主题**：青鸟 Qingniao —— 产品全面审视 + 品牌改名
- **状态**：in_progress
- **当前节点**：① 需求分析 + ② 产品设计
- **模式**：manual
- **Issue**：#5
- **分支**：v1.2.0
- **PR**：-
- **开始日期**：2026-07-03
- **上线日期**：-

## 迭代说明

用户正式确立产品名：中文「青鸟」、英文 **Qingniao**。

本次迭代特殊约定：
- 审视阶段（①②③④）直接修订 doc/ 全局文件（用户明确授权，跳过双轨暂存）
- doc/iterations/v1.2.0/ 只存放：本迭代的架构增量、test/cases.md 增量、tasks.json、progress.md、reviews/
- Bundle ID `com.assistant.app` 保留不变，避免用户权限/容器失效
- Xcode 工程、target、源码目录、显示名、文案全面改名
- PRD/架构审视发现的产品不足直接落到文档修订中；对应的代码改动在 ⑤ 逐任务开发

## 状态推进

- [x] ① 需求分析 —— doc/prd.md（直接修订，commit e41dc56）
- [x] ② 产品设计 —— doc/prd.md（直接修订，Gate 1 通过 2026-07-03，commit 510d857）
- [x] ③ 架构设计 —— doc/architecture/*.md（直接修订，commit e9c448f）
- [x] ④ 架构自审 —— doc/iterations/v1.2.0/architecture/review.md（APPROVED_WITH_MINOR_FIXES，0 阻塞），Gate 2 待审阅
- [ ] ⑤ 开发测试
- [ ] ⑥ 上线部署

## 关键节点

- 2026-07-03 迭代初始化，issue #5 创建，分支 v1.2.0 创建（commit ed4e524）
- 2026-07-03 PRD 重写完成（commit e41dc56），进入 Gate 1
- 2026-07-03 PRD UI 设计语言补全（commit 510d857），Gate 1 通过 by @user
- 2026-07-03 架构设计完成（design.md v17 / api.md v3 / db.md v3），架构自审 APPROVED（0 阻塞，6 改善），commit e9c448f，进入 Gate 2
