#!/bin/bash

# 安装依赖脚本
# Created by Claude on 2025/7/12

set -e

echo "📥 安装项目依赖"
echo "=============="

# 检查 Homebrew
if ! command -v brew &> /dev/null; then
    echo "安装 Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "✅ Homebrew 已安装"
fi

# 安装 SwiftFormat
if ! command -v swiftformat &> /dev/null; then
    echo "安装 SwiftFormat..."
    brew install swiftformat
else
    echo "✅ SwiftFormat 已安装"
fi

# 安装 Ruby 和 Bundler (如果需要 Fastlane)
if ! command -v bundle &> /dev/null; then
    echo "安装 Bundler..."
    if command -v gem &> /dev/null; then
        gem install bundler
    else
        echo "⚠️  警告: Ruby 未安装，跳过 Bundler"
    fi
else
    echo "✅ Bundler 已安装"
fi

# 安装 Fastlane (可选)
if [ "$1" = "--with-fastlane" ]; then
    if ! command -v fastlane &> /dev/null; then
        echo "安装 Fastlane..."
        gem install fastlane
    else
        echo "✅ Fastlane 已安装"
    fi
fi

echo ""
echo "✅ 依赖安装完成"
echo ""
echo "📋 已安装工具:"
command -v brew && echo "  - Homebrew: $(brew --version | head -1)"
command -v swiftformat && echo "  - SwiftFormat: $(swiftformat --version)"
command -v bundle && echo "  - Bundler: $(bundle --version)"
command -v fastlane && echo "  - Fastlane: $(fastlane --version | head -1)" || echo "  - Fastlane: 未安装"