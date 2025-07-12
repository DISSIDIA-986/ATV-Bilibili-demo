# Bundle Identifier 修改指南

## 问题原因
原Bundle Identifier `com.etan.tv.BilibiliLive` 已被其他开发者使用，导致无法注册。

## 解决步骤

### 1. 在Xcode中修改Bundle Identifier
1. 点击项目导航器中的 **BilibiliLive** 项目（蓝色图标）
2. 在主编辑区域选择 **TARGETS** 下的 **BilibiliLive**
3. 切换到 **"Signing & Capabilities"** 标签
4. 找到 **Bundle Identifier** 字段
5. 将 `com.etan.tv.BilibiliLive` 修改为：
   ```
   com.niuyp.BilibiliLive.demo
   ```
   或者使用你的名字：
   ```
   com.yourname.BilibiliLive
   ```

### 2. 开发者团队设置
- **Team**: 选择你的个人开发者账号（如果有的话）
- **Code Signing Style**: 保持 "Automatic"

### 3. 如果没有付费开发者账号
对于免费Apple ID，有以下限制：
- 应用只能在模拟器和你注册的设备上运行
- 应用7天后会过期，需要重新编译
- 不能发布到App Store

但这**不影响在模拟器中测试**！

### 4. 编译选项
如果你只想在模拟器中测试：
1. 选择目标设备为 **tvOS模拟器**
2. 按 **⌘+R** 运行
3. 这样就可以完全绕过证书问题

## 推荐的测试方案

### 方案1：使用模拟器（推荐）
- 选择任意tvOS模拟器作为目标
- Bundle Identifier改为唯一值
- 直接运行测试

### 方案2：免费Apple ID真机测试  
- 修改Bundle Identifier
- 使用你的Apple ID登录Xcode
- 连接Apple TV设备测试（7天限制）

### 方案3：付费开发者账号
- $99/年的Apple Developer Program
- 可以发布到App Store
- 无设备和时间限制

## 立即解决方案
修改Bundle Identifier为：`com.niuyp.BilibiliLive.demo`

这样就能立即在模拟器中测试了！