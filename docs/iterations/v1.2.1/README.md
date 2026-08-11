# v1.2.1 迭代

- **主题**：欢迎页面路由 bug 修复 + 关闭按钮补充
- **状态**：in_progress
- **当前节点**：⑤ XCUITest 扩展代码就绪（target+hook+a11y+22 条用例；UI 测试跑通待用户 GUI 授权，T-UI-005/007 blocked）
- **模式**：manual
- **Issue**：#7
- **分支**：v1.2.1
- **PR**：-
- **开始日期**：2026-07-07
- **上线日期**：-

## 状态推进

- [x] ① 需求分析（Bug 分析） —— prd.md
- [x] ② 产品设计 —— prd.md
- [x] ③ 架构设计 —— architecture/design.md
- [x] ④ 架构评审 —— architecture/review.md
- [x] ⑤ 开发测试 -- progress.md（swift test 181/181，xcodebuild EXIT=0）
- [x] ⑤ 扩展：XCUITest 自动化测试（架构设计 + 评审 + 用例 + 代码全部完成） -- architecture/xcuitest-design.md + xcuitest-review.md + test/cases.md
- [x] ⑤.1 XCUITest 用例生成完成（TC-UI-001~022，首批 P0=10 / 次批 P1=12） -- test/cases.md
- [x] ⑤.2 XCUITest 代码就绪（target+hook+a11y+22 条用例，build-for-testing SUCCEEDED，swift test 181/181）；UI 测试跑通待用户 GUI 授权（T-UI-005/007 blocked） -- test/report.md
- [ ] ⑥ 上线部署

## 关键节点
- 2026-07-07 Gate 1 待审阅（Bug 分析 + PRD）
- 2026-07-13 ③④⑤ 完成（架构设计 + 评审 + 开发测试）；⑥ 待上线
- 2026-07-13 ⑤ 扩展：XCUITest 自动化测试架构设计补充完成（xcuitest-design.md），待 Gate 2 审阅
- 2026-07-13 ⑤.2 XCUITest 代码就绪（target+hook+a11y+22 条用例，build-for-testing SUCCEEDED，swift test 181/181）；UI 测试跑通阻塞于 macOS UI automation 首次 GUI 授权（T-UI-005/007 blocked，T-UI-008 report 完成）
