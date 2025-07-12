# Xcode 编译和测试指南

## 必要步骤

### 1. 代码签名配置 (重要)

**仅模拟器运行**（推荐）：
项目已配置为仅在模拟器中运行，无需开发者账号。

**如需真机测试**：
1. 在Xcode中打开项目
2. 选择 **Project → BilibiliLive → Signing & Capabilities**
3. 设置开发团队和Bundle ID
4. 参考 [IPA签名指南](docs/IPA_SIGNING.md)

### 2. 编译项目
1. 确保选择 **tvOS Simulator** 目标设备 (不是Generic tvOS Device)
2. 选择 **Product → Build** (⌘+B)
3. 如果出现错误，请查看下方的常见问题解决方案

### 3. 运行测试
1. 选择 Apple TV 4K 模拟器作为目标设备
2. 按 **⌘+R** 运行项目
3. 在应用中播放视频测试新功能

## 新功能验证

### 网络监控插件
1. **网络状态指示器**：播放视频时观察网络状态指示器
2. **质量检测**：在网络状况变化时观察质量评级
3. **自动切换**：测试网络质量变化时的自动分辨率切换

### 播放统计插件  
1. **统计界面**：播放视频时可查看详细播放统计
2. **会话跟踪**：观察播放会话的开始、暂停、结束事件
3. **性能指标**：监控帧率、缓冲、网络带宽等指标

### 控制台日志
查找以下关键日志：
- `[NetworkMonitor] Connection status changed: wifi`
- `[PlaybackStats] New session started: sessionId`
- `[QualityAdapter] Quality changed from 1080p to 720p`
- `[dm] memory cleanup: removed X segments`

## 常见编译问题解决

### 1. 代码签名错误
```
Communication with Apple failed
Your team has no devices from which to generate a provisioning profile
```
**解决方案**：确保选择了模拟器目标，项目已配置为仅模拟器运行

### 2. 描述文件错误
```
No profiles for 'com.niuyp.BilibiliLive.demo' were found
```
**解决方案**：在模拟器中运行不需要描述文件，检查目标设备选择

### 3. tvOS兼容性错误
```
'insetGrouped' is unavailable in tvOS
```
**解决方案**：所有tvOS兼容性问题已修复，更新到最新代码

### 4. 网络Session错误
```
sessionDeinitialized
```
**解决方案**：网络Session管理已优化，使用共享Session实例

### 5. 项目GUID冲突
```
unable to load transferred PIF: The workspace contains multiple references with the same GUID
```
**解决方案**：
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf .build/
rm Package.resolved
xcodebuild -resolvePackageDependencies
```

## 架构测试建议

### 插件系统测试
1. **加载测试**：验证所有插件正确加载
2. **内存测试**：长时间播放检查内存使用
3. **并发测试**：多个插件同时工作的稳定性

### 网络功能测试
1. **网络切换**：WiFi/移动网络切换测试
2. **弱网测试**：模拟弱网环境的适应性
3. **断网恢复**：网络中断后的恢复能力

### 性能测试  
1. 使用 Instruments → Allocations 检查内存使用
2. 使用 Instruments → Time Profiler 检查CPU性能
3. 使用 Instruments → Network 检查网络使用

## 预期结果

### 编译成功标志
- 所有依赖包正确解析
- 无编译错误和警告
- 应用成功启动到主界面

### 功能正常标志
- 网络请求正常，无sessionDeinitialized错误
- 播放器插件系统工作正常
- 网络监控实时显示连接状态
- 播放统计准确记录播放数据
- 弹幕内存优化正常工作

### 性能优化效果
- 网络质量自动检测和切换
- 播放统计不影响播放流畅度
- 内存使用稳定在合理范围
- 弹幕渲染性能提升

## 开发工作流

### 代码修改后
1. **格式化代码**：SwiftFormat会在编译时自动运行
2. **编译测试**：⌘+B 编译验证
3. **功能测试**：⌘+R 运行测试
4. **提交代码**：确认功能正常后提交

### 如果遇到问题

1. **编译失败**：检查控制台详细错误信息
2. **运行崩溃**：查看模拟器控制台日志
3. **功能异常**：检查插件是否正确初始化
4. **性能问题**：使用Instruments进行性能分析
5. **网络问题**：检查网络监控插件状态

## 相关文档

- [BUG.md](BUG.md) - 已知问题和修复记录
- [docs/IPA_SIGNING.md](docs/IPA_SIGNING.md) - 真机签名指南
- [SIGNING_FIX.md](SIGNING_FIX.md) - 快速签名修复指南

项目已准备就绪，在Apple TV模拟器中编译和测试。