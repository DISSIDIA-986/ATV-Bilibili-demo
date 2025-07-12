#!/bin/bash

# 代码格式化脚本
# Created by Claude on 2025/7/12

set -e

echo "✨ 代码格式化"
echo "============"

# 进入项目目录
cd "$(dirname "$0")/.."

# 检查 SwiftFormat 是否安装
if ! command -v swiftformat &> /dev/null; then
    echo "❌ SwiftFormat 未安装"
    echo "请运行: brew install swiftformat"
    exit 1
fi

# 格式化代码
echo "格式化 Swift 代码..."

# 使用项目配置的 SwiftFormat 参数
cd BuildTools
swift run swiftformat \
    --disable unusedArguments,numberFormatting,redundantReturn,andOperator,anyObjectProtocol,trailingClosures,redundantFileprivate \
    --ranges nospace \
    --swiftversion 5 \
    ../BilibiliLive

cd ..

echo "✅ 代码格式化完成"

# 检查格式化结果
echo "检查格式化结果..."
if git diff --quiet; then
    echo "✅ 代码格式符合规范"
else
    echo "⚠️  发现格式化更改，请提交这些更改"
    git diff --name-only
fi