# Bug 修复记录

本文档记录了在开发过程中遇到的所有bug及其修复方案。

## 📋 概述

在实现新的插件架构和功能增强过程中，我们遇到了多种类型的问题：
- 网络会话管理问题
- tvOS兼容性问题  
- 编译错误
- 代码签名配置问题
- Xcode项目配置问题

## 🔥 严重Bug修复

### 1. 网络请求失败：sessionDeinitialized

**问题描述**：
```
网络请求失败: https://api.live.bilibili.com/xlive/web-ucenter/v1/xfetter/GetWebList, 错误: sessionDeinitialized
```

**影响**：应用启动后立即无法进行任何网络请求，导致功能完全不可用。

**根本原因**：
`WebRequest.swift` 中每次网络请求都创建新的 `Session` 实例，当请求执行时 Session 已被释放，导致 `sessionDeinitialized` 错误。

**修复方案**：
```swift
// 修复前 - 问题代码
func request<T: ResponseAPIModel>(...) {
    let session = Session(configuration: config, interceptor: networkRetryManager)
    session.request(...) // Session 可能已被释放
}

// 修复后 - 解决方案  
private static let sharedSession: Session = {
    let config = URLSession.shared.configuration
    return Session(configuration: config, interceptor: networkRetryManager)
}()

func request<T: ResponseAPIModel>(...) {
    Self.sharedSession.request(...) // 使用共享实例
}
```

**文件位置**：`BilibiliLive/Request/WebRequest.swift`

---

## 🖥️ tvOS兼容性问题

### 2. UITableView.Style.insetGrouped 不支持

**问题描述**：
```
'insetGrouped' is unavailable in tvOS
```

**修复方案**：
```swift
// 修复前
tableView = UITableView(frame: .zero, style: .insetGrouped)

// 修复后  
tableView = UITableView(frame: .zero, style: .grouped)
```

### 3. UIColor.systemBackground 不支持

**问题描述**：
```
'systemBackground' is unavailable in tvOS
```

**修复方案**：
```swift
// 修复前
backgroundColor = .systemBackground

// 修复后
backgroundColor = .darkGray
```

### 4. UIModalPresentationStyle.formSheet 不支持

**问题描述**：
```
'formSheet' is unavailable in tvOS
```

**修复方案**：
```swift
// 修复前
modalPresentationStyle = .formSheet

// 修复后
modalPresentationStyle = .fullScreen
```

### 5. 系统颜色兼容性问题

**修复的颜色映射**：
```swift
// 修复前 → 修复后
.systemGreen     → .green
.systemRed       → .red  
.systemBlue      → .blue
.systemOrange    → .orange
.systemYellow    → .yellow
.systemBackground → .darkGray
.secondaryLabel  → .lightGray
```

---

## 🔧 编译错误修复

### 6. String格式化错误

**问题描述**：
```
error: 'f' is not a valid digit in integer literal
```

**根本原因**：字符串格式化中 `%%` 前后有多余空格导致编译器解析错误。

**修复方案**：
```swift
// 修复前 - 问题代码
String(format: "%.1f %% ", bufferingRatio * 100)

// 修复后 - 解决方案
String(format: "%.1f%%", bufferingRatio * 100)
```

**影响文件**：
- `PlaybackStatsViewController.swift`
- `NetworkMonitorPlugin.swift`

### 7. Codable协议一致性问题

**问题描述**：
```
Type 'PlaybackSession' does not conform to protocol 'Decodable'/'Encodable'
```

**修复方案**：
```swift
// 修复前
enum NetworkType: String, CaseIterable {
    case wifi = "WiFi"
    case cellular = "Cellular"  
    case unknown = "Unknown"
}

// 修复后
enum NetworkType: String, CaseIterable, Codable {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case unknown = "Unknown"
}
```

---

## 🔐 代码签名问题

### 8. 缺少开发团队配置

**问题描述**：
```
Signing for "BilibiliLive" requires a development team. Select a development team in the Signing & Capabilities editor.
```

**修复方案**：
在 `BilibiliLive.xcodeproj/project.pbxproj` 中添加：
```
CODE_SIGN_STYLE = Automatic;
DEVELOPMENT_TEAM = MA73Z27922;
```

**团队ID获取**：从Apple Development证书中提取Team ID。

### 9. 描述文件要求问题

**问题描述**：
```
BilibiliLive requires a provisioning profile
```

**修复方案**：将代码签名方式从Manual改为Automatic，让Xcode自动管理描述文件。

### 10. 描述文件与设备注册错误

**问题描述**：
```
Communication with Apple failed
Your team has no devices from which to generate a provisioning profile. Connect a device to use or manually add device IDs in Certificates, Identifiers & Profiles.

No profiles for 'com.niuyp.BilibiliLive.demo' were found
Xcode couldn't find any tvOS App Development provisioning profiles matching 'com.niuyp.BilibiliLive.demo'.

"BilibiliLive" requires a provisioning profile. Select a provisioning profile in the Signing & Capabilities editor.
```

**根本原因**：设置了自动签名但没有注册设备，且只需要在模拟器中测试。

**修复方案**：
配置为仅模拟器签名，彻底禁用代码签名：
```
CODE_SIGN_STYLE = Manual;
"CODE_SIGN_IDENTITY[sdk=appletvsimulator*]" = "";
"PROVISIONING_PROFILE_SPECIFIER[sdk=appletvsimulator*]" = "";
"CODE_SIGNING_ALLOWED[sdk=appletvsimulator*]" = NO;
```

移除通用的PROVISIONING_PROFILE_SPECIFIER设置，并完全禁用模拟器的代码签名功能，这样配置后在模拟器中完全不需要任何签名配置或开发者账号。

---

## 📦 Xcode项目配置问题

### 10. GUID冲突错误

**问题描述**：
```
Could not compute dependency graph: unable to load transferred PIF: The workspace contains multiple references with the same GUID
```

**修复方案**：
```bash
# 清理所有Xcode缓存
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf .build/
rm Package.resolved

# 重新解析依赖
xcodebuild -resolvePackageDependencies
```

---

## 🏗️ 架构改进

### 11. 插件架构内存管理

**问题**：插件间可能存在循环引用。

**解决方案**：
- 使用 `weak` 引用避免循环引用
- 实现proper的 `deinit` 清理
- 添加内存监控机制

### 12. 网络监控性能优化

**问题**：持续的网络质量检测消耗资源。

**解决方案**：
- 实现智能检测频率调整
- 添加节能模式
- 优化检测算法效率

### 13. Swift并发: CheckedContinuation重复恢复错误

**问题描述**：
```
SWIFT TASK CONTINUATION MISUSE: measureLatency(to:) tried to resume its continuation more than once, returning nil!
Fatal error in _Concurrency/CheckedContinuation.swift:172
```

**根本原因**：在`NetworkQualityDetector.swift`的`measureLatency`函数中，`withCheckedContinuation`的continuation可能被多次恢复：
1. `timeoutTimer`超时时调用`continuation.resume(returning: nil)`
2. `stateUpdateHandler`在网络状态变化时也可能调用resume
3. 如果网络连接状态快速变化，可能导致竞态条件

**修复方案**：
使用线程安全的标志位和锁机制防止多次resume：
```swift
return await withCheckedContinuation { continuation in
    var isCompleted = false
    let lock = NSLock()
    
    let timeoutTimer = Timer.scheduledTimer(withTimeInterval: endpoint.timeout, repeats: false) { _ in
        lock.lock()
        defer { lock.unlock() }
        
        guard !isCompleted else { return }
        isCompleted = true
        continuation.resume(returning: nil)
    }

    connection.stateUpdateHandler = { state in
        lock.lock()
        defer { lock.unlock() }
        
        guard !isCompleted else { return }
        
        switch state {
        case .ready:
            isCompleted = true
            timeoutTimer.invalidate()
            continuation.resume(returning: latency)
        // ...
    }
}
```

### 14. Swift Range边界检查错误

**问题描述**：
```
Swift/arm64-apple-tvos-simulator.swiftinterface:6072: Fatal error: Range requires lowerBound <= upperBound
```

**根本原因**：在`NetworkQualityDetector.swift`中，网络测量可能返回异常值（NaN、无穷大、负数），导致Range比较操作失败：
1. `qualityScore`计算中可能产生NaN或无穷大
2. `NetworkQualityLevel.from(score:)`使用Range进行pattern matching
3. 当score为异常值时，Range操作触发越界错误

**修复方案**：
添加全面的数值有效性检查：
```swift
// 1. Range匹配前检查数值有效性
static func from(score: Double) -> NetworkQualityLevel {
    guard score.isFinite else {
        return .unknown
    }
    switch score {
    case 3.5...4.0: return .excellent
    // ...
    }
}

// 2. 测量函数中添加安全检查
private func measureNetworkSpeed() async -> (download: Double, upload: Double) {
    // ...
    guard duration > 0 && duration.isFinite else {
        return (download: 0, upload: 0)
    }
    let bytesPerSecond = Double(data.count) / duration
    guard bytesPerSecond.isFinite && bytesPerSecond >= 0 else {
        return (download: 0, upload: 0)
    }
    // ...
}

// 3. 质量分数计算安全检查
var qualityScore: Double {
    // 对每个指标进行isFinite检查
    if latency.isFinite && latency >= 0 {
        // 正常计算
    } else {
        score += 0.1 // 异常值给最低分
    }
}
```

**影响范围**：
- `NetworkQualityLevel.from(score:)` - 添加数值验证
- `NetworkQualityMetrics.qualityScore` - 全面的异常值处理
- `measureNetworkSpeed()` - 除零检查和结果验证
- `measureJitter()` - 方差计算和结果验证

**文件位置**：`BilibiliLive/Request/NetworkQualityDetector.swift:44-434`

---

## 📊 修复统计

| 类别 | 数量 | 严重程度 |
|------|------|----------|
| 网络问题 | 1 | 严重 |
| tvOS兼容性 | 5 | 中等 |
| 编译错误 | 2 | 中等 |
| 签名配置 | 3 | 低 |
| 项目配置 | 1 | 低 |
| 架构优化 | 2 | 低 |
| **Swift并发** | **1** | **严重** |

**总计**：15个问题已修复

---

## 🔍 测试验证

### 修复验证方法

1. **网络功能测试**：
   ```bash
   # 启动应用，验证网络请求正常
   # 检查控制台无sessionDeinitialized错误
   ```

2. **编译测试**：
   ```bash
   xcodebuild -project BilibiliLive.xcodeproj -scheme BilibiliLive -destination 'platform=tvOS Simulator,name=Apple TV 4K'
   ```

3. **签名验证**：
   ```bash
   codesign --verify --verbose BilibiliLive.app
   ```

### 功能回归测试

- [x] 网络请求功能正常
- [x] 插件系统工作正常
- [x] tvOS界面适配正确
- [x] 代码签名配置有效
- [x] 项目编译无错误

---

## 🚀 预防措施

### 1. 网络层改进
- 实现Session生命周期管理
- 添加网络状态监控
- 增强错误处理机制

### 2. tvOS兼容性检查
- 建立tvOS API兼容性清单
- 添加编译时警告检查
- 创建tvOS专用UI组件

### 3. 自动化测试
- 集成编译错误检查
- 添加代码签名验证
- 实现持续集成流程

### 4. 文档维护
- 保持文档与代码同步
- 记录所有重要配置变更
- 建立问题跟踪机制

---

## 📚 相关文档

- [BUILD_GUIDE.md](BUILD_GUIDE.md) - 编译指南
- [docs/IPA_SIGNING.md](docs/IPA_SIGNING.md) - 签名指南
- [SIGNING_FIX.md](SIGNING_FIX.md) - 签名问题修复

---

## 📞 技术支持

如果遇到类似问题：

1. **检查日志**：查看Xcode控制台详细错误信息
2. **参考本文档**：查找相似问题的解决方案
3. **验证环境**：确保开发环境配置正确
4. **清理缓存**：尝试清理Xcode缓存重新编译

**最后更新**：2024年 (开发会话记录)