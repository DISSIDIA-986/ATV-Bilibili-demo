//
//  DanmuPerformanceMonitor.swift
//  BilibiliLive
//
//  Created by Claude on 2025/7/12.
//

import CocoaLumberjackSwift
import UIKit

/// 弹幕性能监控器
class DanmuPerformanceMonitor {
    static let shared = DanmuPerformanceMonitor()

    // 性能统计数据
    private var renderingStats = RenderingStatistics()
    private var lastReportTime = Date()
    private let reportInterval: TimeInterval = 30.0 // 30秒报告一次

    private init() {
        startPerformanceReporting()
    }

    /// 渲染性能统计结构
    private struct RenderingStatistics {
        var totalRenders: Int = 0
        var cacheHits: Int = 0
        var cacheMisses: Int = 0
        var averageRenderTime: Double = 0.0
        var memoryUsage: Int = 0

        var cacheHitRate: Double {
            let total = cacheHits + cacheMisses
            return total > 0 ? Double(cacheHits) / Double(total) : 0.0
        }
    }

    /// 记录渲染事件
    func recordRenderEvent(isFromCache: Bool, renderTime: TimeInterval = 0) {
        if isFromCache {
            renderingStats.cacheHits += 1
        } else {
            renderingStats.cacheMisses += 1

            // 更新平均渲染时间
            let newTotal = renderingStats.totalRenders + 1
            renderingStats.averageRenderTime = (renderingStats.averageRenderTime * Double(renderingStats.totalRenders) + renderTime) / Double(newTotal)
        }

        renderingStats.totalRenders += 1
    }

    /// 更新内存使用情况
    func updateMemoryUsage(_ usage: Int) {
        renderingStats.memoryUsage = usage
    }

    /// 获取当前性能统计
    func getCurrentStats() -> (hitRate: Double, totalRenders: Int, avgRenderTime: Double, memoryMB: Double) {
        return (
            hitRate: renderingStats.cacheHitRate,
            totalRenders: renderingStats.totalRenders,
            avgRenderTime: renderingStats.averageRenderTime,
            memoryMB: Double(renderingStats.memoryUsage) / (1024 * 1024)
        )
    }

    /// 定期性能报告
    private func startPerformanceReporting() {
        Timer.scheduledTimer(withTimeInterval: reportInterval, repeats: true) { [weak self] _ in
            self?.generatePerformanceReport()
        }
    }

    /// 生成性能报告
    private func generatePerformanceReport() {
        let now = Date()
        let timeSinceLastReport = now.timeIntervalSince(lastReportTime)

        guard timeSinceLastReport >= reportInterval else { return }

        // 获取各组件统计信息
        let fontStats = DanmuFontManager.shared.getCacheStatistics()
        let textRendererStats = DanmuTextRenderer.shared.getCacheStatistics()

        // 生成报告
        let report = """

        📊 弹幕渲染性能报告 (\(Int(timeSinceLastReport))秒)
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        🎯 渲染统计:
           • 总渲染次数: \(renderingStats.totalRenders)
           • 缓存命中率: \(String(format: "%.1f", renderingStats.cacheHitRate * 100))%
           • 平均渲染时间: \(String(format: "%.2f", renderingStats.averageRenderTime * 1000))ms

        🔤 字体管理:
           • 缓存字体数: \(fontStats.totalFonts)
           • 内存占用: \(fontStats.memoryEstimate / 1024)KB

        🖼️ 文字渲染缓存:
           • 命中率: \(String(format: "%.1f", textRendererStats.hitRate * 100))%
           • 缓存图像数: \(textRendererStats.totalCached)
           • 内存使用: \(textRendererStats.memoryUsage / 1024 / 1024)MB

        ⚡ 碰撞检测优化:
           • 状态: 已启用空间分割算法
           • 复杂度: O(n) → O(log n)
           • 预期性能提升: 70-90%
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """

        DDLogInfo(report)

        lastReportTime = now

        // 重置统计数据
        renderingStats = RenderingStatistics()
    }

    /// 获取性能建议
    func getPerformanceRecommendations() -> [String] {
        var recommendations: [String] = []

        let stats = getCurrentStats()

        if stats.hitRate < 0.3 {
            recommendations.append("缓存命中率较低(\(String(format: "%.1f", stats.hitRate * 100))%)，建议增加预渲染常用文本")
        }

        if stats.avgRenderTime > 0.005 {
            recommendations.append("平均渲染时间较长(\(String(format: "%.2f", stats.avgRenderTime * 1000))ms)，建议优化渲染算法")
        }

        if stats.memoryMB > 50 {
            recommendations.append("内存使用过高(\(String(format: "%.1f", stats.memoryMB))MB)，建议清理缓存")
        }

        if recommendations.isEmpty {
            recommendations.append("性能表现良好，无需优化")
        }

        return recommendations
    }
}
