# Xcode 编译和测试指南

## 必要步骤

### 1. 添加新文件到项目
在Xcode中：
1. 右键点击 `BilibiliLive/Component/Video/` 文件夹
2. 选择 "Add Files to BilibiliLive"
3. 添加 `DanmuMemoryMonitor.swift`
4. 确保选中 tvOS 目标

### 2. 编译项目
1. 选择 **Product → Build** (⌘+B)
2. 如果出现错误，请查看下方的常见问题解决方案

### 3. 运行测试
1. 选择 tvOS 模拟器作为目标设备
2. 按 **⌘+R** 运行项目
3. 在应用中播放视频并开启弹幕

## 功能验证

### 内存优化验证
1. **内存监控**：在 Xcode → Debug Navigator → Memory 中观察内存使用
2. **长时间测试**：播放长视频(>30分钟)观察内存是否稳定
3. **弹幕密度测试**：选择弹幕密集的视频测试性能

### 控制台日志
查找以下关键日志：
- `[dm] memory cleanup: removed X segments`
- `[dm] memory pressure: X`
- 内存监控器的警告信息

## 常见编译问题解决

### 1. 文件未找到错误
```
error: no such module 'DanmuMemoryMonitor'
```
**解决方案**：在Xcode中重新添加 `DanmuMemoryMonitor.swift` 文件到项目

### 2. 导入错误
```
error: no such module 'Foundation'
```
**解决方案**：检查Build Settings中的SDK设置

### 3. 语法错误
**解决方案**：所有Swift文件已通过语法检查，应该不会有语法错误

### 4. 链接错误
**解决方案**：确保所有依赖库正确链接，运行 Product → Clean Build Folder

## 性能测试建议

### 内存测试
1. 使用 Instruments → Allocations 工具
2. 观察弹幕对象的分配和释放
3. 检查是否有内存泄漏

### 性能测试  
1. 使用 Instruments → Time Profiler
2. 关注弹幕渲染的CPU使用
3. 验证优化效果

## 预期结果

### 内存优化效果
- 长时间播放内存使用稳定在较低水平
- 弹幕段缓存最多保留5个
- 轨道弹幕数量受限(浮动50个/垂直20个)
- 对象池大小控制在100个以内

### 性能提升
- 弹幕渲染更流畅
- 低内存设备兼容性改善
- 应用整体响应性提升

## 如果遇到问题

1. **编译失败**：检查新文件是否正确添加到项目
2. **运行崩溃**：查看控制台错误信息
3. **功能异常**：检查委托设置和监控器初始化
4. **性能问题**：调整优化参数(内存阈值、缓存大小等)

项目已准备就绪，请在Xcode中进行编译和测试。