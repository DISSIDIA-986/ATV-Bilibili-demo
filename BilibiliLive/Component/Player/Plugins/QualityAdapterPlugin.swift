//
//  QualityAdapterPlugin.swift
//  BilibiliLive
//
//  Created by Claude on 2025/7/12.
//

import AVKit
import CocoaLumberjackSwift
import Combine
import Foundation
import UIKit

/// 画质自动切换插件
class QualityAdapterPlugin: NSObject, CommonPlayerPlugin {
    // MARK: - Types

    private struct QualityLevel {
        let quality: MediaQualityEnum
        let minBandwidth: Double // Mbps
        let description: String

        static let levels: [QualityLevel] = [
            QualityLevel(quality: .quality_1080p, minBandwidth: 5.0, description: "1080P"),
            QualityLevel(quality: .quality_2160p, minBandwidth: 25.0, description: "4K"),
            QualityLevel(quality: .quality_hdr_dolby, minBandwidth: 50.0, description: "杜比视界"),
        ]
    }

    private struct AdaptationState {
        var currentQuality: MediaQualityEnum
        var targetQuality: MediaQualityEnum?
        var lastAdaptationTime: Date
        var consecutiveStableChecks: Int
        var isAdapting: Bool
        var adaptationHistory: [Date]

        init(initialQuality: MediaQualityEnum) {
            currentQuality = initialQuality
            targetQuality = nil
            lastAdaptationTime = Date()
            consecutiveStableChecks = 0
            isAdapting = false
            adaptationHistory = []
        }
    }

    // MARK: - Properties

    private weak var player: AVPlayer?
    private weak var playerVC: AVPlayerViewController?
    private var networkDetector = NetworkQualityDetector.shared
    private var cancellables = Set<AnyCancellable>()

    private var adaptationState: AdaptationState
    private var isEnabled = Settings.enableQualityAdapter
    private var adaptationTimer: Timer?

    private let adaptationInterval: TimeInterval = 10.0 // 每10秒检测一次
    private let stabilityThreshold = 3 // 需要连续3次稳定才考虑调整
    private let minimumAdaptationInterval: TimeInterval = 30.0 // 最小调整间隔
    private let maxAdaptationsPerHour = 10 // 每小时最多调整次数

    // UI Components
    private var overlayView: UIView?
    private var qualityLabel: UILabel?
    private var adaptationIndicator: UIActivityIndicatorView?

    // MARK: - Initialization

    override init() {
        adaptationState = AdaptationState(initialQuality: Settings.mediaQuality)
        super.init()
        setupNetworkMonitoring()
    }

    deinit {
        adaptationTimer?.invalidate()
        cancellables.removeAll()
    }

    // MARK: - Network Monitoring Setup

    private func setupNetworkMonitoring() {
        networkDetector.startMonitoring()

        // 监听网络质量变化
        networkDetector.$currentQuality
            .receive(on: DispatchQueue.main)
            .sink { [weak self] quality in
                self?.handleNetworkQualityChange(quality)
            }
            .store(in: &cancellables)

        // 监听设置变化
        NotificationCenter.default.publisher(for: .init("QualityAdapterSettingsChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isEnabled = Settings.enableQualityAdapter
                self?.updateAdaptationBehavior()
            }
            .store(in: &cancellables)
    }

    // MARK: - CommonPlayerPlugin Implementation

    func addViewToPlayerOverlay(container: UIView) {
        guard isEnabled else { return }
        setupOverlayUI(in: container)
    }

    func addMenuItems(current: inout [UIMenuElement]) -> [UIMenuElement] {
        guard isEnabled else { return [] }

        let adaptiveToggle = UIAction(
            title: "自动画质调整",
            image: UIImage(systemName: "gearshape.2"),
            state: Settings.enableQualityAdapter ? .on : .off
        ) { _ in
            Settings.enableQualityAdapter.toggle()
            NotificationCenter.default.post(name: .init("QualityAdapterSettingsChanged"), object: nil)
        }

        let currentQualityInfo = UIAction(
            title: "当前画质: \(adaptationState.currentQuality.desp)",
            image: UIImage(systemName: "tv")
        ) { _ in }

        let networkInfo = UIAction(
            title: "网络状态: \(networkDetector.currentQuality.description)",
            image: UIImage(systemName: "wifi")
        ) { _ in }

        return [
            UIMenu(title: "画质自适应", image: UIImage(systemName: "opticaldisc"), children: [
                adaptiveToggle,
                currentQualityInfo,
                networkInfo,
            ]),
        ]
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
    }

    func playerDidChange(player: AVPlayer) {
        self.player = player
        startAdaptationMonitoring()
    }

    func playerDidStart(player: AVPlayer) {
        updateQualityDisplay()
        DDLogInfo("画质自适应插件：播放开始，当前画质: \(adaptationState.currentQuality.desp)")
    }

    func playerDidPause(player: AVPlayer) {
        pauseAdaptationMonitoring()
    }

    func playerDidEnd(player: AVPlayer) {
        stopAdaptationMonitoring()
    }

    func playerDidCleanUp(player: AVPlayer) {
        stopAdaptationMonitoring()
        self.player = nil
    }

    // MARK: - Adaptation Logic

    private func startAdaptationMonitoring() {
        guard isEnabled, player != nil else { return }

        adaptationTimer?.invalidate()
        adaptationTimer = Timer.scheduledTimer(withTimeInterval: adaptationInterval, repeats: true) { [weak self] _ in
            self?.evaluateQualityAdaptation()
        }

        DDLogInfo("画质自适应监控已启动")
    }

    private func pauseAdaptationMonitoring() {
        // 暂停时不停止timer，但不执行adaptations
    }

    private func stopAdaptationMonitoring() {
        adaptationTimer?.invalidate()
        adaptationTimer = nil
        DDLogInfo("画质自适应监控已停止")
    }

    private func updateAdaptationBehavior() {
        if isEnabled {
            if player != nil {
                startAdaptationMonitoring()
            }
        } else {
            stopAdaptationMonitoring()
        }
        updateOverlayVisibility()
    }

    private func handleNetworkQualityChange(_ quality: NetworkQualityLevel) {
        DDLogDebug("网络质量变化: \(quality.description)")

        // 如果网络质量发生重大变化，重置稳定性计数
        adaptationState.consecutiveStableChecks = 0
    }

    private func evaluateQualityAdaptation() {
        guard isEnabled,
              let player = player,
              player.timeControlStatus == .playing,
              !adaptationState.isAdapting else { return }

        // 检查是否在最小调整间隔内
        let timeSinceLastAdaptation = Date().timeIntervalSince(adaptationState.lastAdaptationTime)
        guard timeSinceLastAdaptation >= minimumAdaptationInterval else {
            DDLogDebug("画质调整间隔太短，跳过: \(Int(timeSinceLastAdaptation))s")
            return
        }

        // 检查每小时调整次数限制
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let recentAdaptations = adaptationState.adaptationHistory.filter { $0 > oneHourAgo }
        guard recentAdaptations.count < maxAdaptationsPerHour else {
            DDLogDebug("达到每小时最大调整次数限制: \(recentAdaptations.count)")
            return
        }

        let networkQuality = networkDetector.currentQuality
        let networkMetrics = networkDetector.metrics

        guard let metrics = networkMetrics else {
            DDLogDebug("网络指标不可用，跳过画质调整")
            return
        }

        let recommendedQuality = determineOptimalQuality(
            networkQuality: networkQuality,
            metrics: metrics,
            currentQuality: adaptationState.currentQuality
        )

        if recommendedQuality != adaptationState.currentQuality {
            // 需要调整画质
            adaptationState.consecutiveStableChecks = 0
            if adaptationState.targetQuality != recommendedQuality {
                adaptationState.targetQuality = recommendedQuality
                DDLogInfo("检测到需要调整画质: \(adaptationState.currentQuality.desp) → \(recommendedQuality.desp)")
            }
        } else {
            // 当前画质合适
            adaptationState.consecutiveStableChecks += 1

            // 如果之前有目标画质但现在稳定，清除目标
            if adaptationState.targetQuality != nil {
                adaptationState.targetQuality = nil
                DDLogDebug("画质已稳定，清除调整目标")
            }
        }

        // 如果连续稳定且有目标画质，执行调整
        if let targetQuality = adaptationState.targetQuality,
           adaptationState.consecutiveStableChecks >= stabilityThreshold
        {
            performQualityAdaptation(to: targetQuality)
        }
    }

    private func determineOptimalQuality(
        networkQuality: NetworkQualityLevel,
        metrics: NetworkQualityMetrics,
        currentQuality: MediaQualityEnum
    ) -> MediaQualityEnum {
        let bandwidth = metrics.bandwidth
        let latency = metrics.latency
        let packetLoss = metrics.packetLoss

        // 根据网络条件确定最适合的画质等级
        var optimalQuality: MediaQualityEnum

        // 基于带宽的初始推荐
        if bandwidth >= 50.0 && latency < 100 && packetLoss < 0.01 {
            optimalQuality = .quality_hdr_dolby // 杜比视界
        } else if bandwidth >= 25.0 && latency < 150 && packetLoss < 0.03 {
            optimalQuality = .quality_2160p // 4K
        } else {
            optimalQuality = .quality_1080p // 1080P
        }

        // 网络质量额外限制
        switch networkQuality {
        case .poor:
            optimalQuality = .quality_1080p
        case .fair:
            optimalQuality = min(optimalQuality, .quality_2160p)
        case .good, .excellent, .unknown:
            break // 不限制
        }

        // 考虑当前画质的稳定性 - 避免频繁跳跃
        let currentIndex = MediaQualityEnum.allCases.firstIndex(of: currentQuality) ?? 0
        let optimalIndex = MediaQualityEnum.allCases.firstIndex(of: optimalQuality) ?? 0

        // 如果差距只有1级，需要更强的理由才调整
        if abs(currentIndex - optimalIndex) == 1 {
            if optimalIndex > currentIndex {
                // 升级：需要更充足的带宽
                if let qualityLevel = QualityLevel.levels.first(where: { $0.quality == optimalQuality }) {
                    let requiredBandwidth = qualityLevel.minBandwidth * 1.5
                    if bandwidth < requiredBandwidth {
                        optimalQuality = currentQuality
                    }
                }
            } else {
                // 降级：需要明显的网络问题
                if packetLoss < 0.05 && latency < 250 {
                    optimalQuality = currentQuality
                }
            }
        }

        return optimalQuality
    }

    private func performQualityAdaptation(to targetQuality: MediaQualityEnum) {
        guard let player = player,
              targetQuality != adaptationState.currentQuality else { return }

        adaptationState.isAdapting = true
        showAdaptationIndicator()

        DDLogInfo("开始执行画质调整: \(adaptationState.currentQuality.desp) → \(targetQuality.desp)")

        // 保存当前播放位置
        let currentTime = player.currentTime()

        Task { @MainActor in
            // 更新设置
            Settings.mediaQuality = targetQuality

            // 触发重新加载播放源
            NotificationCenter.default.post(
                name: .init("QualityAdaptationRequested"),
                object: nil,
                userInfo: [
                    "targetQuality": targetQuality,
                    "currentTime": currentTime,
                ]
            )

            // 更新状态
            adaptationState.currentQuality = targetQuality
            adaptationState.targetQuality = nil
            adaptationState.lastAdaptationTime = Date()
            adaptationState.consecutiveStableChecks = 0
            adaptationState.adaptationHistory.append(Date())

            // 清理历史记录（保留最近1小时）
            let oneHourAgo = Date().addingTimeInterval(-3600)
            adaptationState.adaptationHistory = adaptationState.adaptationHistory.filter { $0 > oneHourAgo }

            updateQualityDisplay()

            // 短暂延迟后隐藏指示器
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.hideAdaptationIndicator()
                self.adaptationState.isAdapting = false
            }

            DDLogInfo("画质调整完成: \(targetQuality.desp)")
        }
    }

    // MARK: - UI Components

    private func setupOverlayUI(in container: UIView) {
        overlayView = UIView()
        overlayView?.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        overlayView?.layer.cornerRadius = 8
        overlayView?.clipsToBounds = true
        overlayView?.isHidden = !isEnabled

        qualityLabel = UILabel()
        qualityLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        qualityLabel?.textColor = .white
        qualityLabel?.textAlignment = .center

        adaptationIndicator = UIActivityIndicatorView(style: .medium)
        adaptationIndicator?.color = .white
        adaptationIndicator?.isHidden = true

        guard let overlayView = overlayView,
              let qualityLabel = qualityLabel,
              let adaptationIndicator = adaptationIndicator else { return }

        container.addSubview(overlayView)
        overlayView.addSubview(qualityLabel)
        overlayView.addSubview(adaptationIndicator)

        overlayView.translatesAutoresizingMaskIntoConstraints = false
        qualityLabel.translatesAutoresizingMaskIntoConstraints = false
        adaptationIndicator.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 20),
            overlayView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            overlayView.widthAnchor.constraint(equalToConstant: 120),
            overlayView.heightAnchor.constraint(equalToConstant: 40),

            qualityLabel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 8),
            qualityLabel.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor),

            adaptationIndicator.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -8),
            adaptationIndicator.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor),
            adaptationIndicator.leadingAnchor.constraint(equalTo: qualityLabel.trailingAnchor, constant: 4),
        ])

        updateQualityDisplay()
    }

    private func updateOverlayVisibility() {
        overlayView?.isHidden = !isEnabled
    }

    private func updateQualityDisplay() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let displayText = "自动 \(self.adaptationState.currentQuality.desp)"
            self.qualityLabel?.text = displayText
        }
    }

    private func showAdaptationIndicator() {
        DispatchQueue.main.async { [weak self] in
            self?.adaptationIndicator?.isHidden = false
            self?.adaptationIndicator?.startAnimating()
        }
    }

    private func hideAdaptationIndicator() {
        DispatchQueue.main.async { [weak self] in
            self?.adaptationIndicator?.stopAnimating()
            self?.adaptationIndicator?.isHidden = true
        }
    }
}

// MARK: - Settings Extension

extension Settings {
    @UserDefault("enableQualityAdapter", defaultValue: true)
    static var enableQualityAdapter: Bool
}

// MARK: - MediaQualityEnum Extension

extension MediaQualityEnum: Comparable {
    public static func < (lhs: MediaQualityEnum, rhs: MediaQualityEnum) -> Bool {
        return lhs.qn < rhs.qn
    }
}
