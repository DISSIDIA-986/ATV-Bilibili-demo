//
//  DanmakuTrackOptimized.swift
//  BilibiliLive
//
//  Created by Claude on 2025/7/12.
//

import UIKit

/// 优化版浮动弹幕轨道
/// 集成碰撞检测优化器，提供O(log n)复杂度的碰撞检测
class DanmakuFloatingTrackOptimized: DanmakuFloatingTrack {
    // MARK: - Properties

    private weak var optimizer: DanmuCollisionOptimizer?
    private var isOptimizationEnabled: Bool = true
    private weak var danmakuView: UIView?

    // MARK: - Initialization

    required init(view: UIView) {
        super.init(view: view)
        danmakuView = view
    }

    /// 设置碰撞优化器
    func setCollisionOptimizer(_ optimizer: DanmuCollisionOptimizer?) {
        self.optimizer = optimizer
    }

    /// 启用/禁用优化
    func setOptimizationEnabled(_ enabled: Bool) {
        isOptimizationEnabled = enabled
    }

    // MARK: - Optimized Methods

    override func shoot(danmaku: DanmakuCell) {
        // 调用父类方法处理动画
        super.shoot(danmaku: danmaku)

        // 通知优化器添加弹幕
        if isOptimizationEnabled, let model = danmaku.model, let view = danmakuView {
            let trajectory = CGRect(
                x: view.bounds.width + danmaku.bounds.width / 2.0,
                y: positionY - danmaku.bounds.height / 2.0,
                width: danmaku.bounds.width,
                height: danmaku.bounds.height
            )

            optimizer?.addDanmu(danmaku, trajectory: trajectory, duration: model.displayTime, trackIndex: index)
        }
    }

    override func canShoot(danmaku: DanmakuCellModel) -> Bool {
        guard isOptimizationEnabled, let optimizer = optimizer, let view = danmakuView else {
            // 回退到原始算法
            return super.canShoot(danmaku: danmaku)
        }

        guard !isOverlap else { return true }

        // 使用优化算法
        return optimizer.canShootFloating(danmu: danmaku, trackIndex: index, viewWidth: view.bounds.width)
    }

    override func canSync(_ danmaku: DanmakuCellModel, at progress: Float) -> Bool {
        guard isOptimizationEnabled, let optimizer = optimizer, let view = danmakuView else {
            // 回退到原始算法
            return super.canSync(danmaku, at: progress)
        }

        // 使用优化算法
        return optimizer.canSyncFloating(danmu: danmaku, progress: progress, trackIndex: index, viewWidth: view.bounds.width)
    }

    // MARK: - Performance Monitoring

    /// 获取轨道性能统计
    func getPerformanceStats() -> (cellCount: Int, isOptimized: Bool) {
        return (cellCount: danmakuCount, isOptimized: isOptimizationEnabled && optimizer != nil)
    }
}

/// 优化版垂直弹幕轨道
class DanmakuVerticalTrackOptimized: DanmakuVerticalTrack {
    // MARK: - Properties

    private weak var optimizer: DanmuCollisionOptimizer?
    private var isOptimizationEnabled: Bool = true
    private weak var danmakuView: UIView?

    // MARK: - Initialization

    required init(view: UIView) {
        super.init(view: view)
        danmakuView = view
    }

    /// 设置碰撞优化器
    func setCollisionOptimizer(_ optimizer: DanmuCollisionOptimizer?) {
        self.optimizer = optimizer
    }

    /// 启用/禁用优化
    func setOptimizationEnabled(_ enabled: Bool) {
        isOptimizationEnabled = enabled
    }

    // MARK: - Overrides with Cleanup Notification

    override func shoot(danmaku: DanmakuCell) {
        super.shoot(danmaku: danmaku)

        // 垂直弹幕也需要在动画结束时从优化器中移除
        if isOptimizationEnabled, let model = danmaku.model, let view = danmakuView {
            let trajectory = CGRect(
                x: view.bounds.width / 2.0 - danmaku.bounds.width / 2.0,
                y: positionY - danmaku.bounds.height / 2.0,
                width: danmaku.bounds.width,
                height: danmaku.bounds.height
            )

            optimizer?.addDanmu(danmaku, trajectory: trajectory, duration: model.displayTime, trackIndex: index)
        }
    }

    /// 获取轨道性能统计
    func getPerformanceStats() -> (cellCount: Int, isOptimized: Bool) {
        return (cellCount: danmakuCount, isOptimized: isOptimizationEnabled && optimizer != nil)
    }
}

// MARK: - Track Factory

/// 弹幕轨道工厂
class DanmakuTrackFactory {
    static func createFloatingTrack(view: UIView, optimizer: DanmuCollisionOptimizer?) -> DanmakuTrack {
        let track = DanmakuFloatingTrackOptimized(view: view)
        track.setCollisionOptimizer(optimizer)
        return track
    }

    static func createVerticalTrack(view: UIView, optimizer: DanmuCollisionOptimizer?) -> DanmakuTrack {
        let track = DanmakuVerticalTrackOptimized(view: view)
        track.setCollisionOptimizer(optimizer)
        return track
    }
}
