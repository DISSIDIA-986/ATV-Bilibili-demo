# BiliBili tvOS 客户端 Demo

### 本项目没有任何授权的 Testflight 发放以及任何收费版本，请注意辨别和考虑安全性问题。

 **BiliBili tvOS 客户端 Demo 从未在任何平台上架和收费（包括AppStore与Testflight）**

 如果您在任何平台上看到有人以收费方式提供本项目的服务或应用，请注意这是**未经授权的**行为，并且与我们的原始意图不符。我们强烈谴责将本项目用于商业盈利的行为，由此引发的任何安全风险与此项目无关。


### 支持功能
- 二维码登录
- 云视听小电视投屏协议
- 直播与弹幕
- 推荐Feed
- 热门
- 排行榜
- 搜索
- 关注列表
- 历史播放
- 稍后再看
- **🌐 智能网络质量检测** ✨ 新增
- **⚡ 自适应超时和重试** ✨ 新增  
- **🎯 地区限制代理支持** ✨ 增强
- **📊 实时播放统计插件** ✨ 新增
- **🔌 可扩展播放器插件架构** ✨ 新增
- **🧠 智能画质自动切换** ✨ 新增
- 系统播放器播放视频
- 视频弹幕 + 内存优化
- 热门评论
- 弹幕防挡
- 云视听投屏
- HDR播放
- 字幕

 ![](imgs/1.jpg)
 ![](imgs/2.jpg)
 ![](imgs/3.png)

## ✨ 最新功能亮点

### 🔌 播放器插件架构
全新设计的可扩展插件系统，支持：
- **模块化设计**：独立的功能插件，易于维护和扩展
- **实时数据**：插件间实时数据共享和通信
- **性能优化**：智能资源管理，避免影响播放性能
- **热插拔支持**：动态加载和卸载插件

### 📊 播放统计插件
实时收集和展示播放数据：
- **详细指标**：帧率、码率、缓冲、网络带宽等
- **会话跟踪**：完整的播放会话生命周期管理
- **历史记录**：播放统计历史数据持久化
- **可视化展示**：直观的图表和数据展示

### 🌐 网络监控插件
智能网络状态检测和管理：
- **实时监控**：网络连接状态、类型、质量检测
- **质量评估**：基于延迟、带宽的网络质量评级
- **状态指示**：可视化网络状态指示器
- **自动适应**：根据网络状况自动调整播放策略

### 🧠 画质自动切换
基于网络状况的智能画质适配：
- **自动检测**：实时监测网络质量变化
- **智能切换**：自动选择最适合的视频质量
- **平滑过渡**：无缝的画质切换体验
- **用户控制**：支持手动覆盖自动选择

### 🎯 网络优化增强
- **Session管理优化**：修复sessionDeinitialized错误
- **重试机制**：智能网络请求重试策略
- **连接池管理**：高效的网络连接复用
- **错误恢复**：网络故障自动恢复机制

## 🚀 快速开始

### 环境要求
- macOS 14.0+ (Sonoma)
- Xcode 15.0+
- Apple TV 4K 或 tvOS Simulator

### ⚡ 一键运行 (推荐)
```bash
# 克隆项目
git clone https://github.com/yichengchen/ATV-Bilibili-demo.git
cd ATV-Bilibili-demo

# 打开项目 (模拟器无需签名)
open BilibiliLive.xcodeproj

# 在Xcode中选择Apple TV模拟器，按⌘+R运行
```

### 🔧 手动构建
```bash
# 构建项目 (模拟器)
xcodebuild -project BilibiliLive.xcodeproj \
           -scheme BilibiliLive \
           -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
           build

# 格式化代码 (可选)
cd BuildTools && swift run swiftformat --disable unusedArguments,numberFormatting,redundantReturn,andOperator,anyObjectProtocol,trailingClosures,redundantFileprivate --ranges nospace --swiftversion 5 ../
```

### 📋 文档指南
- **[构建指南](BUILD_GUIDE.md)** - 详细编译和测试说明
- **[签名指南](docs/IPA_SIGNING.md)** - 真机部署和IPA分发
- **[问题修复](BUG.md)** - 常见问题和解决方案
- **[签名快速修复](SIGNING_FIX.md)** - 快速解决签名问题

### 🎯 主要改进
- **✅ 零配置模拟器运行**：无需开发者账号即可在模拟器中测试
- **✅ 网络稳定性提升**：修复所有已知网络连接问题
- **✅ tvOS完全兼容**：解决所有tvOS API兼容性问题
- **✅ 智能插件系统**：模块化架构，易于扩展和维护

更多详细信息请参考：
- [部署文档](docs/DEPLOYMENT.md) - 本地开发环境搭建
- [IPA签名指南](docs/IPA_SIGNING.md) - 开发者账号签名分发



### Telegram Group
 - https://t.me/appletvbilibilidemo

### 未签名iPA文件

从 https://github.com/yichengchen/ATV-Bilibili-demo/releases/tag/nightly 获取基于最新代码构建的

### Links

- App Icon [【22娘×33娘】亲爱的UP主，你怎么还在咕咕咕？](https://www.bilibili.com/video/BV1AB4y1k7em)

- [thmatuza/MPEGDASHAVPlayerDemo](https://github.com/thmatuza/MPEGDASHAVPlayerDemo)

- [dreamCodeMan/B-webmask](https://github.com/dreamCodeMan/B-webmask)

- [分析Bilibili客户端的“哔哩必连”协议](https://xfangfang.github.io/028)
