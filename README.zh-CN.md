# Mac Super Assistant

[English](README.md) | **简体中文**

> 本地优先的 macOS 指挥中心：Spotlight 风格搜索、剪贴板历史、截图、安全命令与设置，全部集成在一个菜单栏应用中。

Mac Super Assistant（内部项目代号：Assistant）是一款面向公开 Beta 的原生 macOS 效率助手。它常驻菜单栏，通过 `⌥ Space` 快捷键唤起，并默认将剪贴板、截图和设置数据保留在本机。

## 产品页清单

| 项目 | MVP 内容 |
| --- | --- |
| 产品名称 | Mac Super Assistant |
| 标语 | 本地优先的 macOS 指挥中心。 |
| 核心功能 | 统一搜索、应用启动、剪贴板历史、截图与标注、安全内置命令、计算器 / 单位换算、设置与权限中心。 |
| 截图 / 演示 GIF | MVP 构建完成后使用 `/assets/product/search-panel.png`、`/assets/product/clipboard-history.png`、`/assets/product/screenshot-annotation.gif`。在图像被提交到仓库之前，本 README 是发布所需素材的占位清单。 |
| 下载按钮 | [从 GitHub Releases 下载最新公开 Beta](https://github.com/abyss/assistant/releases)。 |
| 版本历史 | [CHANGELOG.md](CHANGELOG.md) 与 [GitHub Releases](https://github.com/abyss/assistant/releases)。 |
| 隐私政策 | [PRIVACY.md](PRIVACY.md)。 |
| 反馈邮箱 | [feedback@assistant.app](mailto:feedback@assistant.app)。 |
| FAQ | 查看 [常见问题](#常见问题)。 |

## 下载

[下载最新公开 Beta](https://github.com/abyss/assistant/releases)

MVP 仅通过 GitHub Releases 分发。MVP 不含账号系统、支付、订阅、许可证密钥，也不通过 Mac App Store 交付。

## 核心功能

- **统一搜索入口**：按 `⌥ Space` 打开居中的 Spotlight 风格搜索面板，可搜索应用、命令、设置、剪贴板项、计算器结果与单位换算。
- **应用启动器**：搜索 `/Applications`、`~/Applications` 与 `/System/Applications` 下的应用，支持中文拼音与首字母匹配（在可用时）。
- **剪贴板历史**：本地记录文本、富文本、图片和 Finder 文件引用，支持搜索、置顶、保留期设置与一键清除。
- **截图与轻量标注**：支持区域、全屏或窗口截图；支持矩形、箭头、文本与马赛克 / 模糊标注；可复制或保存为 PNG。
- **安全内置命令**：仅可运行固定白名单内的常用 macOS 命令。清空剪贴板历史、重启 Finder/Dock 等中等风险操作需要二次确认。
- **设置与权限中心**：集中管理搜索源、快捷键、剪贴板保留期、截图保存目录、语言、启动行为、权限、隐私、反馈与发布链接。

## 截图与演示素材

MVP 产品页在更大范围公开分发之前，应包含以下发布素材：

1. `assets/product/search-panel.png` — 统一搜索面板，展示应用、命令、设置、计算器与剪贴板结果示例。
2. `assets/product/clipboard-history.png` — 剪贴板历史页面，包含类型筛选、搜索、置顶、删除、存储用量与清空入口。
3. `assets/product/screenshot-annotation.gif` — 截图预览、标注工具栏、复制、保存与取消流程。
4. `assets/product/onboarding-permissions.png` — 引导流程中对屏幕录制与辅助功能权限的说明。

这些素材是 US-020 的预留占位，应在最终发布准备阶段基于已签名或发布候选版本捕获。

## 权限说明

Mac Super Assistant 只申请与 MVP 相关的 macOS 权限，且在请求前会给出解释：

- **屏幕录制**：区域、全屏与窗口截图所必需。截图在本地处理，不会上传。
- **辅助功能**：用于 MVP 权限门槛，以及为未来可能的模拟快捷键、自动粘贴、窗口控制与控制其他应用等系统控制能力建立边界。当前 MVP 使用仅限于用户显式触发的应用功能与安全内置命令流程。
- **Apple Events / 自动化**：仅用于用户显式触发的白名单内置命令。应用不会执行任意 Shell 命令。
- **剪贴板访问**：macOS 对剪贴板读取不会单独弹出权限提示，因此引导流程与隐私政策明确说明：剪贴板历史默认开启、仅本地存储，可随时暂停或清空。

## 隐私默认设置

- 剪贴板元数据与内容存储在本地的 Core Data 与应用支持目录中。
- 截图在本地捕获、标注、复制或保存。
- 文件类型的剪贴板历史仅存储文件引用与路径,不复制文件内容。
- MVP 不接入任何账号系统、云同步、埋点后端、支付、订阅或训练流水线。
- 反馈仅由用户主动发送邮件；不会静默发送诊断数据。

完整内容请阅读 [隐私政策](PRIVACY.md)。

## 版本历史

发布说明见 [CHANGELOG.md](CHANGELOG.md)。应用内的 **检查更新** 操作会打开 [GitHub Releases](https://github.com/abyss/assistant/releases),用户可手动下载更新。MVP 不会自动下载、自动安装或重启以完成更新。

## 反馈

请将 bug 报告、建议与公开 Beta 反馈发送至 [feedback@assistant.app](mailto:feedback@assistant.app)。应用生成的反馈邮件会包含应用版本、构建号、macOS 版本、可选的错误摘要以及你的备注。不会附带剪贴板历史、截图、文件或自动崩溃日志。

## 常见问题

### Mac Super Assistant 免费吗？

免费。MVP 完全免费,不含支付、订阅、许可证密钥、账号或 Mac App Store 流程。

### 我在哪里下载更新？

使用 [GitHub Releases](https://github.com/abyss/assistant/releases)。应用的 **检查更新** 按钮会打开同一页面。

### 应用会上传我的剪贴板或截图吗？

不会。剪贴板历史、截图、设置与搜索使用数据均为本地优先,除非你在反馈邮件中手动附带相关信息,否则不会离开你的 Mac。

### 我可以关闭剪贴板历史吗？

可以。你可以在“设置”中暂停剪贴板记录,并在剪贴板历史页面或通过内置命令清空历史。

### 为什么应用需要屏幕录制权限？

macOS 要求截图捕获必须获得屏幕录制权限。该权限仅用于区域、全屏与窗口截图。

### 为什么应用需要辅助功能权限？

MVP 在引导流程中申请辅助功能权限,是为了确立当前与未来 macOS 控制能力的权限边界。产品页与引导流程会说明当前 MVP 的用途与未来能力边界,便于用户在授予前作出决定。

### MVP 支持任意 Shell 命令吗？

不支持。仅提供固定白名单内的安全内置命令。任意 Shell、`sudo`、关机、重启系统、注销、删除文件与结束进程等操作均不在范围内。

### 是否已在 Mac App Store 上架？

否。MVP 通过 GitHub Releases 分发,不包含 Mac App Store 上架流程。

## 第三方声明

请见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
