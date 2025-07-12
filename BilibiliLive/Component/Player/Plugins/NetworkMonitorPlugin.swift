//
//  NetworkMonitorPlugin.swift
//  BilibiliLive
//
//  Created by Claude on 2025/7/12.
//

import CocoaLumberjackSwift
import Combine
import Foundation
import Network
import UIKit

/// 网络状态监控插件
class NetworkMonitorPlugin: NSObject, CommonPlayerPlugin {
    var view: UIView? { statusIndicatorView }

    // MARK: - 状态监控

    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitorPlugin", qos: .utility)
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var connectionStatus: NetworkConnectionStatus = .unknown
    @Published private(set) var networkType: NetworkType = .unknown
    @Published private(set) var isMetered: Bool = false
    @Published private(set) var bandwidth: NetworkBandwidth = .unknown
    @Published private(set) var latency: TimeInterval = 0
    @Published private(set) var packetLoss: Double = 0

    // MARK: - UI 组件

    private let statusIndicatorView = NetworkStatusIndicatorView()
    private var alertController: UIAlertController?

    // MARK: - 统计数据

    private var connectionHistory: [NetworkEvent] = []
    private var bytesReceived: Int64 = 0
    private var bytesSent: Int64 = 0
    private var requestCount: Int = 0
    private var failedRequestCount: Int = 0
    private var lastConnectionTime: Date?
    private var connectionDuration: TimeInterval = 0

    // MARK: - 通知

    private let statusChangeNotification = "NetworkMonitorStatusChanged"
    private let metricsUpdateNotification = "NetworkMonitorMetricsUpdated"

    // MARK: - 生命周期

    override init() {
        super.init()
        setupNetworkMonitoring()
        setupStatusIndicator()
        subscribeToQualityDetector()

        // 通知系统网络状态变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - CommonPlayerPlugin

    func playerDidLoad() {
        DDLogInfo("[NetworkMonitor] 插件加载完成")
        startMonitoring()
        updateStatusIndicator()
    }

    func playerWillStart() {
        recordEvent(.playbackStarted)
        updateConnectionMetrics()
    }

    func playerDidPause() {
        recordEvent(.playbackPaused)
    }

    func playerDidStop() {
        recordEvent(.playbackStopped)
        updateConnectionDuration()
    }

    func playerDidFail(error: Error) {
        recordEvent(.playbackFailed(error))
        failedRequestCount += 1
    }

    // MARK: - 网络监控设置

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handlePathUpdate(path)
            }
        }
    }

    private func handlePathUpdate(_ path: NWPath) {
        let newStatus: NetworkConnectionStatus
        let newType: NetworkType

        switch path.status {
        case .satisfied:
            newStatus = .connected
        case .unsatisfied:
            newStatus = .disconnected
        case .requiresConnection:
            newStatus = .connecting
        @unknown default:
            newStatus = .unknown
        }

        // 检测网络类型
        if path.usesInterfaceType(.wifi) {
            newType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            newType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            newType = .ethernet
        } else {
            newType = .unknown
        }

        let wasConnected = connectionStatus == .connected
        let isNowConnected = newStatus == .connected

        connectionStatus = newStatus
        networkType = newType
        isMetered = path.isExpensive

        // 记录连接状态变化
        if !wasConnected && isNowConnected {
            recordEvent(.connected(newType))
            lastConnectionTime = Date()
            DDLogInfo("[NetworkMonitor] 网络连接已建立: \(newType)")
        } else if wasConnected && !isNowConnected {
            recordEvent(.disconnected)
            updateConnectionDuration()
            DDLogWarn("[NetworkMonitor] 网络连接已断开")
        }

        updateStatusIndicator()
        postStatusChangeNotification()

        // 网络质量检测
        if isNowConnected {
            triggerQualityDetection()
        }
    }

    private func subscribeToQualityDetector() {
        NetworkQualityDetector.shared.$currentQuality
            .receive(on: DispatchQueue.main)
            .sink { [weak self] quality in
                self?.updateNetworkQuality(quality)
            }
            .store(in: &cancellables)

        NetworkQualityDetector.shared.$metrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                if let metrics = metrics {
                    self?.updateMetrics(metrics)
                }
            }
            .store(in: &cancellables)
    }

    private func updateNetworkQuality(_ quality: NetworkQualityLevel) {
        statusIndicatorView.updateQuality(quality)

        // 根据网络质量更新带宽估算
        switch quality {
        case .excellent:
            bandwidth = .high
        case .good:
            bandwidth = .medium
        case .fair:
            bandwidth = .low
        case .poor:
            bandwidth = .veryLow
        case .unknown:
            bandwidth = .unknown
        }

        postMetricsUpdateNotification()
    }

    private func updateMetrics(_ metrics: NetworkQualityMetrics) {
        latency = metrics.latency
        packetLoss = metrics.packetLoss
        statusIndicatorView.updateMetrics(latency: latency, packetLoss: packetLoss)
        postMetricsUpdateNotification()
    }

    // MARK: - 状态指示器

    private func setupStatusIndicator() {
        statusIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        statusIndicatorView.alpha = 0.8

        // 点击状态指示器显示详细信息
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showNetworkDetails))
        statusIndicatorView.addGestureRecognizer(tapGesture)
        statusIndicatorView.isUserInteractionEnabled = true
    }

    private func updateStatusIndicator() {
        statusIndicatorView.updateStatus(
            connectionStatus: connectionStatus,
            networkType: networkType,
            isMetered: isMetered
        )
    }

    @objc private func showNetworkDetails() {
        let detailsVC = NetworkDetailsViewController()
        detailsVC.configure(with: getNetworkStatistics())

        guard let presentingViewController = UIApplication.shared.keyWindow?.rootViewController else {
            return
        }

        let navController = UINavigationController(rootViewController: detailsVC)
        navController.modalPresentationStyle = .fullScreen
        presentingViewController.present(navController, animated: true)
    }

    // MARK: - 监控控制

    func startMonitoring() {
        networkMonitor.start(queue: monitorQueue)
        NetworkQualityDetector.shared.startMonitoring()
        DDLogInfo("[NetworkMonitor] 开始网络监控")
    }

    func stopMonitoring() {
        networkMonitor.cancel()
        NetworkQualityDetector.shared.stopMonitoring()
        DDLogInfo("[NetworkMonitor] 停止网络监控")
    }

    private func triggerQualityDetection() {
        Task {
            await NetworkQualityDetector.shared.performQualityDetection()
        }
    }

    // MARK: - 事件记录

    private func recordEvent(_ event: NetworkEvent) {
        connectionHistory.append(event)

        // 限制历史记录数量
        if connectionHistory.count > 100 {
            connectionHistory.removeFirst()
        }

        DDLogDebug("[NetworkMonitor] 记录网络事件: \(event)")
    }

    private func updateConnectionMetrics() {
        requestCount += 1
    }

    private func updateConnectionDuration() {
        if let lastConnectionTime = lastConnectionTime {
            connectionDuration += Date().timeIntervalSince(lastConnectionTime)
            self.lastConnectionTime = nil
        }
    }

    // MARK: - 通知

    private func postStatusChangeNotification() {
        NotificationCenter.default.post(
            name: NSNotification.Name(statusChangeNotification),
            object: self,
            userInfo: [
                "connectionStatus": connectionStatus,
                "networkType": networkType,
                "isMetered": isMetered,
            ]
        )
    }

    private func postMetricsUpdateNotification() {
        NotificationCenter.default.post(
            name: NSNotification.Name(metricsUpdateNotification),
            object: self,
            userInfo: [
                "bandwidth": bandwidth,
                "latency": latency,
                "packetLoss": packetLoss,
            ]
        )
    }

    @objc private func applicationDidBecomeActive() {
        triggerQualityDetection()
    }

    // MARK: - 统计信息

    func getNetworkStatistics() -> NetworkStatistics {
        return NetworkStatistics(
            connectionStatus: connectionStatus,
            networkType: networkType,
            isMetered: isMetered,
            bandwidth: bandwidth,
            latency: latency,
            packetLoss: packetLoss,
            connectionHistory: connectionHistory,
            bytesReceived: bytesReceived,
            bytesSent: bytesSent,
            requestCount: requestCount,
            failedRequestCount: failedRequestCount,
            connectionDuration: connectionDuration,
            qualityLevel: NetworkQualityDetector.shared.currentQuality
        )
    }

    func getConnectionSuccessRate() -> Double {
        guard requestCount > 0 else { return 0.0 }
        return Double(requestCount - failedRequestCount) / Double(requestCount)
    }

    func getAverageLatency() -> TimeInterval {
        return latency
    }

    func isRecommendedForQuality(_ quality: MediaQualityEnum) -> Bool {
        switch bandwidth {
        case .veryLow:
            return quality == .quality_1080p // 低带宽只推荐1080p
        case .low:
            return quality != .quality_hdr_dolby // 中低带宽不推荐HDR
        case .medium:
            return quality != .quality_hdr_dolby // 中等带宽不推荐HDR
        case .high:
            return true // 高带宽支持所有质量
        case .unknown:
            return quality == .quality_1080p // 未知带宽使用1080p
        }
    }
}

// MARK: - 数据模型

enum NetworkConnectionStatus: String, CaseIterable {
    case connected = "已连接"
    case disconnected = "已断开"
    case connecting = "连接中"
    case unknown = "未知"

    var icon: String {
        switch self {
        case .connected: return "wifi"
        case .disconnected: return "wifi.slash"
        case .connecting: return "wifi.exclamationmark"
        case .unknown: return "questionmark.circle"
        }
    }

    var color: UIColor {
        switch self {
        case .connected: return .green
        case .disconnected: return .red
        case .connecting: return .orange
        case .unknown: return .gray
        }
    }
}

enum NetworkType: String, CaseIterable, Codable {
    case wifi = "WiFi"
    case cellular = "蜂窝网络"
    case ethernet = "以太网"
    case unknown = "未知"

    var icon: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .ethernet: return "cable.connector"
        case .unknown: return "questionmark.circle"
        }
    }
}

enum NetworkBandwidth: String, CaseIterable {
    case veryLow = "极低"
    case low = "低"
    case medium = "中等"
    case high = "高"
    case unknown = "未知"

    var color: UIColor {
        switch self {
        case .veryLow: return .red
        case .low: return .orange
        case .medium: return .yellow
        case .high: return .green
        case .unknown: return .gray
        }
    }
}

enum NetworkEvent {
    case connected(NetworkType)
    case disconnected
    case playbackStarted
    case playbackPaused
    case playbackStopped
    case playbackFailed(Error)
    case qualityChanged(from: MediaQualityEnum, to: MediaQualityEnum)

    var timestamp: Date { Date() }

    var description: String {
        switch self {
        case let .connected(type):
            return "已连接 \(type.rawValue)"
        case .disconnected:
            return "网络断开"
        case .playbackStarted:
            return "播放开始"
        case .playbackPaused:
            return "播放暂停"
        case .playbackStopped:
            return "播放停止"
        case let .playbackFailed(error):
            return "播放失败: \(error.localizedDescription)"
        case let .qualityChanged(from, to):
            return "画质切换: \(from) → \(to)"
        }
    }
}

struct NetworkStatistics {
    let connectionStatus: NetworkConnectionStatus
    let networkType: NetworkType
    let isMetered: Bool
    let bandwidth: NetworkBandwidth
    let latency: TimeInterval
    let packetLoss: Double
    let connectionHistory: [NetworkEvent]
    let bytesReceived: Int64
    let bytesSent: Int64
    let requestCount: Int
    let failedRequestCount: Int
    let connectionDuration: TimeInterval
    let qualityLevel: NetworkQualityLevel

    var successRate: Double {
        guard requestCount > 0 else { return 0.0 }
        return Double(requestCount - failedRequestCount) / Double(requestCount)
    }

    var formattedDataUsage: String {
        let totalBytes = bytesReceived + bytesSent
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }
}
