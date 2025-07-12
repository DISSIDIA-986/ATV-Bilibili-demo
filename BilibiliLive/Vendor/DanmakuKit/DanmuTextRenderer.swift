//
//  DanmuTextRenderer.swift
//  BilibiliLive
//
//  Created by Claude on 2025/7/12.
//

import UIKit

/// 弹幕缓存策略
enum DanmuCacheStrategy {
    case frequent // 高频文本，永久缓存
    case normal // 普通文本，LRU缓存
    case temporary // 临时文本，不缓存

    /// 根据文本内容智能判断缓存策略
    static func strategy(for text: String) -> DanmuCacheStrategy {
        // 短文本或数字，高频缓存
        if text.count <= 2 { return .frequent }

        // 常见弹幕表达
        if isCommonPhrase(text) { return .frequent }

        // 长文本不缓存，避免内存浪费
        if text.count > 20 { return .temporary }

        // 默认普通缓存
        return .normal
    }

    /// 判断是否为常见弹幕短语
    private static func isCommonPhrase(_ text: String) -> Bool {
        let commonPhrases = [
            "6666", "666", "66666", "牛逼", "牛批", "哈哈哈", "哈哈", "2333", "233",
            "笑死", "好家伙", "绝了", "真的假的", "卧槽", "强", "秀", "可以", "不错",
            "厉害", "赞", "顶", "支持", "加油", "谢谢", "感谢", "[doge]", "[滑稽]",
        ]
        return commonPhrases.contains(text.lowercased())
    }
}

/// 弹幕文字预渲染和缓存管理器
class DanmuTextRenderer {
    static let shared = DanmuTextRenderer()

    // 渲染图像缓存
    private let imageCache = NSCache<NSString, UIImage>()

    // 文字属性缓存
    private var attributesCache: [String: [NSAttributedString.Key: Any]] = [:]
    private var sizeCache: [String: CGSize] = [:]

    // 渲染队列
    private let renderQueue = DispatchQueue(label: "danmu.text.render", qos: .userInteractive)
    private let cacheQueue = DispatchQueue(label: "danmu.cache.manage", qos: .utility)

    // 缓存管理
    private let lock = NSLock()
    private var cacheHitCount: Int = 0
    private var cacheMissCount: Int = 0

    // 常用弹幕预渲染
    private let commonTexts = ["6666", "666", "哈哈哈", "牛逼", "强", "2333", "笑死", "好家伙"]

    private init() {
        setupCacheConfiguration()
        setupMemoryManagement()
        scheduleCommonTextPrerendering()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    /// 获取渲染后的文字图像，优先从缓存获取
    func getRenderedText(
        text: String,
        font: UIFont,
        color: UIColor,
        strokeColor: UIColor,
        alpha: CGFloat = 1.0,
        strokeWidth: CGFloat = 1.0
    ) -> UIImage? {
        let cacheKey = generateCacheKey(
            text: text,
            font: font,
            color: color,
            strokeColor: strokeColor,
            alpha: alpha,
            strokeWidth: strokeWidth
        )

        // 尝试从缓存获取
        if let cachedImage = imageCache.object(forKey: cacheKey as NSString) {
            incrementCacheHit()
            return cachedImage
        }

        incrementCacheMiss()

        // 根据策略决定是否缓存
        let strategy = DanmuCacheStrategy.strategy(for: text)

        // 渲染新图像
        let renderedImage = renderTextImage(
            text: text,
            font: font,
            color: color,
            strokeColor: strokeColor,
            alpha: alpha,
            strokeWidth: strokeWidth
        )

        // 根据策略缓存图像
        if strategy != .temporary, let image = renderedImage {
            cacheRenderedImage(image: image, key: cacheKey, strategy: strategy)
        }

        return renderedImage
    }

    /// 预渲染常用文本
    func prerenderCommonTexts() {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }

            let font = DanmuFontManager.shared.getFont(size: 20) // 默认大小
            let color = UIColor.white
            let strokeColor = UIColor.black

            for text in self.commonTexts {
                _ = self.getRenderedText(
                    text: text,
                    font: font,
                    color: color,
                    strokeColor: strokeColor
                )
            }

            Logger.info("预渲染常用弹幕文本完成: \(self.commonTexts.count) 个")
        }
    }

    /// 计算文字尺寸（带缓存）
    func getTextSize(text: String, font: UIFont) -> CGSize {
        let sizeKey = "\(text)_\(font.pointSize)"

        lock.lock()
        defer { lock.unlock() }

        if let cachedSize = sizeCache[sizeKey] {
            return cachedSize
        }

        let size = NSString(string: text).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 20),
            options: [.usesFontLeading, .usesLineFragmentOrigin],
            attributes: [.font: font],
            context: nil
        ).size

        // 缓存尺寸（限制缓存数量）
        if sizeCache.count < 1000 {
            sizeCache[sizeKey] = size
        }

        return size
    }

    /// 获取渲染属性（带缓存）
    func getTextAttributes(font: UIFont, color: UIColor) -> [NSAttributedString.Key: Any] {
        let key = "\(font.pointSize)_\(color.hexString)"

        lock.lock()
        defer { lock.unlock() }

        if let cached = attributesCache[key] {
            return cached
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]

        // 缓存属性（限制缓存数量）
        if attributesCache.count < 500 {
            attributesCache[key] = attributes
        }

        return attributes
    }

    /// 获取缓存统计信息
    func getCacheStatistics() -> (hitRate: Double, totalCached: Int, memoryUsage: Int) {
        let totalRequests = cacheHitCount + cacheMissCount
        let hitRate = totalRequests > 0 ? Double(cacheHitCount) / Double(totalRequests) : 0.0

        let totalCached = imageCache.countLimit
        let memoryUsage = Int(imageCache.totalCostLimit)

        return (hitRate: hitRate, totalCached: totalCached, memoryUsage: memoryUsage)
    }

    // MARK: - Private Methods

    /// 渲染文字图像
    private func renderTextImage(
        text: String,
        font: UIFont,
        color: UIColor,
        strokeColor: UIColor,
        alpha: CGFloat,
        strokeWidth: CGFloat
    ) -> UIImage? {
        let textSize = getTextSize(text: text, font: font)
        let imageSize = CGSize(
            width: ceil(textSize.width) + strokeWidth * 2,
            height: ceil(textSize.height) + strokeWidth * 2
        )

        UIGraphicsBeginImageContextWithOptions(imageSize, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }

        context.setAlpha(alpha)
        context.setLineWidth(strokeWidth)
        context.setLineJoin(.round)

        let drawPoint = CGPoint(x: strokeWidth, y: strokeWidth)
        let nsText = NSString(string: text)

        // 绘制描边
        context.saveGState()
        context.setTextDrawingMode(.stroke)
        let strokeAttributes = getTextAttributes(font: font, color: strokeColor)
        context.setStrokeColor(strokeColor.cgColor)
        nsText.draw(at: drawPoint, withAttributes: strokeAttributes)
        context.restoreGState()

        // 绘制填充
        context.setTextDrawingMode(.fill)
        let fillAttributes = getTextAttributes(font: font, color: color)
        nsText.draw(at: drawPoint, withAttributes: fillAttributes)

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }

    /// 生成缓存键
    private func generateCacheKey(
        text: String,
        font: UIFont,
        color: UIColor,
        strokeColor: UIColor,
        alpha: CGFloat,
        strokeWidth: CGFloat
    ) -> String {
        return "\(text)_\(font.pointSize)_\(color.hexString)_\(strokeColor.hexString)_\(Int(alpha * 100))_\(Int(strokeWidth))"
    }

    /// 缓存渲染图像
    private func cacheRenderedImage(image: UIImage, key: String, strategy: DanmuCacheStrategy) {
        let cost = Int(image.size.width * image.size.height * 4) // 估算内存占用

        switch strategy {
        case .frequent:
            // 高频文本，高优先级缓存
            imageCache.setObject(image, forKey: key as NSString, cost: cost * 2)
        case .normal:
            // 普通缓存
            imageCache.setObject(image, forKey: key as NSString, cost: cost)
        case .temporary:
            // 不缓存
            break
        }
    }

    /// 配置缓存容量
    private func setupCacheConfiguration() {
        // 根据设备内存动态配置缓存大小
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let cacheMemoryLimit = min(totalMemory / 200, 50 * 1024 * 1024) // 最多50MB或0.5%内存

        imageCache.totalCostLimit = Int(cacheMemoryLimit)
        imageCache.countLimit = 200 // 最多缓存200个图像

        Logger.info("弹幕文字渲染缓存配置: 内存限制 \(cacheMemoryLimit / 1024 / 1024)MB, 数量限制 200")
    }

    /// 设置内存管理
    private func setupMemoryManagement() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    /// 调度常用文本预渲染
    private func scheduleCommonTextPrerendering() {
        // 延迟5秒后预渲染，避免影响启动性能
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.prerenderCommonTexts()
        }
    }

    @objc private func handleMemoryWarning() {
        Logger.warn("收到内存警告，清理弹幕文字渲染缓存")

        lock.lock()
        // 清理一半缓存
        let originalCount = imageCache.countLimit
        imageCache.countLimit = originalCount / 2

        // 清理辅助缓存
        if attributesCache.count > 100 {
            attributesCache.removeAll()
        }
        if sizeCache.count > 200 {
            sizeCache.removeAll()
        }
        lock.unlock()

        // 恢复缓存限制
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 10.0) { [weak self] in
            self?.imageCache.countLimit = originalCount
        }

        Logger.info("内存警告处理完成，临时减少缓存容量")
    }

    /// 缓存命中计数
    private func incrementCacheHit() {
        lock.lock()
        cacheHitCount += 1
        lock.unlock()
    }

    /// 缓存未命中计数
    private func incrementCacheMiss() {
        lock.lock()
        cacheMissCount += 1
        lock.unlock()
    }
}

// MARK: - UIColor Extension

private extension UIColor {
    /// 获取颜色的十六进制字符串表示
    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return String(format: "%02X%02X%02X%02X",
                      Int(red * 255),
                      Int(green * 255),
                      Int(blue * 255),
                      Int(alpha * 255))
    }
}
