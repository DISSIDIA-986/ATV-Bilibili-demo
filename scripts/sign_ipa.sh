#!/bin/bash

# IPA 签名脚本
# 详细说明请参考: docs/IPA_SIGNING.md

set -e

echo "📱 IPA 签名工具"
echo "==============="

# 配置参数 - 请在此处修改你的设置
TEAM_ID=""                      # 开发者团队ID
BUNDLE_ID=""                    # Bundle标识符，如: com.yourname.bilibiliive
EXPORT_METHOD="ad-hoc"          # ad-hoc 或 enterprise
OUTPUT_DIR="./build"
ARCHIVE_PATH="$OUTPUT_DIR/BilibiliLive.xcarchive"
IPA_NAME="BilibiliLive-signed.ipa"

# 参数检查
if [ -z "$TEAM_ID" ] || [ -z "$BUNDLE_ID" ]; then
    echo "❌ 请先在脚本中配置 TEAM_ID 和 BUNDLE_ID"
    echo "📚 详细说明: docs/IPA_SIGNING.md"
    exit 1
fi

if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 未找到 Xcode"
    exit 1
fi

# 进入项目目录并创建输出目录
cd "$(dirname "$0")/.."
mkdir -p "$OUTPUT_DIR"

# 创建 ExportOptions.plist
cat > "$OUTPUT_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>$EXPORT_METHOD</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>compileBitcode</key>
    <false/>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
EOF

echo "🔧 团队ID: $TEAM_ID | Bundle ID: $BUNDLE_ID | 方式: $EXPORT_METHOD"

# 更新 Bundle ID
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" BilibiliLive/Info.plist

# Archive 项目
echo "🔨 Archive 项目..."
xcodebuild archive \
    -project BilibiliLive.xcodeproj \
    -scheme BilibiliLive \
    -destination 'generic/platform=tvOS' \
    -archivePath "$ARCHIVE_PATH" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Automatic

# 导出 IPA
echo "📦 导出 IPA..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$OUTPUT_DIR" \
    -exportOptionsPlist "$OUTPUT_DIR/ExportOptions.plist"

# 重命名文件
if [ -f "$OUTPUT_DIR/BilibiliLive.ipa" ]; then
    mv "$OUTPUT_DIR/BilibiliLive.ipa" "$OUTPUT_DIR/$IPA_NAME"
    echo "✅ 签名完成: $OUTPUT_DIR/$IPA_NAME"
    ls -lh "$OUTPUT_DIR/$IPA_NAME"
    
    # 计算哈希
    command -v shasum > /dev/null && shasum -a 256 "$OUTPUT_DIR/$IPA_NAME"
else
    echo "❌ 导出失败"
    exit 1
fi