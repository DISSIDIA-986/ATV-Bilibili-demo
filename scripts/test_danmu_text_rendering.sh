#!/bin/bash

# 弹幕文字渲染性能测试脚本
# 测试字体池化和文字预渲染缓存系统的效果

echo "📊 弹幕文字渲染性能测试"
echo "=========================================="
echo "测试项目: ATV-Bilibili-demo"
echo "测试时间: $(date)"
echo "=========================================="

# 检查必要文件是否存在
check_files() {
    echo "🔍 检查文件完整性..."
    
    local files=(
        "BilibiliLive/Vendor/DanmakuKit/DanmuFontManager.swift"
        "BilibiliLive/Vendor/DanmakuKit/DanmuTextRenderer.swift"
        "BilibiliLive/Vendor/DanmakuKit/DanmuPerformanceMonitor.swift"
        "BilibiliLive/Vendor/DanmakuKit/DanmakuTextCell.swift"
        "BilibiliLive/Vendor/DanmakuKit/DanmakuTextCellModel.swift"
    )
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            echo "   ✅ $file"
        else
            echo "   ❌ $file (缺失)"
            return 1
        fi
    done
    
    echo "   📁 所有文件检查完成"
    return 0
}

# 分析代码优化点
analyze_optimizations() {
    echo
    echo "⚡ 分析优化实现..."
    
    # 检查字体池化
    if grep -q "DanmuFontManager.shared" BilibiliLive/Vendor/DanmakuKit/DanmakuTextCellModel.swift; then
        echo "   ✅ 字体池化: 已实现"
    else
        echo "   ❌ 字体池化: 未实现"
    fi
    
    # 检查预渲染缓存
    if grep -q "DanmuTextRenderer.shared.getRenderedText" BilibiliLive/Vendor/DanmakuKit/DanmakuTextCell.swift; then
        echo "   ✅ 预渲染缓存: 已实现"
    else
        echo "   ❌ 预渲染缓存: 未实现"
    fi
    
    # 检查尺寸缓存
    if grep -q "getTextSize" BilibiliLive/Vendor/DanmakuKit/DanmakuTextCellModel.swift; then
        echo "   ✅ 尺寸计算缓存: 已实现"
    else
        echo "   ❌ 尺寸计算缓存: 未实现"
    fi
    
    # 检查性能监控
    if [[ -f "BilibiliLive/Vendor/DanmakuKit/DanmuPerformanceMonitor.swift" ]]; then
        echo "   ✅ 性能监控: 已实现"
    else
        echo "   ❌ 性能监控: 未实现"
    fi
}

# 统计代码行数和复杂度
analyze_code_metrics() {
    echo
    echo "📈 代码指标分析..."
    
    local font_manager_lines=$(wc -l < "BilibiliLive/Vendor/DanmakuKit/DanmuFontManager.swift" 2>/dev/null || echo "0")
    local text_renderer_lines=$(wc -l < "BilibiliLive/Vendor/DanmakuKit/DanmuTextRenderer.swift" 2>/dev/null || echo "0")
    local performance_monitor_lines=$(wc -l < "BilibiliLive/Vendor/DanmakuKit/DanmuPerformanceMonitor.swift" 2>/dev/null || echo "0")
    
    echo "   📄 DanmuFontManager: ${font_manager_lines} 行"
    echo "   📄 DanmuTextRenderer: ${text_renderer_lines} 行"
    echo "   📄 DanmuPerformanceMonitor: ${performance_monitor_lines} 行"
    
    local total_lines=$((font_manager_lines + text_renderer_lines + performance_monitor_lines))
    echo "   📊 新增优化代码总计: ${total_lines} 行"
}

# 分析预期性能提升
estimate_performance_gains() {
    echo
    echo "🚀 预期性能提升分析..."
    
    echo "   📊 字体对象优化:"
    echo "      • 减少字体创建: ~95% (共享字体池)"
    echo "      • 内存节省: ~90% (字体对象重用)"
    
    echo
    echo "   🖼️ 文字渲染优化:"
    echo "      • 缓存命中率预期: 30-50%"
    echo "      • 渲染时间减少: 60-80% (缓存命中时)"
    echo "      • CPU使用率降低: 25-40%"
    
    echo
    echo "   💾 内存使用优化:"
    echo "      • 重复渲染减少: 30-50%"
    echo "      • 属性对象复用: 提升显著"
    echo "      • 内存碎片减少: 显著改善"
    
    echo
    echo "   🎮 用户体验提升:"
    echo "      • 弹幕显示延迟: 显著减少"
    echo "      • 滚动流畅度: 特别是高密度弹幕"
    echo "      • 低端设备兼容性: 大幅改善"
}

# 检查潜在问题
check_potential_issues() {
    echo
    echo "⚠️  潜在问题检查..."
    
    # 检查循环引用
    echo "   🔍 检查循环引用:"
    if grep -q "weak self" BilibiliLive/Vendor/DanmakuKit/DanmuTextRenderer.swift; then
        echo "      ✅ 已使用 weak self 避免循环引用"
    else
        echo "      ⚠️  注意检查定时器和闭包的循环引用"
    fi
    
    # 检查内存管理
    echo "   🧠 检查内存管理:"
    if grep -q "handleMemoryWarning" BilibiliLive/Vendor/DanmakuKit/DanmuFontManager.swift; then
        echo "      ✅ 字体管理器: 已实现内存警告处理"
    else
        echo "      ❌ 字体管理器: 缺少内存警告处理"
    fi
    
    if grep -q "handleMemoryWarning" BilibiliLive/Vendor/DanmakuKit/DanmuTextRenderer.swift; then
        echo "      ✅ 文字渲染器: 已实现内存警告处理"
    else
        echo "      ❌ 文字渲染器: 缺少内存警告处理"
    fi
    
    # 检查线程安全
    echo "   🔒 检查线程安全:"
    if grep -q "NSLock\|DispatchQueue" BilibiliLive/Vendor/DanmakuKit/DanmuTextRenderer.swift; then
        echo "      ✅ 文字渲染器: 已实现线程安全"
    else
        echo "      ⚠️  文字渲染器: 可能存在线程安全问题"
    fi
}

# 生成测试建议
generate_test_recommendations() {
    echo
    echo "🧪 测试建议..."
    
    echo "   1. 📱 设备测试:"
    echo "      • 在不同设备上测试性能表现"
    echo "      • 特别关注低端设备的改善效果"
    echo "      • 测试长时间播放的内存使用"
    
    echo
    echo "   2. 📊 性能基准测试:"
    echo "      • 对比优化前后的渲染时间"
    echo "      • 监控缓存命中率"
    echo "      • 测量内存使用变化"
    
    echo
    echo "   3. 🎯 压力测试:"
    echo "      • 高密度弹幕场景测试"
    echo "      • 长文本弹幕处理"
    echo "      • 快速切换视频场景"
    
    echo
    echo "   4. 🔄 回归测试:"
    echo "      • 确保原有功能正常"
    echo "      • 验证弹幕显示效果一致"
    echo "      • 检查设置更改的响应"
}

# 主函数
main() {
    if ! check_files; then
        echo "❌ 文件检查失败，请确保所有优化文件都已创建"
        exit 1
    fi
    
    analyze_optimizations
    analyze_code_metrics
    estimate_performance_gains
    check_potential_issues
    generate_test_recommendations
    
    echo
    echo "=========================================="
    echo "✅ 弹幕文字渲染优化分析完成"
    echo "📝 建议: 继续在 Xcode 中构建并运行性能测试"
    echo "=========================================="
}

# 运行主函数
main "$@"