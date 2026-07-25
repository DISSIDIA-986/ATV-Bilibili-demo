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

launchd 日志关键行：

```
[02:00:15] 钥匙串已解锁
[02:01:27] [VividIPTV]    ✅ 部署成功，已重置 7 天计时。
[02:16:38] [BilibiliLive] ✅ 部署成功，已重置 7 天计时。
[02:16:39] === 结束 (rc=0) ===
```

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
