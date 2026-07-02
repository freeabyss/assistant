# Mac Super Assistant（Assistant）v1.0.0 测试执行报告

## 版本记录

| 版本 | 上线日期 | 说明 |
|------|---------|------|
| v1.0.0 | 2026-07-02 | 首次上线，Mac Super Assistant MVP（22 个用户故事） |

> 本文件为 v1.0.0 迭代的测试执行结果、通过/失败统计与自动化基线摘要。用例定义见同目录 [cases.md](cases.md)，开发进度流水见 [../progress.md](../progress.md)。

## 执行结果摘要卡片

| 维度 | 结果 |
| :--- | :--- |
| 任务完成 | 22/22 通过（US-001 ~ US-022） |
| `swift test` | 124/124 通过、0 失败 |
| `xcodebuild build` | `** BUILD SUCCEEDED **` |
| `xcodebuild test` | 119/119 通过、0 失败，`** TEST SUCCEEDED **` |
| 阻塞项 | 无 |
| 手动验收 | 系统权限/菜单栏/全局快捷键/真实截图/邮件/浏览器等 P0/P1 手动项需在 release-candidate 环境执行（后台子 Agent 未虚构人工结果） |

已知遗留 warning：`--skip-update` deprecation warning、既有 Swift 6 Sendable/NSLock warning，不影响测试通过。

---

## 执行记录（时间线）

### 2026-06-12 - US-001 App Shell 验证

- `swift test --skip-update`：通过，执行 35 个 XCTest，35 通过、0 失败。
- `xcodebuild -project SnapVault.xcodeproj -scheme SnapVault -configuration Debug build`：通过，产物为 `Assistant.app`。
- `xcodebuild test -project SnapVault.xcodeproj -scheme SnapVault -configuration Debug`：通过,执行 35 个 XCTest，35 通过、0 失败。
- 验证重点：macOS 13 deployment target 保持 13.0；Info.plist 保持 `LSUIElement=true`；菜单栏 App Shell 与菜单项已具备构建级验证，真实菜单栏交互仍按手动验收 `MENU-001` ~ `MENU-004` 执行。

### 2026-06-12 - US-009 CalculatorSource 计算与单位换算验证

- `swift test --skip-update`：通过，执行 87 个 XCTest，87 通过、0 失败。
- `xcodebuild -project /Users/abyss/workspace/abyss/assistant/SnapVault.xcodeproj -scheme SnapVault -configuration Debug build`：通过，`** BUILD SUCCEEDED **`。
- `xcodebuild test -project /Users/abyss/workspace/abyss/assistant/SnapVault.xcodeproj -scheme SnapVault -configuration Debug`：通过，执行 87 个 XCTest，87 通过、0 失败，`** TEST SUCCEEDED **`。
- 验证重点：基础四则、括号、小数、除零/非法表达式防护、长度/重量/数据大小/温度换算、货币/复杂函数/变量/历史/范围外单位拒绝、`SearchService.execute(.copyText)` 写入系统剪贴板。

### 2026-06-13 - US-021 测试基线与自动化验收

- `swift test --skip-update`：通过，执行 122 个 XCTest，122 通过、0 失败。
- `xcodebuild -project /Users/abyss/workspace/abyss/assistant/SnapVault.xcodeproj -scheme SnapVault -configuration Debug build`：通过，`** BUILD SUCCEEDED **`。
- `xcodebuild test -project /Users/abyss/workspace/abyss/assistant/SnapVault.xcodeproj -scheme SnapVault -configuration Debug`：通过，执行 117 个 XCTest，117 通过、0 失败，`** TEST SUCCEEDED **`。
- 验证重点：确认并记录 SwiftPM/Xcode 测试入口；建立自动化覆盖矩阵，覆盖 SearchSource、搜索排序、拼音、CalculatorSource、单位换算、contentHash 去重、Core Data 临时 store、FileResourceStore 临时目录、ClipboardRepository、InMemorySearchIndex、黑名单、使用统计；整理 P0/P1 自动化或手动验证方式，权限、截图、全局快捷键、菜单栏、Onboarding 等系统交互保留为手动验收清单。

### 2026-06-13 - US-022 MVP 集成验收与文档收尾

- 依赖状态：`.claude/task.json` 中 US-001 ~ US-021 均为 `passes=true`、`blocked=false`，US-022 依赖满足。
- 文档一致性：复核 `doc/prd.md`、`doc/architecture.md`、`doc/architecture_db.md`、`doc/architecture_api.md`、`doc/test.md` 与当前实现；`doc/prd.md` 和 `doc/architecture_db.md` 的未提交内容确认属于当前 Assistant MVP 文档基线（Core Data + 文件系统、Provider 架构、GitHub Release + 项目主页发布、范围排除），纳入本次收尾提交。
- 范围外能力检查：确认 MVP 用户入口不包含账号、支付、订阅、Mac App Store、任意 shell、sudo、关机/重启系统/注销、签名公证或自动安装更新；检查更新入口打开 GitHub Releases 手动下载。旧 SnapVault 兼容源码中遗留的 OCR / ContentStore / FileSearchSource 实现已从 SwiftPM target 与 Xcode App target 构建输入排除，避免进入 MVP 构建产物；源文件仍留存为历史兼容归档，后续可单独清理。
- GitHub Release + 项目主页发布材料：复核 `README.md`、`PRIVACY.md`、`CHANGELOG.md`、`THIRD_PARTY_NOTICES.md`、`ReleaseLinks`、`appcast.xml`，确认项目主页、隐私政策、反馈邮箱、版本记录和 GitHub Releases 链接已准备；真实截图/GIF 仍需发布前从候选构建捕获。
- `swift test --skip-update`：通过，执行 124 个 XCTest，124 通过、0 失败。仍有 `--skip-update` deprecation warning 与既有 Swift 6 Sendable/NSLock warning，不影响通过。
- `xcodebuild -project /Users/abyss/workspace/abyss/assistant/SnapVault.xcodeproj -scheme SnapVault -configuration Debug build`：通过，`** BUILD SUCCEEDED **`。
- `xcodebuild test -project /Users/abyss/workspace/abyss/assistant/SnapVault.xcodeproj -scheme SnapVault -configuration Debug`：通过，执行 119 个 XCTest，119 通过、0 失败，`** TEST SUCCEEDED **`。
- 手动验收记录：本次后台子 Agent 无法可靠操作真实菜单栏、系统权限弹窗、全局快捷键、屏幕录制授权、辅助功能授权、真实截图捕获、邮件客户端和浏览器页面；未虚构人工结果。相关 P0/P1 手动项仍按 [cases.md](cases.md) 第 5/6/7 节在 release-candidate 环境执行。
- 已知问题 / 后续建议：发布前捕获 README 所列产品截图/GIF；在真实 macOS 环境复测 Onboarding 权限拒绝/授权、菜单栏无 Dock、全局快捷键、截图三模式、剪贴板真实格式恢复、邮件反馈和 GitHub Releases 打开；扩大公开分发前补齐 Developer ID 签名与 Apple Notarization；后续单独删除或归档未参与构建的旧 SnapVault OCR/文件搜索源码和旧本地化键。

---

## v1.0.1（2026-07-02，Issue #1、PR #2）

- **swift test**：126/126 全绿（基线由 v1.0.0 的 124 提升 +2）
- **xcodebuild test**：119/119 TEST SUCCEEDED（新增用例未纳入 Xcode SnapVaultTests target，P2 遗留）
- **手动验收**：TC-M-001（Debug 启动无弹窗）/ TC-M-002（Release 启动无弹窗）/ TC-M-003（检查更新跳浏览器）均由 @user 亲自执行通过
- **覆盖 AC**：AC-1 / AC-2 / AC-3 / AC-4 全通过
- **详情**：doc/iterations/v1.0.1/test/report.md
