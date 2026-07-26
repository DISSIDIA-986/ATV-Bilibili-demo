# 视频信息显示不更新问题修复

## 问题描述

当自动播放下一个视频时，按向上键查看视频信息，显示的仍然是第一个视频的标题和简介信息。

## 根因分析

### 核心问题
插件生命周期管理不完整，导致旧的 `BVideoInfoPlugin` 实例残留在 `activePlugins` 中，造成信息显示不更新。

### 详细分析

1. **插件累积问题**
   - `playNext()` 方法只移除了 `playPlugin` 和 `qualityPlugin`
   - 旧的 `infoPlugin` 没有被移除，残留在 `activePlugins` 数组中
   - 新的 `infoPlugin` 被创建并通过 `generatePlayerPlugin` 添加

2. **播放器状态触发机制**
   - `BVideoPlayPlugin.playerDidLoad()` 会：
     1. 先设置 `playerVC.player = nil`
     2. 然后异步准备新播放器
     3. 最后设置 `playerVC.player = newPlayer`
   - 每次设置 `playerVC.player` 都会触发 `playerDidChange` 回调
   - 回调会通知所有 `activePlugins`（包括旧的 `infoPlugin`）

3. **时序竞争**
   - 新的 `infoPlugin` 被创建并设置正确的标题
   - 但由于 `playerDidChange` 的触发时机，旧的 `infoPlugin` 可能在之后被调用
   - `BVideoInfoPlugin.playerWillStart()` 使用闭包捕获的属性值
   - 如果旧插件被调用，会使用过时的标题数据更新播放器元数据

## 解决方案

### 修改内容

**文件**: `BilibiliLive/Component/Video/NewVideoPlayerViewModel.swift`

#### 1. 在 `playNext()` 中移除旧的 `infoPlugin`

```swift
private func playNext(newPlayInfo: PlayInfo) {
    playInfo = newPlayInfo

    // 移除旧的播放、清晰度和信息插件，确保插件不会累积
    if let playPlugin {
        Logger.debug("playNext: remove previous playPlugin: \(playPlugin)")
        onPluginRemove.send(playPlugin)
    }
    if let qualityPlugin {
        Logger.debug("playNext: remove previous qualityPlugin")
        onPluginRemove.send(qualityPlugin)
    }
    if let infoPlugin {
        Logger.debug("playNext: remove previous infoPlugin")
        onPluginRemove.send(infoPlugin)
    }
    // ...
}
```

#### 2. 在 `playNext()` 中创建并发送新的 `infoPlugin`

```swift
Task {
    do {
        let data = try await loadVideoInfo()

        let player = BVideoPlayPlugin(detailData: data)
        playPlugin = player

        let quality = QualitySelectionPlugin(playURLInfo: data.videoPlayURLInfo)
        quality.onQualityChange = { [weak self] newQn in
            guard let self else { return }
            Logger.info("[VideoPlayer] Quality change requested: \(newQn)")
            self.reloadCurrentVideo()
        }
        qualityPlugin = quality

        // 创建新的信息插件
        let info = BVideoInfoPlugin()
        infoPlugin = info
        if let detail = data.detail {
            var title = detail.title
            var subTitle = detail.ownerName
            let pages = detail.View.pages ?? []
            if pages.count > 1, let index = pages.firstIndex(where: { $0.cid == playInfo.cid }) {
                let page = pages[index]
                title = page.part
                subTitle += "·\(detail.title)"
            }
            info.title = title
            info.subTitle = subTitle
            info.desp = detail.View.desc
            info.pic = detail.pic
            info.viewPoints = data.playerInfo?.view_points
            Logger.debug("playNext: setup infoPlugin - title: \(title), subTitle: \(subTitle)")
        }

        // 呈现新插件（包括 infoPlugin）
        onPluginReady.send([player, quality, info])
    } catch let err {
        onPluginReady.send(completion: .failure(err.localizedDescription))
    }
}
```

### 设计原则

1. **最小化修改**: 只修改 `playNext()` 方法，不影响其他代码路径
2. **最大化代码复用**: 复用现有的插件创建和移除机制
3. **避免大篇幅改动**: 不修改插件系统架构
4. **保持稳定性**: 不影响初始播放和清晰度切换功能

## 技术细节

### 插件生命周期

```
初始加载:
generatePlayerPlugin() → 创建 infoPlugin → onPluginReady.send() → addPlugin()

播放下一个:
playNext()
  → onPluginRemove.send(oldInfoPlugin) → removePlugin()
  → 创建 newInfoPlugin → onPluginReady.send([newInfoPlugin]) → addPlugin()
```

### 播放器状态变化

```
BVideoPlayPlugin.playerDidLoad():
  1. playerVC.player = nil
     → playerDidChange(nil)
     → 旧插件收到 nil 播放器（已移除，不影响）

  2. 异步准备播放器...

  3. playerVC.player = newPlayer
     → playerDidChange(newPlayer)
     → 新插件收到新播放器
     → infoPlugin.playerWillStart()
     → 更新播放器元数据（正确的标题）
```

## 测试验证

### 测试场景

1. **单个视频播放**
   - ✓ 首次播放显示正确标题

2. **自动播放下一个**
   - ✓ 播放视频一，显示标题一
   - ✓ 自动播放视频二，按向上键显示标题二
   - ✓ 自动播放视频三，按向上键显示标题三

3. **多P视频分页播放**
   - ✓ 分P标题正确显示
   - ✓ 副标题格式：UP主·视频标题

4. **清晰度切换**
   - ✓ 清晰度切换不影响标题显示

### 预期结果

- 每次播放新视频时，标题和简介信息都正确更新
- 不会有残留的旧视频信息
- 不影响其他播放器功能

## 相关文件

- `NewVideoPlayerViewModel.swift` - 视频播放器视图模型
- `BVideoInfoPlugin.swift` - 视频信息显示插件
- `BVideoPlayPlugin.swift` - 视频播放插件
- `CommonPlayerViewController.swift` - 通用播放器控制器

## 影响范围

- ✅ 修复：视频自动播放时信息显示不更新
- ✅ 兼容：不影响初始加载
- ✅ 兼容：不影响清晰度切换
- ✅ 兼容：不影响其他播放器功能

## 备注

- `reloadCurrentVideo()` 方法不需要修改，因为它用于清晰度切换，不涉及视频信息变更
- 插件移除机制通过 `onPluginRemove` PassthroughSubject 实现
- 插件添加通过 `onPluginReady` PassthroughSubject 实现
