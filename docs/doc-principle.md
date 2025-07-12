在为 tvOS 平台编写 Swift 应用时，最核心的是“遥控器驱动+焦点导航”的 10-英尺体验、流媒体性能以及严格的 App Store 合规。本纲要汇总了从 UX 到 CI/CD 的关键原则，便于你在撰写 PRD、TDD、API、DB、Dev-Standards 等文档时直接引用。

1  平台与视觉基线
	•	10 英尺 UI：界面元素需更大、更疏；避免小字号和密集信息。 ￼
	•	焦点引擎：一切交互围绕焦点移动；让系统高亮、视差、弹性动画自动呈现。 ￼
	•	遥控器输入：仅支持方向、点击、长按、滑动等有限事件，需保证路径顺畅无“焦点陷阱”。 ￼

2  UX & 交互原则

2.1  焦点与导航
	•	使用 @FocusState 或 .focused(_:equals:) 处理 SwiftUI 焦点。 ￼
	•	如出现复杂网格，添加 UIFocusGuide 引导跨区跳转。 ￼

2.2  遥控器手势
	•	在 SwiftUI 中监听 onMoveCommand 处理上/下/左/右；onPlayPauseCommand 触发播放控制。 ￼

2.3  Top Shelf
	•	通过 TVTopShelfContentProvider 扩展推送个性化海报、预览视频，提高留存。 ￼ ￼

3  技术架构与代码组织

层次	建议	目标
UI	SwiftUI + Combine/MVVM	声明式、可预览、易测试  ￼
并发	Swift Concurrency (async/await, Task)	简化线程管理
模块化	Media, Networking, UIComponents, Storage 各自独立 Target	提升编译与责任边界

4  布局与组件
	•	优先使用 NavigationStack, Grid, Carousel 等系统组件，自动获得视差与焦点管理。 ￼
	•	主要操作应出现在焦点链左上角；保持层级深度 ≤3。 ￼

5  媒体播放与性能

任务	推荐
播放 UI	首选 AVPlayerViewController；如需自定义仅覆盖控制层。 ￼ ￼
编码	HEVC/H.265，1080p 60fps 或 4K 30fps，码率自适应。 ￼ ￼
内容匹配	打开“Match Content”以避免 SDR/HDR 切换闪烁。 ￼

6  数据持久化与网络
	•	缓存：Core Data + CloudKit 同步；持久化容器放到后台队列。 ￼ ￼
	•	ATS：所有请求需 HTTPS；对流媒体采用 HLS。

7  无障碍 (Accessibility)
	•	提供精准 AccessibilityLabel、焦点顺序与视觉顺序一致。 ￼ ￼
	•	支持 VoiceOver 朗读、字幕及音频描述开关。

8  安全与隐私
	•	流媒体若需 DRM，必须使用 FairPlay Streaming 并符合 HLS Authoring 规范。 ￼
	•	令牌存储到 Keychain；禁止将 PII 写入日志。

9  测试与质量保障

层	工具	要点
单元	XCTest	ViewModel、Service 纯逻辑覆盖
UI	XCUITest	XCUIApplication().debugDescription 检查焦点元素；断言 element.hasFocus。 ￼ ￼
自动化	Appium tvOS 驱动可做端到端回归。 ￼	

10  CI/CD 与发布
	•	Xcode Cloud：按 push/日程触发 build→test→archive，支持 tvOS 4K 设备自动跑 UI 测试。 ￼ ￼
	•	Fastlane：lane 脚本自动递增版本号、上传符号文件、推送 TestFlight。

11  编码规范 (示例)

文件命名: FeatureXView.swift / FeatureXViewModel.swift  
常量: upperCamelCase enum, lowerCamelCase var  
Git 提交: feat(tvOS): 支持顶部轮播

12  上架前检查清单
	1.	单元 & UI 测试全部通过；核心逻辑覆盖 ≥80%。
	2.	Top Shelf、深度链接、恢复购买验证。
	3.	App Store 截图：1920×720 横幅 + 16:9 预览视频。
	4.	HLS 清单、FPS 秘钥、ATS 例外条目验证。

⸻

