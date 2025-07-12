# 开发者账号签名IPA分发指南

## 📋 概述

本文档详细说明如何使用开发者账号为 ATV-Bilibili-demo 签名并分发给测试用户。

## 🔐 前提条件

### 必需的开发者账号
- **Apple Developer Program** 账号 ($99/年)
- 或 **Apple Developer Enterprise Program** 账号 ($299/年，仅限企业内部分发)

### 开发环境
- macOS 14.0+
- Xcode 15.0+
- 有效的开发者证书和描述文件

## 🛠️ 签名方法

### 方法一：Xcode Archive 签名 (推荐)

#### 1. 配置证书和描述文件
```bash
# 确保已登录开发者账号
# Xcode > Settings > Accounts > 添加 Apple ID
```

#### 2. 配置项目签名
1. 打开 `BilibiliLive.xcodeproj`
2. 选择项目 → Targets → BilibiliLive
3. 签名与功能 (Signing & Capabilities):
   - **Team**: 选择你的开发者团队
   - **Bundle Identifier**: 修改为唯一标识符 (如: `com.yourname.bilibiliive`)
   - **Signing Certificate**: 选择合适的证书

#### 3. Archive 和导出
```bash
# 或使用命令行 Archive
xcodebuild archive \
    -project BilibiliLive.xcodeproj \
    -scheme BilibiliLive \
    -destination 'generic/platform=tvOS' \
    -archivePath ./build/BilibiliLive.xcarchive

# 导出 IPA
xcodebuild -exportArchive \
    -archivePath ./build/BilibiliLive.xcarchive \
    -exportPath ./build \
    -exportOptionsPlist ExportOptions.plist
```

### 方法二：Fastlane 自动化签名

#### 1. 安装 Fastlane
```bash
# 已在 setup.sh 中包含
gem install fastlane
```

#### 2. 创建 Fastfile
```ruby
# fastlane/Fastfile
default_platform(:tvos)

platform :tvos do
  desc "Build and sign IPA for distribution"
  lane :build_signed_ipa do
    # 同步证书和描述文件
    match(type: "adhoc", platform: "tvos")
    
    # 构建项目
    build_app(
      project: "BilibiliLive.xcodeproj",
      scheme: "BilibiliLive",
      destination: "generic/platform=tvOS",
      export_method: "ad-hoc",
      output_directory: "./build",
      output_name: "BilibiliLive-signed.ipa"
    )
  end
  
  desc "Build for enterprise distribution"
  lane :build_enterprise_ipa do
    match(type: "enterprise", platform: "tvos")
    
    build_app(
      project: "BilibiliLive.xcodeproj", 
      scheme: "BilibiliLive",
      destination: "generic/platform=tvOS",
      export_method: "enterprise",
      output_directory: "./build",
      output_name: "BilibiliLive-enterprise.ipa"
    )
  end
end
```

#### 3. 运行 Fastlane
```bash
# Ad-hoc 分发 (最多100台设备)
fastlane build_signed_ipa

# 企业分发 (企业账号)
fastlane build_enterprise_ipa
```

### 方法三：手动签名工具

#### 使用 iOS App Signer
```bash
# 下载 iOS App Signer 工具
# 选择未签名的 IPA 文件
# 选择签名证书和描述文件
# 导出签名后的 IPA
```

## 📱 分发方式

### 1. Ad-hoc 分发 (开发者账号)

#### 设备注册要求
- 最多支持 100 台 Apple TV 设备
- 必须预先在开发者中心注册设备 UDID

#### 获取 Apple TV UDID
```bash
# 方法1: Xcode 设备管理器
# Window > Devices and Simulators > 连接 Apple TV

# 方法2: Apple Configurator 2
# 从 Mac App Store 下载并连接设备

# 方法3: 系统信息
# Apple TV: 设置 > 通用 > 关于本机 > 标识符
```

#### 注册设备
1. 登录 [Apple Developer Center](https://developer.apple.com)
2. 证书、标识符和描述文件 > 设备 > 注册设备
3. 输入设备名称和 UDID
4. 重新生成 Ad-hoc 描述文件

### 2. 企业分发 (企业账号)

#### 优势
- 无设备数量限制
- 无需注册设备 UDID
- 支持无线安装

#### 限制
- 仅限企业内部员工使用
- 不得向公众分发
- 需要企业开发者账号 ($299/年)

### 3. TestFlight 分发

#### 注意事项
⚠️ **重要**: 由于 ATV-Bilibili-demo 使用了第三方服务API，可能不符合 App Store 审核指南，TestFlight 分发存在风险。

#### 如果要尝试 TestFlight
```bash
# 1. 提交到 App Store Connect
# 2. 通过内部测试 (最多25人)
# 3. 外部测试需要苹果审核
```

## 🔧 配置文件示例

### ExportOptions.plist (Ad-hoc)
```xml
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
```

### ExportOptions.plist (Enterprise)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>enterprise</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>compileBitcode</key>
    <false/>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
```

## 📦 自动化脚本

### 创建签名脚本

<function_calls>
<invoke name="Write">
<parameter name="content">#!/bin/bash

# IPA 签名脚本
# Created by Claude on 2025/7/12

set -e

echo "📱 ATV-Bilibili-demo IPA 签名工具"
echo "================================="

# 配置参数
TEAM_ID=""
BUNDLE_ID=""
EXPORT_METHOD="ad-hoc"  # ad-hoc 或 enterprise
OUTPUT_DIR="./build"
ARCHIVE_PATH="$OUTPUT_DIR/BilibiliLive.xcarchive"
IPA_NAME="BilibiliLive-signed.ipa"

# 检查参数
if [ -z "$TEAM_ID" ]; then
    echo "❌ 错误: 请在脚本中设置 TEAM_ID"
    echo "可在 Apple Developer Center 查看团队ID"
    exit 1
fi

if [ -z "$BUNDLE_ID" ]; then
    echo "❌ 错误: 请在脚本中设置 BUNDLE_ID"
    echo "例如: com.yourname.bilibiliive"
    exit 1
fi

# 检查开发环境
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 错误: 未找到 Xcode"
    exit 1
fi

# 进入项目目录
cd "$(dirname "$0")/.."

# 创建输出目录
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

echo "🔧 配置信息:"
echo "  团队ID: $TEAM_ID"
echo "  Bundle ID: $BUNDLE_ID" 
echo "  导出方式: $EXPORT_METHOD"
echo "  输出目录: $OUTPUT_DIR"

# 检查项目配置
echo ""
echo "📋 检查项目配置..."

# 临时修改 Bundle Identifier (如果需要)
if [ -n "$BUNDLE_ID" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" BilibiliLive/Info.plist
    echo "✅ Bundle ID 已更新为: $BUNDLE_ID"
fi

# Archive 项目
echo ""
echo "🔨 Archive 项目..."
xcodebuild archive \
    -project BilibiliLive.xcodeproj \
    -scheme BilibiliLive \
    -destination 'generic/platform=tvOS' \
    -archivePath "$ARCHIVE_PATH" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Automatic

echo "✅ Archive 完成"

# 导出 IPA
echo ""
echo "📦 导出 IPA..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$OUTPUT_DIR" \
    -exportOptionsPlist "$OUTPUT_DIR/ExportOptions.plist"

# 重命名 IPA 文件
if [ -f "$OUTPUT_DIR/BilibiliLive.ipa" ]; then
    mv "$OUTPUT_DIR/BilibiliLive.ipa" "$OUTPUT_DIR/$IPA_NAME"
    echo "✅ IPA 导出成功: $OUTPUT_DIR/$IPA_NAME"
else
    echo "❌ IPA 导出失败"
    exit 1
fi

# 显示文件信息
echo ""
echo "📊 文件信息:"
ls -lh "$OUTPUT_DIR/$IPA_NAME"

# 计算文件哈希
if command -v shasum &> /dev/null; then
    echo ""
    echo "🔐 文件哈希:"
    shasum -a 256 "$OUTPUT_DIR/$IPA_NAME"
fi

echo ""
echo "🎉 签名完成!"
echo ""
echo "📋 下一步操作:"
echo "1. 将 IPA 文件分发给测试用户"
echo "2. 测试用户需要将设备 UDID 注册到开发者账号 (Ad-hoc 分发)"
echo "3. 使用 Apple Configurator 2 或 Xcode 安装 IPA"
echo ""
echo "⚠️  注意事项:"
echo "- Ad-hoc 分发最多支持 100 台设备"
echo "- 企业分发仅限企业内部使用"
echo "- 证书过期前需要重新签名"
EOF
echo ""