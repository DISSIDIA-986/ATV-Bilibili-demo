# 定时部署失败：Xcode 账号丢失 + bundle ID 被旧 team 占用

> 分支 `fix/bundle-id-after-team-change` · 2026-07-25

## 问题描述

`com.streambox.atv-auto-deploy`（launchd，每 4 小时给 VividIPTV 和本项目重签
7 天免费证书）连续多日失败。检查 Xcode Settings 时发现没有有效的 Apple
account。同期刚把 macOS 升级到 27.0 Golden Gate Beta，打开 Xcode 提示
"This version of Xcode isn't supported in this version of macOS."

## 根因分析

两个独立问题叠加，且第二个被第一个掩盖。

### 根因 1：macOS 大版本升级清空了 Xcode 的账号列表

日志里的真实报错：

```
error: No Accounts: Add a new account in Accounts settings.
error: No profiles for 'com.streambox.VividIPTV' were found
```

佐证：

```bash
$ defaults read com.apple.dt.Xcode DVTDeveloperAccountManagerAppleIDLists
{ "IDE.Identifiers.Prod" = ( );   # ← 空
}
$ ls ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/ | wc -l
0
```

免费账号**没有 CLI 补救路径**（`-authenticationKeyPath` 只对付费的 App Store
Connect API key 有效），只能 GUI 重登 `Xcode > Settings > Accounts`。

### 根因 2：bundle ID 注册在已失效的旧 team 下

补回账号后，VividIPTV 立刻部署成功，本项目却报：

```
error: Failed Registering Bundle Identifier: The app identifier
"com.jasonniu.BilibiliLiveATV" cannot be registered to your development team
because it is not available.
```

同一个 Apple ID（`neoniu2008@gmail.com`）的免费个人 team ID 变过：钥匙串里的
证书是 `Apple Development: neoniu2008@gmail.com (X3RG65K69M)`，而 Xcode 当前
账号拥有的 team 是 `MA73Z27922`。旧 team 注册过的 App ID 不会跟着迁移，新
team 再注册同一标识符就被拒。免费账号无 developer portal 权限释放它。

## 方案

`PRODUCT_BUNDLE_IDENTIFIER` 由 `com.jasonniu.BilibiliLiveATV` 改为
`com.jasonniu.BilibiliLiveATV2`，改在 `project.pbxproj` 的 Debug + Release
两处。

### 为什么不用 `xcodebuild -xcconfig` 注入（试过，不可行）

初版方案是把 bundle ID 放在仓库外的 xcconfig 里，用 `-xcconfig` 注入，避免
个人化配置进这个公开 fork。实测**构建通过但装机失败**：

```
The parent bundle has the same identifier (com.jasonniu.BilibiliLiveATV2)
as sub-bundle at .../Frameworks/PocketSVG.framework
MIInstallerErrorDomain error 57 — DuplicateIdentifier
```

`-xcconfig` 对**所有 target** 生效，把内嵌的 SPM framework 一起改了名，父子
bundle 标识符重复被 installd 拒绝。xcconfig 的条件语法只支持按
sdk / arch / variant 区分，**没有按 target 区分的能力**。改 pbxproj 才只作用
于 app target。

该方案已完整回退，`scripts/deploy_to_appletv.sh` 未做任何改动。

## 验证

真机部署，非模拟器，非 mock：

| 路径 | 结果 |
|---|---|
| 手动 `deploy_to_appletv.sh --clean` | BUILD SUCCEEDED + 安装成功，76 秒 |
| launchd 完整链路（清空时间戳强制重跑） | `rc=0`，两个 App 均 ✅，时间戳写入 |
| Xcode 重命名后再跑 launchd | `rc=0`，新鲜度门控正常跳过 |
| **修复后** tvOS 模拟器启动 | 进程存活，登录页 + 二维码正常渲染 |
| **修复后** 真机启动 | 存活 45s 后由 `timeout` 以 signal 15 结束（此前 1s 内 exit 0），截图确认登录页 |

launchd 日志关键行：

```
[02:00:15] 钥匙串已解锁
[02:01:27] [VividIPTV]    ✅ 部署成功，已重置 7 天计时。
[02:16:38] [BilibiliLive] ✅ 部署成功，已重置 7 天计时。
[02:16:39] === 结束 (rc=0) ===
```

## 根因 3：tvOS 27 SDK 强制 UIScene 生命周期，启动即 trap

部署成功后 App 在真机上**点开闪一下就退出**。这一条与 bundle ID 无关，
是同一天升级 Xcode 26.6 → 27（tvOS SDK 26 → 27）带来的独立回归。

排查过程有两个坑：

1. `devicectl process launch --console` 报的是 **`exit code 0`**，看着像"干净退出"
   而非崩溃，容易误判。
2. 设备上**没有生成崩溃报告**（`~/Library/Logs/CrashReporter/MobileDevice/`
   目录都不存在），`devicectl device sysdiagnose` 也报错拿不到。

可靠办法是**在 tvOS 模拟器里复现**，崩溃报告直接落到本机
`~/Library/Logs/DiagnosticReports/`。堆栈顶帧一眼看穿：

```
__UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption_block_invoke
EXC_BREAKPOINT (SIGTRAP)
```

模拟器系统日志里的原话：

```
failure in _UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption
(UIApplication_RuntimeIssues.m:106):
Application failed to launch: UIScene life cycle is required for apps built
with this SDK.
```

本项目一直用老式 `AppDelegate` + `window` 生命周期，Info.plist 里没有
`UIApplicationSceneManifest`。在 tvOS 26 SDK 下这只是警告，链接 27 SDK 后
变成**启动即失败**，且没有 opt-out（唯一的规避是继续用旧 SDK 构建）。

对照实验：VividIPTV 用同一条工具链、同一 team 构建部署，运行完全正常 ——
它是 SwiftUI，本来就走 scene 生命周期。这条对照把范围从"工具链/系统"
一次性收敛到"本 App 的生命周期写法"。

### 改法（最小适配）

- `AppDelegate.didFinishLaunchingWithOptions` 不再创建窗口，只保留非 UI 的
  bootstrap；根控制器的选择逻辑抽成 `makeRootViewController()`。
- 新增 `SceneDelegate`（写在 `AppDelegate.swift` 内，避免手改 pbxproj 加文件引用），
  在 `scene(_:willConnectTo:options:)` 里创建窗口并**回填
  `AppDelegate.shared.window`**，使既有调用点（DLNA 投屏、`topMostViewController`
  等 4 处）零改动。
- `applicationDidBecomeActive` 在 scene 生命周期下**不再被调用**，其中的
  `AVAudioSession` 配置必须迁到 `sceneDidBecomeActive`，否则播放会静默出问题
  （无声 / 被其他音频打断）。这是最容易漏掉的一处。
- Info.plist 加 `UIApplicationSceneManifest`，删掉 `UIMainStoryboardFile`
  （窗口改为程序化创建；`Main.storyboard` 仍在包内，
  `UIStoryboard(name:"Main")` 的调用点不受影响）。

## 副作用（已知且接受）

tvOS 按 bundle ID 隔离本地存储，换 ID 后本 App 被视为**全新应用**：

- **B 站登录态丢失，需重新扫码登录。** 播放历史存在 B 站服务端，登回即恢复。
- 旧的 `com.jasonniu.BilibiliLiveATV` 仍以独立图标留在 Apple TV 上，需手动删除。

## 排障备忘

**不要从证书 OU 反推 team ID。** 证书 `Apple Development: <邮箱> (XXXX)` 括号
里的串是签发时的 team，可能早已失效。查当前账号真正拥有的 team：

```bash
defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier
```

**Xcode 与 macOS 版本不匹配只挡 GUI。** 报 "This version of Xcode isn't
supported" 时 `xcodebuild` 命令行仍完全正常，定时部署本身不受影响 —— 唯一被
卡住的是"重登账号"这一步必须走 GUI。

**Xcode 不能用 Homebrew 安装**（不在 cask 里）。可用 `brew install xcodes`
装版本管理器，再 `xcodes install "<版本>"`。
