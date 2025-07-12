#!/bin/bash

# 更新依赖脚本
# Created by Claude on 2025/7/12

set -e

echo "📦 更新项目依赖"
echo "=============="

# 进入项目目录
cd "$(dirname "$0")/.."

# 更新 Swift Package 依赖
echo "更新 Swift Package 依赖..."
xcodebuild -resolvePackageDependencies -project BilibiliLive.xcodeproj

# 更新 Ruby 依赖 (如果存在 Gemfile)
if [ -f "Gemfile" ]; then
    echo "更新 Ruby 依赖..."
    if command -v bundle &> /dev/null; then
        bundle update
    else
        echo "⚠️  警告: 未找到 bundler"
    fi
fi

# 更新开发工具
echo "检查开发工具更新..."

# 检查 SwiftFormat
if command -v swiftformat &> /dev/null; then
    if command -v brew &> /dev/null; then
        echo "更新 SwiftFormat..."
        brew upgrade swiftformat || echo "SwiftFormat 已是最新版本"
    fi
fi

# 检查 Fastlane
if command -v fastlane &> /dev/null; then
    echo "更新 Fastlane..."
    gem update fastlane || echo "Fastlane 更新失败或已是最新版本"
fi

echo ""
echo "✅ 依赖更新完成"
echo ""
echo "💡 建议操作:"
echo "1. 重新构建项目: ./scripts/build.sh"
echo "2. 运行测试验证: ./scripts/test_network_quality.sh"