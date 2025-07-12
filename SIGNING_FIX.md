# 修复代码签名问题 - 仅使用模拟器

## 问题原因
Xcode默认尝试为真机创建开发者配置文件，但我们只需要在模拟器中测试。

## 解决方案：配置为仅模拟器运行

### 步骤1：修改代码签名设置
在Xcode中：

1. **选择项目** → **TARGETS** → **BilibiliLive**
2. **切换到 "Signing & Capabilities" 标签**
3. **关闭自动签名**：
   - 取消勾选 ✅ **"Automatically manage signing"**
4. **设置 Provisioning Profile**：
   - **Provisioning Profile**: 选择 **"None"** 或者保持空白

### 步骤2：修改Build Settings
1. **切换到 "Build Settings" 标签**
2. **搜索 "Code Signing"**
3. **设置以下值**：
   - **Code Signing Identity (Debug)**: `Apple Development` 或 `iPhone Developer`
   - **Code Signing Identity (Release)**: `Apple Development` 或 `iPhone Developer`
   - **Development Team**: 可以保持空白或选择你的Apple ID
   - **Provisioning Profile**: `Automatic` 或 `None`

### 步骤3：确保选择模拟器
1. **在Xcode顶部工具栏**，确保选择的是：
   ```
   BilibiliLive > Apple TV (任意模拟器)
   ```
   **不要选择** `Generic tvOS Device` 或真实Apple TV设备

### 步骤4：重新编译
- 按 **⌘+Shift+K** 清理构建
- 按 **⌘+B** 重新编译
- 按 **⌘+R** 运行

## 如果还有问题，尝试以下方案：

### 方案A：完全禁用代码签名（仅模拟器）
在 **Build Settings** 中搜索并设置：
- **Code Signing Allowed**: `No`
- **Code Signing Required**: `No`

### 方案B：使用开发者账号（如果有）
1. **Xcode** → **Preferences** → **Accounts**
2. **添加你的Apple ID**
3. **回到项目设置**，选择你的开发团队

### 方案C：临时使用个人免费账号
即使没有付费开发者账号，也可以：
1. 使用你的Apple ID登录Xcode
2. Xcode会自动创建免费的开发者证书
3. 但只能在模拟器和个人设备上测试

## 推荐操作（最简单）

直接在Xcode中：
1. 确保选择了 **Apple TV模拟器**（不是真机）
2. 在 "Signing & Capabilities" 中，如果有错误提示，直接**取消勾选 "Automatically manage signing"**
3. 设置所有签名相关选项为 **"None"** 或保持空白
4. **按 ⌘+R 直接运行**

模拟器不需要任何代码签名！