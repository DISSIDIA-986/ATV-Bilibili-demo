//
//  DanmakuTextCell.swift
//  DanmakuKit_Example
//
//  Created by Q YiZhong on 2020/8/29.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit

class DanmakuTextCell: DanmakuCell {
    required init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func willDisplay() {}

    override func displaying(_ context: CGContext, _ size: CGSize, _ isCancelled: Bool) {
        guard let model = model as? DanmakuTextCellModel else { return }

        let startTime = CFAbsoluteTimeGetCurrent()
        let strokeColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: CGFloat(Settings.danmuStrokeAlpha.rawValue))

        if let cachedImage = DanmuTextRenderer.shared.getRenderedText(
            text: model.text,
            font: model.font,
            color: model.color,
            strokeColor: strokeColor,
            alpha: CGFloat(Settings.danmuAlpha.rawValue),
            strokeWidth: CGFloat(Settings.danmuStrokeWidth.rawValue)
        ) {
            // 使用缓存的预渲染图像，性能最优
            context.draw(cachedImage.cgImage!, in: CGRect(origin: .zero, size: size))
            DanmuPerformanceMonitor.shared.recordRenderEvent(isFromCache: true)
            return
        }

        // 回退到原始渲染方式（保持兼容性）
        performDirectRendering(context, size, model, strokeColor)

        let renderTime = CFAbsoluteTimeGetCurrent() - startTime
        DanmuPerformanceMonitor.shared.recordRenderEvent(isFromCache: false, renderTime: renderTime)
    }

    /// 直接渲染方式（原始实现，作为回退方案）
    private func performDirectRendering(_ context: CGContext, _ size: CGSize, _ model: DanmakuTextCellModel, _ strokeColor: UIColor) {
        let text = NSString(string: model.text)
        context.setAlpha(CGFloat(Settings.danmuAlpha.rawValue))
        context.setLineWidth(CGFloat(Settings.danmuStrokeWidth.rawValue))
        context.setLineJoin(.round)
        context.saveGState()
        context.setTextDrawingMode(.stroke)

        // 使用缓存的属性获取方法
        let strokeAttributes = DanmuTextRenderer.shared.getTextAttributes(font: model.font, color: strokeColor)
        context.setStrokeColor(strokeColor.cgColor)
        text.draw(at: .zero, withAttributes: strokeAttributes)
        context.restoreGState()

        let fillAttributes = DanmuTextRenderer.shared.getTextAttributes(font: model.font, color: model.color)
        context.setTextDrawingMode(.fill)
        context.setStrokeColor(UIColor.white.cgColor)
        text.draw(at: .zero, withAttributes: fillAttributes)
    }

    override func didDisplay(_ finished: Bool) {}
}
