#!/bin/bash

# ATV-Bilibili-demo 环境初始化脚本
# Created by Claude on 2025/7/12

set -e

echo "🚀 ATV-Bilibili-demo 环境初始化"
echo "=================================="

# 检查系统要求
echo "📋 检查系统要求..."

# 检查 macOS 版本
MACOS_VERSION=$(sw_vers -productVersion)
echo "macOS 版本: $MACOS_VERSION"

# 检查 Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 错误: 未找到 Xcode"
    echo "请安装 Xcode 15.0+ 并运行 'sudo xcode-select --install'"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -n1 | awk '{print $2}')
echo "✅ Xcode 版本: $XCODE_VERSION"

# 检查 Swift
if ! command -v swift &> /dev/null; then
    echo "❌ 错误: 未找到 Swift"
    exit 1
fi

SWIFT_VERSION=$(swift --version | head -n1 | awk '{print $4}')
echo "✅ Swift 版本: $SWIFT_VERSION"

# 安装必要工具
echo ""
echo "🔧 安装开发工具..."

# 检查并安装 SwiftFormat
if ! command -v swiftformat &> /dev/null; then
    echo "安装 SwiftFormat..."
    if command -v brew &> /dev/null; then
        brew install swiftformat
    else
        echo "❌ 请先安装 Homebrew: https://brew.sh"
        exit 1
    fi
else
    echo "✅ SwiftFormat 已安装"
fi

# 检查并安装 Fastlane (如果需要)
if ! command -v fastlane &> /dev/null; then
    echo "安装 Fastlane..."
    if command -v gem &> /dev/null; then
        sudo gem install fastlane
    else
        echo "⚠️  警告: 未找到 Ruby gem，跳过 Fastlane 安装"
    fi
else
    echo "✅ Fastlane 已安装"
fi

# 设置项目
echo ""
echo "📦 设置项目..."

# 进入项目目录
cd "$(dirname "$0")/.."

# 检查 Xcode 项目
if [ ! -f "BilibiliLive.xcodeproj/project.pbxproj" ]; then
    echo "❌ 错误: 未找到 Xcode 项目文件"
    exit 1
fi

echo "✅ 项目文件检查完成"

# 安装 Ruby 依赖 (如果存在 Gemfile)
if [ -f "Gemfile" ]; then
    echo "安装 Ruby 依赖..."
    if command -v bundle &> /dev/null; then
        bundle install
    else
        echo "⚠️  警告: 未找到 bundler，跳过 Ruby 依赖安装"
    fi
fi

# 创建必要目录
echo "创建工作目录..."
mkdir -p "logs"
mkdir -p "build"

# 设置脚本权限
echo "设置脚本权限..."
chmod +x scripts/*.sh

# 验证环境
echo ""
echo "🧪 验证环境..."

# 尝试构建项目
echo "测试项目构建..."
if xcodebuild -project BilibiliLive.xcodeproj -scheme BilibiliLive -destination 'platform=tvOS Simulator,name=Apple TV' build > /dev/null 2>&1; then
    echo "✅ 项目构建成功"
else
    echo "⚠️  警告: 项目构建测试失败，可能需要手动配置"
fi

# 运行网络质量功能测试
echo "测试网络质量功能..."
if ./scripts/test_network_quality.sh > /dev/null 2>&1; then
    echo "✅ 网络质量功能正常"
else
    echo "⚠️  警告: 网络质量功能测试失败"
fi

echo ""
echo "🎉 环境初始化完成！"
echo "=================================="
echo ""
echo "📖 下一步操作:"
echo "1. 打开项目: open BilibiliLive.xcodeproj"
echo "2. 选择 Apple TV Simulator 或连接真实设备"
echo "3. 点击运行按钮开始调试"
echo ""
echo "🔧 常用命令:"
echo "- 构建项目: ./scripts/build.sh"
echo "- 格式化代码: ./scripts/format_code.sh"
echo "- 清理项目: ./scripts/clean.sh"
echo "- 更新依赖: ./scripts/update_dependencies.sh"
echo ""
echo "📚 文档参考: docs/DEPLOYMENT.md"