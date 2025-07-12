#!/bin/bash

echo "=== Bilibili tvOS 项目编译准备检查 ==="
echo ""

# 检查 Xcode 安装
if [ -d "/Applications/Xcode.app" ]; then
    echo "✅ Xcode 已安装"
    xcode_version=$(plutil -extract CFBundleShortVersionString raw "/Applications/Xcode.app/Contents/Info.plist" 2>/dev/null)
    if [ -n "$xcode_version" ]; then
        echo "   版本: $xcode_version"
    fi
else
    echo "❌ Xcode 未安装"
    exit 1
fi

echo ""

# 检查项目文件
echo "📱 检查项目文件:"
if [ -f "BilibiliLive.xcodeproj/project.pbxproj" ]; then
    echo "✅ 项目文件存在"
else
    echo "❌ 项目文件不存在"
    exit 1
fi

echo ""

# 检查新添加的文件是否需要添加到项目
echo "📝 检查新增文件状态:"

new_files=(
    "BilibiliLive/Component/Video/DanmuMemoryMonitor.swift"
)

for file in "${new_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file 存在"
        # 检查是否在项目中
        if grep -q "DanmuMemoryMonitor.swift" "BilibiliLive.xcodeproj/project.pbxproj"; then
            echo "   ✅ 已添加到项目"
        else
            echo "   ⚠️  需要在Xcode中添加到项目"
        fi
    else
        echo "❌ $file 不存在"
    fi
done

echo ""

# 检查Swift语法
echo "🔍 Swift语法检查:"

swift_files=(
    "BilibiliLive/Component/Video/DanmuMemoryMonitor.swift"
    "BilibiliLive/Component/Video/VideoDanmuProvider.swift"
    "BilibiliLive/Component/Player/Plugins/DanmuViewPlugin.swift"
)

for file in "${swift_files[@]}"; do
    if [ -f "$file" ]; then
        # 基本语法检查
        if swift -frontend -parse "$file" >/dev/null 2>&1; then
            echo "✅ $file 语法正确"
        else
            echo "❌ $file 语法错误"
            echo "   错误详情:"
            swift -frontend -parse "$file" 2>&1 | head -5
        fi
    fi
done

echo ""

# 检查编译环境
echo "🛠️  编译环境检查:"

# 检查开发者工具路径
dev_dir=$(xcode-select -p 2>/dev/null)
if [[ "$dev_dir" == *"Xcode.app"* ]]; then
    echo "✅ 开发者工具路径正确: $dev_dir"
else
    echo "⚠️  开发者工具路径: $dev_dir"
    echo "   建议运行: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
fi

echo ""

# 模拟器检查
echo "📱 tvOS模拟器检查:"
if [ -d "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app" ]; then
    echo "✅ 模拟器已安装"
else
    echo "❌ 模拟器未找到"
fi

echo ""

# 编译建议
echo "🎯 编译建议:"
echo "1. 在Xcode中打开项目: open BilibiliLive.xcodeproj"
echo "2. 将新文件添加到项目:"
echo "   - DanmuMemoryMonitor.swift"
echo "3. 选择tvOS模拟器作为目标设备"
echo "4. 按 Cmd+R 运行项目"

echo ""

# 测试建议
echo "🧪 功能测试建议:"
echo "1. 启动应用后播放任意视频"
echo "2. 开启弹幕显示"
echo "3. 在Xcode内存图表中观察内存使用"
echo "4. 长时间播放验证内存优化效果"
echo "5. 检查控制台是否有内存监控日志"

echo ""

# 可能的编译问题
echo "⚠️  可能的编译问题:"
echo "1. 新增文件未添加到项目 -> 在Xcode中手动添加"
echo "2. 导入语句缺失 -> 检查import声明"
echo "3. 目标平台不匹配 -> 确保选择tvOS"
echo "4. 依赖库版本问题 -> 更新Package.resolved"

echo ""
echo "=== 检查完成 ==="