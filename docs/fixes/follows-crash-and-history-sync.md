# 关注页解码崩溃 + 播放历史跨端同步修复

> PR #16 · 分支 `feat/follows-crash-and-history-sync`

## 问题描述

1. **顶部导航「关注」tab 点击报错** — 打开关注页时列表报错 / 打不开内容。
2. **播放历史 Apple TV 与手机不同步** — 相同账号下，在 Apple TV 上看过的视频，手机端「历史」看不到或对不上。

用户怀疑与 tvOS 更新有关，实际两者都是数据解码 / 上报逻辑问题，与 tvOS 版本无关。

## 根因分析

### Bug1：关注页解码崩溃

关注动态流（`/x/polymer/web-dynamic/v1/feed/all`）是**异构数据**，一次返回里混杂视频、番剧等多种动态。原模型把番剧的 `Pgc.epid` 定义成**非可选 `Int`**：

```swift
struct Pgc: Codable, Hashable {
    let epid: Int   // ← B站有时返回 String 或缺失
}
```

`WebRequest.request(...)` 用 `JSONDecoder` 解码整个 `DynamicFeedInfo`，其中 `items` 是整体解码。只要**任意一条**动态的 `epid` 是字符串 / 缺失（或 `update_num` 类型不符），整个 `DynamicFeedInfo` 解码就会 `throw` → 整页请求失败 → 关注页报错。

### Bug2：播放历史跨端不同步

历史进度此前**只在 `playerDidDismiss`（退出播放器）时上报一次**，且 fire-and-forget（`complete: nil`，无重试、无失败日志）：

```swift
func playerDidDismiss(playerVC: AVPlayerViewController) {
    guard let currentTime = playerVC.player?.currentTime().seconds, currentTime > 0 else { return }
    WebRequest.reportWatchHistory(...)   // 无 completion，失败静默
}
```

后果：

1. Apple TV 用户常直接按 Home / 上划杀进程，而非在播放器里优雅退出 → `playerDidDismiss` 不触发 → 这次观看**永不上报** → 手机端看不到。
2. 弱网下单次 POST 静默失败（本项目主打弱网场景，失败率更高）。
3. 番剧判定依赖 `isBangumi` 布尔；连续播放的番剧续集在 `seq` 构造时**漏传 `epid` / `seasonId`**，且 aid 用了当前集的 aid，导致番剧续集历史串号 / 缺 ID，B站不按番剧记录。

## 解决方案

### Bug1（`FollowsViewController.swift`）

- `Pgc.epid` → `Int?` + 自定义 decoder，容忍 `Int` / `String` / `null` / 缺失（对齐上游 #189）。
- `DynamicFeedInfo` 逐条容错：`LossyItem` 包装单条 item，坏项被跳过而非让整页失败；`update_num` / `offset` / `update_baseline` / `has_more` 全部柔性解码（对齐上游 #185 思路）。
- `offset` 非空即原样回传，支持非数字分页 token；递归翻页加 `offset` 前进保护，防止异常 offset 无限重复请求同一页。
- `videoFeeds` 过滤掉 `epid` 无效的纯 PGC 项；纯 PGC 动态（aid=0）跳转走 `create(epid:)`。

### Bug2

- **`BVideoPlayPlugin.swift`** — 播放中周期心跳（`addPeriodicTimeObserver`，15s）+ 在 `playerDidPause` / `playerDidEnd` / `playerDidCleanUp` / `playerDidDismiss` / 进入后台各 flush 一次；observer 生命周期化管理（`startHistoryReporting` / `stopHistoryReporting`，deinit 兜底）。
  - 切集 / 切码率时新插件 `playerDidLoad` 会置 `playerVC.player = nil`，KVO 的 cleanup 会发给当前 active plugins（可能是新插件）。加 `player === reportPlayer` 守卫，避免用新集 `playData` 上报旧 player 时间，污染跨端历史。
- **`WebRequest.swift`** — `reportWatchHistory` 加 completion 日志（上报参数 + 返回 code/message，便于真机诊断）；番剧判定改为超集 `isBangumi || (epid ?? 0) > 0 || (seasonId ?? 0) > 0`，避免番剧误走普通视频分支。
- **`VideoDetailViewController.swift`** — 修番剧连播 `seq` 参数传播：补 `seasonId`、`epid`，番剧每集 aid 取 `$0.page`（与单播路径一致），避免续集串号 / 缺 ID。

## 测试验证

### 关注页解码（12 项极端输入，独立 Swift 测试全过）

- `epid` 为 Int / String / null / 非法字符串 → 分别正确解析或降级为 nil，item 保留
- 坏项（缺 `module_author`）混在好项中 → 坏项跳过，保留好项
- 全部坏项 → 空数组但不 throw
- 空 items / 顶层字段全缺 → 默认值不报错
- `update_num` 为 String / `offset` 为数字 → 正确转换
- 超长 title（16384 字符）→ 正常

### 编译 & 部署

- `xcodebuild -destination 'generic/platform=tvOS'` **BUILD SUCCEEDED**
- 已部署真机 Apple TV 4K 联调

### 真机验收（待用户观察）

- ✅ 关注 tab 点击不再报错，正常出内容
- ⏳ 历史跨端同步：手机端与 ATV 历史列表初步对比一致，继续观察中
- 建议重点验证：播放中按 Home / 杀进程后，手机端仍能看到最近进度（本次核心修复点）；番剧连播续集在手机端记录为正确的那一集

日志已加 `[History] flush(reason)` / `report ok|FAILED`，真机接 Console 可看每次上报的参数与返回 code。

## 相关文件

- `BilibiliLive/Module/ViewController/FollowsViewController.swift` — 关注页动态流模型 + 请求
- `BilibiliLive/Component/Video/Plugins/BVideoPlayPlugin.swift` — 播放插件（历史上报）
- `BilibiliLive/Request/WebRequest.swift` — `reportWatchHistory`
- `BilibiliLive/Component/Video/VideoDetailViewController.swift` — 播放序列构造

## 影响范围

- ✅ 修复：关注页因单条脏数据整页解码失败
- ✅ 修复：ATV 观看历史不上报 / 弱网静默失败 / 番剧续集串号
- ✅ 兼容：普通视频上报路径不变；非番剧连播路径 aid 不变，零回归

## 备注

- 上游 #177 / #165 / #199 / #206 / 插件生命周期重构等跨多文件大改，与 fork 已重写部分冲突高，本轮未纳入。
- 若真机确认是**反向**不同步（手机观看 → ATV 历史页看不到），属于读取端 `/x/v2/history` 端点问题，需单独 PR 迁移到 `/x/web-interface/history/cursor`，本次未动。
- 上游 #188（`playerDidCleanUp` 事件绑定）fork 已包含，无需再挑。
