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

# 创建输出目录
OUTPUT_DIR="./build"
mkdir -p "$OUTPUT_DIR"

# Archive 项目用于生成 IPA
echo "📦 Archive 项目用于 IPA..."
xcodebuild archive \
    -project BilibiliLive.xcodeproj \
    -scheme BilibiliLive \
    -destination 'generic/platform=tvOS' \
    -archivePath "$OUTPUT_DIR/BilibiliLive.xcarchive" \
    -configuration Release \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_ENTITLEMENTS="" \
    CODE_SIGNING_ALLOWED=NO

if [ $? -ne 0 ]; then
    echo "❌ Archive 失败"
    exit 1
fi

echo "✅ Archive 完成"

# 手动创建 IPA
APP_PATH="$OUTPUT_DIR/BilibiliLive.xcarchive/Products/Applications/BilibiliLive.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ 找不到编译的应用文件: $APP_PATH"
    exit 1
fi

echo "📱 创建 IPA 包..."
cd "$OUTPUT_DIR"
mkdir -p Payload
cp -R "BilibiliLive.xcarchive/Products/Applications/BilibiliLive.app" Payload/
zip -r "BilibiliLive.ipa" Payload/
rm -rf Payload/

# 验证 IPA 文件
if [ -f "BilibiliLive.ipa" ]; then
    IPA_SIZE=$(du -h "BilibiliLive.ipa" | cut -f1)
    echo ""
    echo "🎉 IPA 文件生成成功！"
    echo "📁 文件位置: $(pwd)/BilibiliLive.ipa"
    echo "📏 文件大小: $IPA_SIZE"
    echo ""
    echo "🔧 接下来可以用 Sideloadly 签名这个 IPA 文件"
else
    echo "❌ IPA 文件生成失败"
    exit 1
fi