#!/bin/bash

# IPA 签名环境检查脚本
# 详细说明请参考: docs/IPA_SIGNING.md

set -e

echo "🧪 签名环境检查"
echo "=============="

cd "$(dirname "$0")/.."

# 基础检查
echo "📋 基础环境..."
[ ! -f "BilibiliLive.xcodeproj/project.pbxproj" ] && { echo "❌ 项目文件不存在"; exit 1; }
! command -v xcodebuild &> /dev/null && { echo "❌ 未找到 Xcode"; exit 1; }
echo "✅ Xcode: $(xcodebuild -version | head -n1 | awk '{print $2}')"

# 证书检查
echo "🔐 开发者证书..."
CERT_COUNT=$(security find-identity -v -p codesigning | grep -c "valid identities found" || echo "0")
if [ "$CERT_COUNT" != "0" ]; then
    echo "✅ 找到代码签名证书"
    security find-identity -v -p codesigning | grep -v "valid identities found" | head -2
else
    echo "⚠️  未找到有效证书"
fi

# 描述文件检查
echo "📄 描述文件..."
PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
if [ -d "$PROFILE_DIR" ]; then
    PROFILE_COUNT=$(find "$PROFILE_DIR" -name "*.mobileprovision" | wc -l)
    echo "✅ 找到 $PROFILE_COUNT 个描述文件"
else
    echo "⚠️  未找到描述文件目录"
fi

# Bundle ID 检查
echo "📦 应用配置..."
BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw BilibiliLive/Info.plist)
VERSION=$(plutil -extract CFBundleShortVersionString raw BilibiliLive/Info.plist)
echo "Bundle ID: $BUNDLE_ID"
echo "版本: $VERSION"

[[ "$BUNDLE_ID" == *"demo"* ]] && echo "⚠️  建议修改为唯一 Bundle ID"

# 构建测试
echo "🔨 构建测试..."
if xcodebuild clean -project BilibiliLive.xcodeproj -scheme BilibiliLive > /dev/null 2>&1; then
    echo "✅ 项目清理成功"
else
    echo "⚠️  项目清理失败"
fi

mkdir -p build

# 总结
echo ""
echo "📊 检查完成"
if [ "$CERT_COUNT" = "0" ] || [[ "$BUNDLE_ID" == *"demo"* ]]; then
    echo "🔧 需要配置证书或修改 Bundle ID"
    echo "📚 参考: docs/IPA_SIGNING.md"
else
    echo "🎉 环境就绪，可以运行签名脚本"
    echo "📝 编辑: vim scripts/sign_ipa.sh"
fi