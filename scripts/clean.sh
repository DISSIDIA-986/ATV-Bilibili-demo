#!/bin/bash

# 清理项目脚本
# Created by Claude on 2025/7/12

set -e

echo "🧹 清理项目"
echo "==========="

# 进入项目目录
cd "$(dirname "$0")/.."

# 清理 Xcode 构建缓存
echo "清理 Xcode 构建缓存..."
xcodebuild clean -project BilibiliLive.xcodeproj -scheme BilibiliLive

# 清理派生数据
echo "清理派生数据..."
rm -rf ~/Library/Developer/Xcode/DerivedData/BilibiliLive-*

# 清理本地构建目录
echo "清理本地构建目录..."
rm -rf build/
rm -rf .build/

# 清理日志文件
echo "清理日志文件..."
rm -rf logs/*.log

# 清理临时文件
echo "清理临时文件..."
find . -name ".DS_Store" -delete
find . -name "*.tmp" -delete
find . -name "*~" -delete

# 清理 Swift Package 缓存 (可选)
if [ "$1" = "--deep" ]; then
    echo "深度清理 Swift Package 缓存..."
    rm -rf ~/Library/Caches/org.swift.swiftpm/
    rm -rf ~/Library/Developer/Xcode/DerivedData/
fi

echo "✅ 项目清理完成"

if [ "$1" = "--deep" ]; then
    echo ""
    echo "🔄 建议重新运行:"
    echo "1. ./scripts/setup.sh"
    echo "2. ./scripts/build.sh"
fi