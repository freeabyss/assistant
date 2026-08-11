# Bug: 启动时 Sparkle updater 弹窗

## 一、基本信息

- **发现时间**：2026-07-02
- **报告人**：@abyss
- **严重程度**：中（不阻塞使用，但每次启动都出现，严重影响用户信任感）
- **影响版本**：v1.0.0（Info.plist SUPublicEDKey 从 MVP 阶段就是占位符）
- **修复版本**：v1.0.1

## 二、症状描述

应用启动完成后立即弹出系统对话框：

> 无法启动更新程序。请验证是否有最新版本的 Mac Super Assistant，并联系 App 开发者如果此问题持续。请查看控制台以获得更多信息。

关闭后应用可正常使用，但每次启动重复出现。

## 三、复现步骤

1. 通过 `./build_and_run.sh run` 或 Xcode 构建 SnapVault.app（Debug/Release 均可）
2. 启动应用
3. 观察：应用主窗口出现后 0.5-1 秒内弹出上述对话框
4. 点击关闭 → 主功能可用

## 四、根因分析

### 直接原因
- `SnapVault/Info.plist:47-48` 中 `SUPublicEDKey` 为占位符 `REPLACE_WITH_YOUR_EDDSA_PUBLIC_KEY`
- `SnapVault/Services/UpdateService/UpdateService.swift:62` 使用 `SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)`
- Sparkle 2 在 `startUpdater:` 阶段做配置强校验：`SUFeedURL` 已配置但 `SUPublicEDKey` 非合法 EdDSA 公钥 → 视为签名配置不足 → 抛出致命错误 → 标准控制器弹出用户可见的错误对话框

### 深层原因
MVP 阶段（v1.0.0）自动更新策略是"点击检查更新 → 跳转 GitHub Releases"（见 `UpdateService.checkNow()`），但代码里仍启用了 Sparkle 的完整启动流程，配置又不完备，导致启动期强校验失败。

## 五、修复方案（v1.0.1 采用）

### 方案：关闭启动期 updater 启动

将 `UpdateService.swift:62` 的：

```swift
updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: self,
    userDriverDelegate: nil
)
```

改为：

```swift
updaterController = SPUStandardUpdaterController(
    startingUpdater: false,
    updaterDelegate: self,
    userDriverDelegate: nil
)
```

### 为什么这样修

- MVP 阶段"检查更新"实际走 `checkNow()` → `NSWorkspace.open(GitHub Releases URL)`，从未依赖 Sparkle 的 `checkForUpdates()`
- `startingUpdater: false` 让 Sparkle controller 只做惰性初始化、不在启动期执行签名校验，弹窗根源消除
- controller 实例仍然创建，未来启用真自动更新时（v1.x 后续版本）只需切回 `true` + 配置真密钥即可，无回退成本

### 拒绝方案 B/C 的理由

- 方案 B（填真 EdDSA 公钥 + 补 appcast 签名）：需要密钥托管、发布流程改造，超出 patch 范围
- 方案 C（entitlements + XPC service key）：方案 B 的配套，同样超出范围

## 六、已知遗留（不在本迭代处理）

以下问题在诊断中被识别，但本 patch 迭代不处理，作为技术债留待后续版本：

| 编号 | 遗留项 | 位置 | 建议版本 |
|------|--------|------|---------|
| L-1 | `SUPublicEDKey` 占位符 | `SnapVault/Info.plist:47-48` | 启用真自动更新时（v1.x） |
| L-2 | entitlements 缺 `com.apple.security.network.client` | `SnapVault/SnapVault.entitlements` | 同上 |
| L-3 | `Info.plist` 缺 `SUEnableInstallerLauncherService` / `SUEnableDownloaderService` | `SnapVault/Info.plist` | 同上 |
| L-4 | `Resources/appcast.xml` 签名与长度为占位符 | `SnapVault/Resources/appcast.xml` | 同上 |
| L-5 | `CFBundleShortVersionString` 为 0.1.0 | `SnapVault/Info.plist:19` | 下个版本统一 release 号时 |

## 七、验收标准

- **AC-1**：启动 SnapVault.app 不再出现"无法启动更新程序"弹窗（Debug 与 Release 各验证一次）
- **AC-2**：Help / 设置菜单中的"检查更新"点击后仍能正常打开浏览器跳转 GitHub Releases 页
- **AC-3**：`swift test` 全绿；`xcodebuild test` 全绿（保持 v1.0.0 基线数量或更多）
- **AC-4**：`UpdateService` 相关新增/回归单元测试通过（如断言 controller 已构造且 `startingUpdater` 参数为 false，可通过依赖注入或私有 API 侧面验证；若无法直接断言则以 AC-1 手工验收替代）

## 八、变更范围

- 修改文件：`SnapVault/Services/UpdateService/UpdateService.swift`（1 行）
- 影响范围：仅 UpdateService 启动流程
- 无架构层改动、无数据模型改动、无外部接口改动 → **本迭代跳过 architecture/**
