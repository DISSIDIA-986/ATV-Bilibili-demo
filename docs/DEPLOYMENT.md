# ATV-Bilibili-demo 本地部署指南

## 📋 系统要求

- **macOS**: 14.0+ (Sonoma)
- **Xcode**: 15.0+
- **Swift**: 5.9+
- **设备**: Apple TV 4K (推荐) 或 tvOS Simulator

## 🚀 快速开始

### 1. 环境准备
```bash
# 运行环境初始化脚本
./scripts/setup.sh

# 或手动安装依赖
./scripts/install_dependencies.sh
```

### 2. 项目构建
```bash
# 打开项目
open BilibiliLive.xcodeproj

# 或使用命令行构建
./scripts/build.sh
```

### 3. 运行调试
- **模拟器**: 选择 Apple TV Simulator 运行
- **真机**: 连接 Apple TV 设备后选择目标设备

## 🔧 开发工具

### 代码格式化
```bash
# 手动格式化代码
./scripts/format_code.sh

# 注意：SwiftFormat 已集成到构建流程中
```

### 网络质量测试
```bash
# 运行网络功能演示
./scripts/test_network_quality.sh
```

### 依赖管理
```bash
# 更新 Swift Package 依赖
./scripts/update_dependencies.sh

# 清理构建缓存
./scripts/clean.sh
```

## 📱 设备配置

### Apple TV 设置
1. 确保 Apple TV 和 Mac 在同一网络
2. 在 Apple TV 设置中启用"开发者模式"
3. 在 Xcode 中添加 Apple TV 设备

### 模拟器调试
- 推荐使用 Apple TV 4K (3rd generation) 模拟器
- 支持 tvOS 16.0+ 所有功能

## 🐛 常见问题

### 构建失败
```bash
# 清理项目并重新构建
./scripts/clean.sh
./scripts/build.sh
```

### 依赖问题
```bash
# 重置 Swift Package 依赖
rm -rf .build
./scripts/update_dependencies.sh
```

### 网络功能测试
```bash
# 验证网络质量检测功能
./scripts/test_network_quality.sh
```

## 📚 项目结构

```
BilibiliLive/
├── Component/          # UI组件
├── Module/            # 功能模块
├── Request/           # 网络层
├── Vendor/            # 第三方库
├── Tests/             # 测试文件
└── scripts/           # 开发脚本
```

## 🧪 测试验证

### 网络质量功能
- 运行 `NetworkQualityTests.swift`
- 验证自适应超时机制
- 检查网络质量指示器

### 代理功能
- 测试地区限制解除
- 验证代理服务器切换
- 检查连接稳定性

### 弹幕系统
- 测试高密度弹幕渲染
- 验证内存使用情况
- 检查性能表现

## 📞 技术支持

遇到问题请查看：
- 项目 README.md
- docs/TODO.md 开发计划
- Xcode 控制台输出