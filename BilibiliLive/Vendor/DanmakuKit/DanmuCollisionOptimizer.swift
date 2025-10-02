//
//  DanmuCollisionOptimizer.swift
//  BilibiliLive
//
//  Created by Claude on 2025/7/12.
//

import UIKit

/// 弹幕碰撞检测优化器
/// 使用空间分割和时间窗口算法，将碰撞检测从O(n)优化到O(log n)
class DanmuCollisionOptimizer {
    /// 空间网格配置
    private struct SpatialGrid {
        let cellWidth: CGFloat
        let cellHeight: CGFloat
        let cols: Int
        let rows: Int

        init(viewWidth: CGFloat, viewHeight: CGFloat, maxCellSize: CGSize) {
            // 网格大小基于最大弹幕尺寸，确保一个弹幕最多跨越4个网格
            cellWidth = max(maxCellSize.width * 0.8, 50)
            cellHeight = max(maxCellSize.height * 0.8, 20)
            cols = max(Int(ceil(viewWidth / cellWidth)), 1)
            rows = max(Int(ceil(viewHeight / cellHeight)), 1)
        }

        func getGridIndex(for point: CGPoint) -> (col: Int, row: Int) {
            let col = max(0, min(cols - 1, Int(point.x / cellWidth)))
            let row = max(0, min(rows - 1, Int(point.y / cellHeight)))
            return (col, row)
        }

        func getGridIndices(for rect: CGRect) -> [(col: Int, row: Int)] {
            // 处理无效矩形
            guard rect.width > 0 && rect.height > 0 else {
                return []
            }

            let minCol = max(0, Int(rect.minX / cellWidth))
            let maxCol = min(cols - 1, Int(rect.maxX / cellWidth))
            let minRow = max(0, Int(rect.minY / cellHeight))
            let maxRow = min(rows - 1, Int(rect.maxY / cellHeight))

            // 确保范围有效
            guard minCol <= maxCol && minRow <= maxRow else {
                return []
            }

            var indices: [(col: Int, row: Int)] = []
            for col in minCol...maxCol {
                for row in minRow...maxRow {
                    indices.append((col, row))
                }
            }
            return indices
        }
    }

    /// 弹幕时空信息
    private struct DanmuSpaceTimeInfo {
        let cell: DanmakuCell
        let startTime: CFTimeInterval
        let endTime: CFTimeInterval
        let trajectory: DanmuTrajectory
        let trackIndex: UInt

        var isActive: Bool {
            let currentTime = CACurrentMediaTime()
            return currentTime >= startTime && currentTime <= endTime
        }
    }

    /// 弹幕运动轨迹
    private struct DanmuTrajectory {
        let startFrame: CGRect
        let endFrame: CGRect
        let duration: TimeInterval
        let type: DanmakuCellType

        func frameAt(progress: Float) -> CGRect {
            let t = CGFloat(max(0, min(1, progress)))

            switch type {
            case .floating:
                // 水平移动轨迹
                let x = startFrame.origin.x + (endFrame.origin.x - startFrame.origin.x) * t
                return CGRect(x: x, y: startFrame.origin.y, width: startFrame.width, height: startFrame.height)
            case .top, .bottom:
                // 垂直固定轨迹
                return startFrame
            }
        }

        func frameAt(time: CFTimeInterval, startTime: CFTimeInterval) -> CGRect {
            let progress = duration > 0 ? Float((time - startTime) / duration) : 0
            return frameAt(progress: progress)
        }
    }

    // MARK: - Properties

    private var spatialGrid: SpatialGrid
    private var activeDanmus: [UInt: [DanmuSpaceTimeInfo]] = [:] // trackIndex -> danmus
    private var gridCells: [Int: [DanmuSpaceTimeInfo]] = [:] // gridHash -> danmus
    private let cleanupInterval: TimeInterval = 2.0
    private var lastCleanupTime: CFTimeInterval = 0

    // MARK: - Initialization

    init(viewWidth: CGFloat, viewHeight: CGFloat, maxDanmuSize: CGSize = CGSize(width: 200, height: 30)) {
        spatialGrid = SpatialGrid(viewWidth: viewWidth, viewHeight: viewHeight, maxCellSize: maxDanmuSize)
    }

    // MARK: - Public Methods

    /// 更新视图尺寸时重建空间网格
    func updateViewSize(width: CGFloat, height: CGFloat, maxDanmuSize: CGSize) {
        spatialGrid = SpatialGrid(viewWidth: width, viewHeight: height, maxCellSize: maxDanmuSize)
        rebuildSpatialIndex()
    }

    /// 添加新弹幕到优化器
    func addDanmu(_ cell: DanmakuCell, trajectory: CGRect, duration: TimeInterval, trackIndex: UInt) {
        let startTime = CACurrentMediaTime()
        let endTime = startTime + duration

        guard let model = cell.model else { return }

        let trajectoryInfo = DanmuTrajectory(
            startFrame: trajectory,
            endFrame: calculateEndFrame(from: trajectory, type: model.type, duration: duration),
            duration: duration,
            type: model.type
        )

        let spaceTimeInfo = DanmuSpaceTimeInfo(
            cell: cell,
            startTime: startTime,
            endTime: endTime,
            trajectory: trajectoryInfo,
            trackIndex: trackIndex
        )

        // 添加到轨道索引
        if activeDanmus[trackIndex] == nil {
            activeDanmus[trackIndex] = []
        }
        activeDanmus[trackIndex]?.append(spaceTimeInfo)

        // 添加到空间索引
        updateSpatialIndex(for: spaceTimeInfo, isAdding: true)

        // 定期清理过期弹幕
        performPeriodicCleanup()
    }

    /// 移除弹幕
    func removeDanmu(_ cell: DanmakuCell, trackIndex: UInt) {
        guard var trackDanmus = activeDanmus[trackIndex] else { return }

        if let index = trackDanmus.firstIndex(where: { $0.cell === cell }) {
            let spaceTimeInfo = trackDanmus[index]

            // 从空间索引中移除
            updateSpatialIndex(for: spaceTimeInfo, isAdding: false)

            // 从轨道索引中移除
            trackDanmus.remove(at: index)
            activeDanmus[trackIndex] = trackDanmus
        }
    }

    /// 优化的浮动弹幕碰撞检测
    func canShootFloating(danmu: DanmakuCellModel, trackIndex: UInt, viewWidth: CGFloat) -> Bool {
        guard let trackDanmus = activeDanmus[trackIndex], !trackDanmus.isEmpty else {
            return true
        }

        let currentTime = CACurrentMediaTime()

        // 使用时间窗口快速过滤过期弹幕
        let activeInTrack = trackDanmus.filter { $0.isActive }
        guard !activeInTrack.isEmpty else { return true }

        // 计算新弹幕轨迹
        let newStartFrame = CGRect(x: viewWidth, y: 0, width: danmu.size.width, height: danmu.size.height)
        let newEndFrame = CGRect(x: -danmu.size.width, y: 0, width: danmu.size.width, height: danmu.size.height)
        let newTrajectory = DanmuTrajectory(
            startFrame: newStartFrame,
            endFrame: newEndFrame,
            duration: danmu.displayTime,
            type: .floating
        )

        // 使用优化的碰撞预测算法
        return !willCollideWithExisting(newTrajectory: newTrajectory,
                                        currentTime: currentTime,
                                        existingDanmus: activeInTrack)
    }

    /// 优化的同步弹幕碰撞检测
    func canSyncFloating(danmu: DanmakuCellModel, progress: Float, trackIndex: UInt, viewWidth: CGFloat) -> Bool {
        guard let trackDanmus = activeDanmus[trackIndex] else { return true }

        let currentTime = CACurrentMediaTime()
        let totalWidth = viewWidth + danmu.size.width
        let syncX = viewWidth - totalWidth * CGFloat(progress)
        let syncFrame = CGRect(x: syncX, y: 0, width: danmu.size.width, height: danmu.size.height)

        // 使用空间网格快速查找可能相交的弹幕
        let gridIndices = spatialGrid.getGridIndices(for: syncFrame)
        var candidateCollisions: Set<ObjectIdentifier> = []

        for (col, row) in gridIndices {
            let gridHash = col * spatialGrid.rows + row
            if let gridDanmus = gridCells[gridHash] {
                for danmuInfo in gridDanmus {
                    if danmuInfo.trackIndex == trackIndex && danmuInfo.isActive {
                        candidateCollisions.insert(ObjectIdentifier(danmuInfo.cell))
                    }
                }
            }
        }

        // 精确碰撞检测
        for danmuInfo in trackDanmus {
            guard danmuInfo.isActive && candidateCollisions.contains(ObjectIdentifier(danmuInfo.cell)) else {
                continue
            }

            let currentFrame = danmuInfo.trajectory.frameAt(time: currentTime, startTime: danmuInfo.startTime)
            if currentFrame.intersects(syncFrame) {
                return false
            }
        }

        return true
    }

    /// 清理所有数据
    func clear() {
        activeDanmus.removeAll()
        gridCells.removeAll()
        lastCleanupTime = 0
    }

    /// 获取性能统计信息
    func getPerformanceStats() -> (activeDanmus: Int, gridCells: Int, memoryKB: Int) {
        let totalDanmus = activeDanmus.values.reduce(0) { $0 + $1.count }
        let totalGridCells = gridCells.values.reduce(0) { $0 + $1.count }
        let estimatedMemory = (totalDanmus * 200 + totalGridCells * 50) / 1024 // 粗略估算KB

        return (activeDanmus: totalDanmus, gridCells: totalGridCells, memoryKB: estimatedMemory)
    }

    // MARK: - Private Methods

    private func calculateEndFrame(from startFrame: CGRect, type: DanmakuCellType, duration: TimeInterval) -> CGRect {
        switch type {
        case .floating:
            return CGRect(x: -startFrame.width, y: startFrame.origin.y, width: startFrame.width, height: startFrame.height)
        case .top, .bottom:
            return startFrame // 垂直弹幕位置不变
        }
    }

    private func willCollideWithExisting(newTrajectory: DanmuTrajectory, currentTime: CFTimeInterval, existingDanmus: [DanmuSpaceTimeInfo]) -> Bool {
        for existing in existingDanmus {
            if predictCollision(newTrajectory: newTrajectory,
                                newStartTime: currentTime,
                                existingTrajectory: existing.trajectory,
                                existingStartTime: existing.startTime)
            {
                return true
            }
        }
        return false
    }

    private func predictCollision(newTrajectory: DanmuTrajectory,
                                  newStartTime: CFTimeInterval,
                                  existingTrajectory: DanmuTrajectory,
                                  existingStartTime: CFTimeInterval) -> Bool
    {
        // 计算两个弹幕的相对运动
        let newSpeed = newTrajectory.duration > 0 ?
            (newTrajectory.endFrame.origin.x - newTrajectory.startFrame.origin.x) / CGFloat(newTrajectory.duration) : 0
        let existingSpeed = existingTrajectory.duration > 0 ?
            (existingTrajectory.endFrame.origin.x - existingTrajectory.startFrame.origin.x) / CGFloat(existingTrajectory.duration) : 0

        // 如果新弹幕速度不大于现有弹幕，不会追上
        if newSpeed <= existingSpeed {
            return false
        }

        // 计算追击时间和距离
        let timeDiff = newStartTime - existingStartTime
        let existingCurrentX = existingTrajectory.startFrame.origin.x + existingSpeed * CGFloat(timeDiff)
        let distanceGap = existingCurrentX - newTrajectory.startFrame.origin.x - 10 // 10像素安全距离

        if distanceGap <= 0 {
            return true // 已经重叠
        }

        let relativeSpeed = newSpeed - existingSpeed
        let collisionTime = distanceGap / relativeSpeed

        // 检查碰撞时间是否在有效范围内
        let existingEndTime = existingStartTime + existingTrajectory.duration
        let newEndTime = newStartTime + newTrajectory.duration
        let maxValidTime = min(existingEndTime, newEndTime) - newStartTime

        return collisionTime > 0 && collisionTime < maxValidTime
    }

    private func updateSpatialIndex(for spaceTimeInfo: DanmuSpaceTimeInfo, isAdding: Bool) {
        let currentTime = CACurrentMediaTime()
        let currentFrame = spaceTimeInfo.trajectory.frameAt(time: currentTime, startTime: spaceTimeInfo.startTime)
        let gridIndices = spatialGrid.getGridIndices(for: currentFrame)

        for (col, row) in gridIndices {
            let gridHash = col * spatialGrid.rows + row

            if isAdding {
                if gridCells[gridHash] == nil {
                    gridCells[gridHash] = []
                }
                gridCells[gridHash]?.append(spaceTimeInfo)
            } else {
                gridCells[gridHash]?.removeAll { ObjectIdentifier($0.cell) == ObjectIdentifier(spaceTimeInfo.cell) }
                if gridCells[gridHash]?.isEmpty == true {
                    gridCells.removeValue(forKey: gridHash)
                }
            }
        }
    }

    private func rebuildSpatialIndex() {
        gridCells.removeAll()

        for trackDanmus in activeDanmus.values {
            for spaceTimeInfo in trackDanmus {
                if spaceTimeInfo.isActive {
                    updateSpatialIndex(for: spaceTimeInfo, isAdding: true)
                }
            }
        }
    }

    private func performPeriodicCleanup() {
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastCleanupTime > cleanupInterval else { return }

        // 清理过期弹幕
        for (trackIndex, var trackDanmus) in activeDanmus {
            let activeCount = trackDanmus.count
            trackDanmus.removeAll { !$0.isActive }

            if trackDanmus.isEmpty {
                activeDanmus.removeValue(forKey: trackIndex)
            } else if trackDanmus.count != activeCount {
                activeDanmus[trackIndex] = trackDanmus
            }
        }

        // 重建空间索引（清理过期数据）
        rebuildSpatialIndex()

        lastCleanupTime = currentTime
    }
}

// MARK: - Integration Extensions

extension DanmakuFloatingTrack {
    /// 使用碰撞优化器的canShoot实现
    func optimizedCanShoot(danmaku: DanmakuCellModel, optimizer: DanmuCollisionOptimizer, viewWidth: CGFloat) -> Bool {
        guard !isOverlap else { return true }
        return optimizer.canShootFloating(danmu: danmaku, trackIndex: index, viewWidth: viewWidth)
    }

    /// 使用碰撞优化器的canSync实现
    func optimizedCanSync(danmaku: DanmakuCellModel, at progress: Float, optimizer: DanmuCollisionOptimizer, viewWidth: CGFloat) -> Bool {
        return optimizer.canSyncFloating(danmu: danmaku, progress: progress, trackIndex: index, viewWidth: viewWidth)
    }
}
