#!/bin/bash

# 构建项目脚本
# Created by Claude on 2025/7/12

set -e

echo "🔨 构建 ATV-Bilibili-demo 项目"
echo "=============================="

# 进入项目目录
cd "$(dirname "$0")/.."

# 清理之前的构建
echo "清理之前的构建..."
xcodebuild clean -project BilibiliLive.xcodeproj -scheme BilibiliLive

# 构建项目 - tvOS Simulator
echo "构建 tvOS Simulator 版本..."
xcodebuild build \
    -project BilibiliLive.xcodeproj \
    -scheme BilibiliLive \
    -destination 'platform=tvOS Simulator,name=Apple TV' \
    -configuration Debug

echo "✅ tvOS Simulator 构建完成"

# 如果有连接的 Apple TV 设备，也构建真机版本
if xcrun devicectl list devices | grep -q "Apple TV"; then
    echo "检测到 Apple TV 设备，构建真机版本..."
    xcodebuild build \
        -project BilibiliLive.xcodeproj \
        -scheme BilibiliLive \
        -destination 'generic/platform=tvOS' \
        -configuration Debug
    echo "✅ Apple TV 设备版本构建完成"
fi

echo ""
echo "🎉 项目构建完成！"
echo "可以在 Xcode 中运行项目了"