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
- **🌐 智能网络质量检测** (新增)
- **⚡ 自适应超时和重试** (新增)
- **🎯 地区限制代理支持** (增强)
- 系统播放器播放视频
- 视频弹幕
- 热门评论
- 弹幕防挡
- 云视听投屏
- HDR播放
- 字幕

 ![](imgs/1.jpg)
 ![](imgs/2.jpg)
 ![](imgs/3.png)

## 🚀 快速开始

### 环境要求
- macOS 14.0+ (Sonoma)
- Xcode 15.0+
- Apple TV 4K 或 tvOS Simulator

### 一键安装
```bash
# 克隆项目
git clone https://github.com/yichengchen/ATV-Bilibili-demo.git
cd ATV-Bilibili-demo

# 运行环境初始化脚本
./scripts/setup.sh

# 打开项目
open BilibiliLive.xcodeproj
```

### 手动构建
```bash
# 构建项目
./scripts/build.sh

# 格式化代码
./scripts/format_code.sh

# 测试网络功能
./scripts/test_network_quality.sh
```

更多详细信息请参考 [部署文档](docs/DEPLOYMENT.md)



### Telegram Group
 - https://t.me/appletvbilibilidemo

### 未签名iPA文件

从 https://github.com/yichengchen/ATV-Bilibili-demo/releases/tag/nightly 获取基于最新代码构建的

### Links

- App Icon [【22娘×33娘】亲爱的UP主，你怎么还在咕咕咕？](https://www.bilibili.com/video/BV1AB4y1k7em)

- [thmatuza/MPEGDASHAVPlayerDemo](https://github.com/thmatuza/MPEGDASHAVPlayerDemo)

- [dreamCodeMan/B-webmask](https://github.com/dreamCodeMan/B-webmask)

- [分析Bilibili客户端的“哔哩必连”协议](https://xfangfang.github.io/028)
