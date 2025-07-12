#!/bin/bash

# IPA 签名功能测试脚本
# Created by Claude on 2025/7/12

set -e

echo "🧪 IPA 签名功能测试"
echo "=================="

# 进入项目目录
cd "$(dirname "$0")/.."

echo "📋 检查签名环境..."

# 检查 Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 错误: 未找到 Xcode"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -n1 | awk '{print $2}')
echo "✅ Xcode 版本: $XCODE_VERSION"

# 检查项目文件
if [ ! -f "BilibiliLive.xcodeproj/project.pbxproj" ]; then
    echo "❌ 错误: 未找到项目文件"
    exit 1
fi

echo "✅ 项目文件存在"

# 检查签名脚本
if [ ! -f "scripts/sign_ipa.sh" ]; then
    echo "❌ 错误: 未找到签名脚本"
    exit 1
fi

echo "✅ 签名脚本存在"

# 检查证书 (如果已配置)
echo ""
echo "🔐 检查代码签名证书..."
CERT_COUNT=$(security find-identity -v -p codesigning | grep -c "valid identities found" || echo "0")

if [ "$CERT_COUNT" != "0" ]; then
    echo "📱 可用的开发者证书:"
    security find-identity -v -p codesigning | grep -v "valid identities found"
else
    echo "⚠️  警告: 未找到有效的代码签名证书"
    echo "请在 Xcode 中配置开发者账号和证书"
fi

# 检查描述文件
echo ""
echo "📄 检查描述文件..."
PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"

if [ -d "$PROFILE_DIR" ]; then
    PROFILE_COUNT=$(find "$PROFILE_DIR" -name "*.mobileprovision" | wc -l)
    echo "📋 找到 $PROFILE_COUNT 个描述文件"
    
    if [ "$PROFILE_COUNT" -gt 0 ]; then
        echo "最近的描述文件:"
        find "$PROFILE_DIR" -name "*.mobileprovision" -print0 | xargs -0 ls -lt | head -3
    fi
else
    echo "⚠️  警告: 未找到描述文件目录"
fi

# 测试项目构建能力
echo ""
echo "🔨 测试项目构建能力..."

# 尝试 Clean 项目
if xcodebuild clean -project BilibiliLive.xcodeproj -scheme BilibiliLive > /dev/null 2>&1; then
    echo "✅ 项目清理成功"
else
    echo "⚠️  警告: 项目清理失败"
fi

# 尝试分析项目 (不实际构建)
echo "分析项目配置..."
if xcodebuild analyze -project BilibiliLive.xcodeproj -scheme BilibiliLive -destination 'platform=tvOS Simulator,name=Apple TV' > /dev/null 2>&1; then
    echo "✅ 项目分析通过"
else
    echo "⚠️  警告: 项目分析失败，可能需要配置签名"
fi

# 检查 Bundle ID 配置
echo ""
echo "📦 检查 Bundle ID 配置..."
BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw BilibiliLive/Info.plist)
echo "当前 Bundle ID: $BUNDLE_ID"

if [[ "$BUNDLE_ID" == *"demo"* ]]; then
    echo "⚠️  建议: 分发前请修改为唯一的 Bundle ID"
    echo "推荐格式: com.yourname.bilibiliive"
fi

# 检查版本信息
BUNDLE_VERSION=$(plutil -extract CFBundleShortVersionString raw BilibiliLive/Info.plist)
BUILD_NUMBER=$(plutil -extract CFBundleVersion raw BilibiliLive/Info.plist)
echo "应用版本: $BUNDLE_VERSION (Build $BUILD_NUMBER)"

# 生成示例配置
echo ""
echo "📝 生成示例签名配置..."

cat > ExportOptions.plist.example << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>ad-hoc</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>compileBitcode</key>
    <false/>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
EOF

echo "✅ 示例配置文件已生成: ExportOptions.plist.example"

# 检查构建目录
echo ""
echo "📁 检查构建目录..."
mkdir -p build
echo "✅ 构建目录已创建: ./build"

# 总结报告
echo ""
echo "📊 签名环境检查总结"
echo "==================="

# 统计检查结果
PASS_COUNT=0
WARN_COUNT=0

echo "✅ 通过的检查项:"
[ -f "BilibiliLive.xcodeproj/project.pbxproj" ] && { echo "  - 项目文件存在"; ((PASS_COUNT++)); }
[ -f "scripts/sign_ipa.sh" ] && { echo "  - 签名脚本存在"; ((PASS_COUNT++)); }
command -v xcodebuild &> /dev/null && { echo "  - Xcode 已安装"; ((PASS_COUNT++)); }

echo ""
echo "⚠️  需要注意的项目:"
if [ "$CERT_COUNT" = "0" ]; then
    echo "  - 需要配置开发者证书"
    ((WARN_COUNT++))
fi

if [ ! -d "$PROFILE_DIR" ] || [ "$(find "$PROFILE_DIR" -name "*.mobileprovision" | wc -l)" -eq 0 ]; then
    echo "  - 需要配置描述文件"
    ((WARN_COUNT++))
fi

if [[ "$BUNDLE_ID" == *"demo"* ]]; then
    echo "  - 建议修改 Bundle ID"
    ((WARN_COUNT++))
fi

echo ""
echo "📈 检查结果: $PASS_COUNT 项通过, $WARN_COUNT 项需要注意"

if [ "$WARN_COUNT" -eq 0 ]; then
    echo "🎉 环境检查完成，可以尝试签名!"
    echo ""
    echo "📖 下一步操作:"
    echo "1. 编辑签名脚本: vim scripts/sign_ipa.sh"
    echo "2. 设置 TEAM_ID 和 BUNDLE_ID"
    echo "3. 运行签名: ./scripts/sign_ipa.sh"
else
    echo "🔧 请先解决上述注意事项，然后重新运行检查"
    echo ""
    echo "📚 参考文档:"
    echo "- 部署文档: docs/DEPLOYMENT.md"
    echo "- IPA签名指南: docs/IPA_SIGNING.md"
fi

# 清理临时文件
# rm -f ExportOptions.plist.example  # 保留作为参考

echo ""
echo "✅ 签名环境检查完成"