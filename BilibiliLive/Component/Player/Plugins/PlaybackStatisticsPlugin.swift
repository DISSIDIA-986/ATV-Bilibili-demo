//
//  PlaybackStatisticsPlugin.swift
//  BilibiliLive
//
//  Created by Claude on 2025/7/12.
//

import AVFoundation
import CocoaLumberjackSwift
import Combine
import Foundation
import UIKit

/// 播放统计插件
class PlaybackStatisticsPlugin: NSObject, CommonPlayerPlugin {
    var view: UIView? { overlayView }

    // MARK: - 统计数据

    @Published private(set) var currentSession: PlaybackSession?
    @Published private(set) var totalPlayTime: TimeInterval = 0
    @Published private(set) var totalVideos: Int = 0
    @Published private(set) var sessionsToday: Int = 0
    @Published private(set) var averagePlaybackLength: TimeInterval = 0

    // MARK: - UI 组件

    private let overlayView = PlaybackStatsOverlayView()
    private var statsViewController: PlaybackStatsViewController?

    // MARK: - 数据存储

    private var sessions: [PlaybackSession] = []
    private var playbackEvents: [PlaybackEvent] = []
    private var qualityChanges: [QualityChangeEvent] = []
    private var bufferingEvents: [BufferingEvent] = []

    // MARK: - 实时监控

    private var sessionStartTime: Date?
    private var lastPositionUpdate: Date?
    private var totalBufferingTime: TimeInterval = 0
    private var bufferingStartTime: Date?
    private var watchedDuration: TimeInterval = 0
    private var lastPosition: TimeInterval = 0

    // MARK: - 设置

    private var showRealTimeStats: Bool = true
    private var enableDetailedLogging: Bool = true
    private var autoSaveInterval: TimeInterval = 30.0

    // MARK: - Timer 和通知

    private var saveTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 生命周期

    override init() {
        super.init()
        loadStoredData()
        setupAutoSave()
        setupOverlay()
        subscribeToNotifications()
    }

    deinit {
        saveTimer?.invalidate()
        saveCurrentSession()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - CommonPlayerPlugin

    func playerDidLoad() {
        DDLogInfo("[PlaybackStats] 播放统计插件已加载")
        startNewSession()
        updateOverlay()
    }

    func playerWillStart() {
        sessionStartTime = Date()
        recordEvent(.playbackStarted)
        DDLogDebug("[PlaybackStats] 播放开始")
    }

    func playerDidPause() {
        recordEvent(.playbackPaused)
        updateWatchedDuration()
        DDLogDebug("[PlaybackStats] 播放暂停")
    }

    func playerDidResume() {
        recordEvent(.playbackResumed)
        lastPositionUpdate = Date()
        DDLogDebug("[PlaybackStats] 播放恢复")
    }

    func playerDidStop() {
        recordEvent(.playbackStopped)
        updateWatchedDuration()
        finishCurrentSession()
        DDLogInfo("[PlaybackStats] 播放停止，会话结束")
    }

    func playerDidFail(error: Error) {
        recordEvent(.playbackError(error))
        updateWatchedDuration()
        finishCurrentSession(successful: false)
        DDLogError("[PlaybackStats] 播放失败: \\(error.localizedDescription)")
    }

    func playerDidSeek(to time: TimeInterval) {
        recordEvent(.seekPerformed(from: lastPosition, to: time))
        lastPosition = time
        DDLogDebug("[PlaybackStats] 跳转到 \\(time) 秒")
    }

    func playerDidChangePlaybackPosition(_ position: TimeInterval) {
        updatePlaybackPosition(position)
    }

    // MARK: - 会话管理

    private func startNewSession() {
        let session = PlaybackSession(
            id: UUID(),
            startTime: Date(),
            endTime: nil,
            totalDuration: 0,
            watchedDuration: 0,
            bufferingTime: 0,
            qualityChanges: 0,
            seekCount: 0,
            successful: false,
            averageQuality: .quality_1080p,
            networkType: .unknown,
            deviceInfo: getDeviceInfo()
        )

        currentSession = session
        sessionStartTime = Date()
        lastPositionUpdate = Date()
        watchedDuration = 0
        lastPosition = 0
        totalBufferingTime = 0

        sessionsToday += 1
        updateOverlay()
    }

    private func finishCurrentSession(successful: Bool = true) {
        guard var session = currentSession else { return }

        session.endTime = Date()
        session.successful = successful
        session.watchedDuration = watchedDuration
        session.bufferingTime = totalBufferingTime

        if let startTime = sessionStartTime {
            session.totalDuration = Date().timeIntervalSince(startTime)
        }

        // 计算平均质量
        if !qualityChanges.isEmpty {
            let totalWeightedQuality = qualityChanges.reduce(0.0) { sum, change in
                return sum + qualityScore(for: change.newQuality) * change.duration
            }
            let totalDuration = qualityChanges.reduce(0.0) { sum, change in
                return sum + change.duration
            }
            if totalDuration > 0 {
                let averageScore = totalWeightedQuality / totalDuration
                session.averageQuality = qualityFromScore(averageScore)
            }
        }

        // 添加到历史记录
        sessions.append(session)
        currentSession = nil

        // 更新总体统计
        totalPlayTime += session.watchedDuration
        totalVideos += 1
        updateAveragePlaybackLength()
        updateOverlay()

        DDLogInfo("[PlaybackStats] 会话完成: 观看时长 \\(session.watchedDuration)s, 缓冲时长 \\(session.bufferingTime)s")
    }

    // MARK: - 事件记录

    private func recordEvent(_ event: PlaybackEventType) {
        let playbackEvent = PlaybackEvent(
            id: UUID(),
            timestamp: Date(),
            type: event,
            position: lastPosition,
            sessionId: currentSession?.id
        )

        playbackEvents.append(playbackEvent)

        // 限制事件数量
        if playbackEvents.count > 1000 {
            playbackEvents.removeFirst(200)
        }

        // 更新会话统计
        updateSessionStats(for: event)
    }

    private func updateSessionStats(for event: PlaybackEventType) {
        guard var session = currentSession else { return }

        switch event {
        case .seekPerformed:
            session.seekCount += 1
        case .qualityChanged:
            session.qualityChanges += 1
        case .bufferingStarted:
            bufferingStartTime = Date()
        case .bufferingEnded:
            if let bufferingStart = bufferingStartTime {
                let bufferingDuration = Date().timeIntervalSince(bufferingStart)
                totalBufferingTime += bufferingDuration
                session.bufferingTime = totalBufferingTime

                // 记录缓冲事件
                let bufferingEvent = BufferingEvent(
                    id: UUID(),
                    timestamp: bufferingStart,
                    duration: bufferingDuration,
                    position: lastPosition,
                    sessionId: session.id
                )
                bufferingEvents.append(bufferingEvent)
                bufferingStartTime = nil
            }
        default:
            break
        }

        currentSession = session
        updateOverlay()
    }

    // MARK: - 位置更新

    private func updateWatchedDuration() {
        // 在暂停或停止时更新观看时长
        if let lastUpdate = lastPositionUpdate {
            let timeDelta = Date().timeIntervalSince(lastUpdate)
            watchedDuration += timeDelta
            lastPositionUpdate = Date()
            currentSession?.watchedDuration = watchedDuration
            updateOverlay()
        }
    }

    private func updatePlaybackPosition(_ position: TimeInterval) {
        let now = Date()

        if let lastUpdate = lastPositionUpdate {
            let timeDelta = now.timeIntervalSince(lastUpdate)
            // 只有在正常播放时（没有快进/快退）才计算观看时长
            if abs(position - lastPosition) <= timeDelta + 1.0 {
                watchedDuration += timeDelta
            }
        }

        lastPosition = position
        lastPositionUpdate = now

        // 更新当前会话
        currentSession?.watchedDuration = watchedDuration
        updateOverlay()
    }

    // MARK: - 质量变化监控

    func recordQualityChange(from: MediaQualityEnum, to: MediaQualityEnum) {
        let qualityChange = QualityChangeEvent(
            id: UUID(),
            timestamp: Date(),
            fromQuality: from,
            newQuality: to,
            position: lastPosition,
            duration: 0, // 将在下次质量变化时更新
            sessionId: currentSession?.id
        )

        // 更新上一个质量变化的持续时间
        if let lastChange = qualityChanges.last {
            let duration = Date().timeIntervalSince(lastChange.timestamp)
            qualityChanges[qualityChanges.count - 1].duration = duration
        }

        qualityChanges.append(qualityChange)
        recordEvent(.qualityChanged(from: from, to: to))

        DDLogInfo("[PlaybackStats] 画质变化: \\(from) → \\(to)")
    }

    // MARK: - 缓冲监控

    func recordBufferingStart() {
        recordEvent(.bufferingStarted)
    }

    func recordBufferingEnd() {
        recordEvent(.bufferingEnded)
    }

    // MARK: - 数据持久化

    private func loadStoredData() {
        if let data = UserDefaults.standard.data(forKey: "PlaybackStatistics.sessions"),
           let storedSessions = try? JSONDecoder().decode([PlaybackSession].self, from: data)
        {
            sessions = storedSessions
        }

        totalPlayTime = UserDefaults.standard.double(forKey: "PlaybackStatistics.totalPlayTime")
        totalVideos = UserDefaults.standard.integer(forKey: "PlaybackStatistics.totalVideos")

        updateAveragePlaybackLength()
        updateSessionsToday()
    }

    private func saveCurrentSession() {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: "PlaybackStatistics.sessions")
            UserDefaults.standard.set(totalPlayTime, forKey: "PlaybackStatistics.totalPlayTime")
            UserDefaults.standard.set(totalVideos, forKey: "PlaybackStatistics.totalVideos")
        } catch {
            DDLogError("[PlaybackStats] 保存数据失败: \\(error)")
        }
    }

    private func setupAutoSave() {
        saveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { [weak self] _ in
            self?.saveCurrentSession()
        }
    }

    // MARK: - 统计计算

    private func updateAveragePlaybackLength() {
        if totalVideos > 0 {
            averagePlaybackLength = totalPlayTime / Double(totalVideos)
        }
    }

    private func updateSessionsToday() {
        let today = Calendar.current.startOfDay(for: Date())
        sessionsToday = sessions.filter { session in
            Calendar.current.isDate(session.startTime, inSameDayAs: today)
        }.count
    }

    // MARK: - 质量评分

    private func qualityScore(for quality: MediaQualityEnum) -> Double {
        switch quality {
        case .quality_1080p:
            return 2.0
        case .quality_2160p:
            return 3.0
        case .quality_hdr_dolby:
            return 4.0
        }
    }

    private func qualityFromScore(_ score: Double) -> MediaQualityEnum {
        if score >= 3.5 {
            return .quality_hdr_dolby
        } else if score >= 2.5 {
            return .quality_2160p
        } else {
            return .quality_1080p
        }
    }

    // MARK: - 设备信息

    private func getDeviceInfo() -> String {
        return "Apple TV" // tvOS 设备信息
    }

    // MARK: - 通知订阅

    private func subscribeToNotifications() {
        // 订阅质量变化通知
        NotificationCenter.default.publisher(for: .init("QualityAdaptationRequested"))
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let fromQuality = userInfo["fromQuality"] as? MediaQualityEnum,
                   let toQuality = userInfo["targetQuality"] as? MediaQualityEnum
                {
                    self?.recordQualityChange(from: fromQuality, to: toQuality)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 覆盖层管理

    private func setupOverlay() {
        overlayView.isHidden = !showRealTimeStats
        overlayView.configure(plugin: self)
    }

    private func updateOverlay() {
        overlayView.updateStats(
            watchedTime: watchedDuration,
            bufferingTime: totalBufferingTime,
            sessionCount: sessionsToday,
            averageLength: averagePlaybackLength
        )
    }

    func toggleStatsDisplay() {
        showRealTimeStats.toggle()
        overlayView.isHidden = !showRealTimeStats
    }

    func showDetailedStats() {
        let statsVC = PlaybackStatsViewController()
        statsVC.configure(with: self)

        guard let presentingViewController = UIApplication.shared.keyWindow?.rootViewController else {
            return
        }

        let navController = UINavigationController(rootViewController: statsVC)
        navController.modalPresentationStyle = .fullScreen
        presentingViewController.present(navController, animated: true)
    }

    // MARK: - 公共接口

    func getSessionStats() -> PlaybackSessionStats {
        let completedSessions = sessions.filter { $0.successful }
        let todaySessions = sessions.filter { session in
            Calendar.current.isDate(session.startTime, inSameDayAs: Date())
        }

        return PlaybackSessionStats(
            totalSessions: sessions.count,
            successfulSessions: completedSessions.count,
            totalPlayTime: totalPlayTime,
            averagePlayTime: averagePlaybackLength,
            sessionsToday: todaySessions.count,
            totalBufferingTime: sessions.reduce(0) { $0 + $1.bufferingTime },
            averageSeekCount: sessions.isEmpty ? 0 : sessions.reduce(0) { $0 + $1.seekCount } / sessions.count,
            qualityDistribution: getQualityDistribution(),
            recentSessions: Array(sessions.suffix(10).reversed())
        )
    }

    private func getQualityDistribution() -> [MediaQualityEnum: Double] {
        var distribution: [MediaQualityEnum: Double] = [:]
        let totalTime = sessions.reduce(0.0) { $0 + $1.watchedDuration }

        if totalTime > 0 {
            for session in sessions {
                let weight = session.watchedDuration / totalTime
                distribution[session.averageQuality, default: 0] += weight
            }
        }

        return distribution
    }

    func exportStats() -> String {
        let stats = getSessionStats()
        var export = "播放统计报告\\n"
        export += "==============\\n"
        export += "总播放次数: \\(stats.totalSessions)\\n"
        export += "成功播放次数: \\(stats.successfulSessions)\\n"
        export += "总播放时长: \\(formatDuration(stats.totalPlayTime))\\n"
        export += "平均播放时长: \\(formatDuration(stats.averagePlayTime))\\n"
        export += "今日播放次数: \\(stats.sessionsToday)\\n"
        export += "总缓冲时长: \\(formatDuration(stats.totalBufferingTime))\\n"
        export += "平均跳转次数: \\(stats.averageSeekCount)\\n"

        return export
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}
