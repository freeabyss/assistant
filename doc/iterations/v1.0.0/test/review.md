# v1.0.0 测试用例评审(追溯说明)

> 本文件由 v1.0.0 追溯归档整改生成。

## 追溯说明

v1.0.0 迭代**未按 leader 规范执行独立的测试用例评审环节**。当时测试方案（见 [cases.md](cases.md)）与实现同步演进，用例的有效性由**实际测试执行结果**事实性代替用例评审：

- `swift test`：124/124 通过、0 失败
- `xcodebuild test`：119/119 通过、0 失败（`** TEST SUCCEEDED **`）
- `xcodebuild build`：`** BUILD SUCCEEDED **`
- 22/22 用户故事（US-001 ~ US-022）全部 `passes=true`

自动化覆盖矩阵已覆盖 SearchSource、搜索排序、拼音、CalculatorSource、单位换算、contentHash 去重、Core Data 临时 store、FileResourceStore、ClipboardRepository、InMemorySearchIndex、黑名单与使用统计等核心逻辑；系统级交互（权限弹窗、菜单栏、全局快捷键、真实截图、邮件/浏览器）保留为 release-candidate 环境的手动验收清单，后台子 Agent 未虚构人工结果。

详细执行记录见同目录 [report.md](report.md)。从 v1.0.1 / v1.1.0 起将按 leader 规范执行独立用例评审。
