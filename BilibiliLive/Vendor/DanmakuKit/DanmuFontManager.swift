//
//  DanmuFontManager.swift
//  BilibiliLive
//
//  Created by Claude on 2025/7/12.
//

import UIKit

/// 弹幕字体资源池管理器
/// 负责统一管理和复用字体对象，避免重复创建
class DanmuFontManager {
    static let shared = DanmuFontManager()

    // 字体缓存池，按字体大小索引
    private var fontPool: [CGFloat: UIFont] = [:]
    private let lock = NSLock()

    // 预定义的常用字体大小
    private let commonSizes: [CGFloat] = [16, 18, 20, 22, 24, 26, 28]

    private init() {
        preloadCommonFonts()
        setupMemoryWarningObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// 获取指定大小的字体，优先从缓存池中获取
    func getFont(size: CGFloat) -> UIFont {
        lock.lock()
        defer { lock.unlock() }

        // 尝试从缓存池获取
        if let cachedFont = fontPool[size] {
            return cachedFont
        }

        // 创建新字体并缓存
        let font = UIFont.systemFont(ofSize: size)
        fontPool[size] = font

        Logger.debug("创建新字体缓存: 大小 \(size)")
        return font
    }

    /// 获取粗体字体
    func getBoldFont(size: CGFloat) -> UIFont {
        let boldSize = size + 1000 // 使用特殊标识区分粗体

        lock.lock()
        defer { lock.unlock() }

        if let cachedFont = fontPool[boldSize] {
            return cachedFont
        }

        let font = UIFont.boldSystemFont(ofSize: size)
        fontPool[boldSize] = font

        Logger.debug("创建新粗体字体缓存: 大小 \(size)")
        return font
    }

    /// 预加载常用字体大小
    private func preloadCommonFonts() {
        for size in commonSizes {
            _ = getFont(size: size)
        }
        Logger.info("预加载常用字体完成，共 \(commonSizes.count) 个字体")
    }

    /// 清理字体缓存
    func clearCache() {
        lock.lock()
        defer { lock.unlock() }

        let cachedCount = fontPool.count
        fontPool.removeAll()

        // 重新预加载常用字体
        preloadCommonFonts()

        Logger.warn("清理字体缓存: 清除 \(cachedCount) 个字体，重新预加载常用字体")
    }

    /// 获取缓存统计信息
    func getCacheStatistics() -> (totalFonts: Int, memoryEstimate: Int) {
        lock.lock()
        defer { lock.unlock() }

        let totalFonts = fontPool.count
        // 估算每个字体对象占用约2KB内存
        let memoryEstimate = totalFonts * 2048

        return (totalFonts: totalFonts, memoryEstimate: memoryEstimate)
    }

    /// 设置内存警告监听
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func handleMemoryWarning() {
        Logger.warn("收到内存警告，清理字体缓存")

        lock.lock()
        defer { lock.unlock() }

        // 只保留常用字体，清除其他字体
        let commonFonts = fontPool.filter { key, _ in
            commonSizes.contains(key) || key > 1000 // 保留常用大小和粗体字体
        }

        let clearedCount = fontPool.count - commonFonts.count
        fontPool = commonFonts

        Logger.info("内存警告清理完成: 保留 \(commonFonts.count) 个字体，清除 \(clearedCount) 个字体")
    }
}

// MARK: - Settings Extension

extension Settings {
    /// 获取当前弹幕字体（使用字体池）
    static var danmuFont: UIFont {
        return DanmuFontManager.shared.getFont(size: Settings.danmuSize.size)
    }

    /// 获取当前弹幕粗体字体（使用字体池）
    static var danmuBoldFont: UIFont {
        return DanmuFontManager.shared.getBoldFont(size: Settings.danmuSize.size)
    }
}
