//
//  NetworkMonitor.swift
//  BilibiliLive
//
//  Created by Claude on 2025/1/12.
//

import Combine
import Foundation
import Network

/// 网络连接类型
enum NetworkConnectionType {
    case wifi
    case ethernet
    case cellular
    case unknown

    var displayName: String {
        switch self {
        case .wifi: return "Wi-Fi"
        case .ethernet: return "以太网"
        case .cellular: return "移动网络"
        case .unknown: return "未知"
        }
    }
}

/// 网络状态
enum NetworkStatus {
    case connected(NetworkConnectionType)
    case disconnected
    case unknown

    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

/// 网络监控器
@available(iOS 12.0, tvOS 12.0, *)
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published var status: NetworkStatus = .unknown
    @Published var currentBandwidth: Double = 0.0 // Mbps
    @Published var latency: TimeInterval = 0.0

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var speedTestTimer: Timer?

    private init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateNetworkStatus(path: path)
            }
        }
        monitor.start(queue: queue)

        // 定期进行速度和延迟测试
        startPeriodicSpeedTest()
    }

    private func stopMonitoring() {
        monitor.cancel()
        speedTestTimer?.invalidate()
    }

    private func updateNetworkStatus(path: NWPath) {
        switch path.status {
        case .satisfied:
            let connectionType = getConnectionType(path: path)
            status = .connected(connectionType)
            Logger.info("网络连接正常: \(connectionType.displayName)")
        case .unsatisfied:
            status = .disconnected
            Logger.warn("网络连接断开")
        case .requiresConnection:
            status = .unknown
            Logger.info("网络需要连接")
        @unknown default:
            status = .unknown
        }
    }

    private func getConnectionType(path: NWPath) -> NetworkConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else {
            return .unknown
        }
    }

    // MARK: - Speed and Latency Testing

    private func startPeriodicSpeedTest() {
        speedTestTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.performSpeedTest()
        }
    }

    private func performSpeedTest() {
        Task {
            await performLatencyTest()
            // 带宽测试在生产环境中应该谨慎使用，避免消耗过多流量
            // await performBandwidthTest()
        }
    }

    @MainActor
    private func performLatencyTest() async {
        let startTime = Date()

        do {
            // 使用一个小的ping请求测试延迟
            _ = try await URLSession.shared.data(from: URL(string: "https://api.bilibili.com/x/web-interface/nav")!)
            let latency = Date().timeIntervalSince(startTime)
            self.latency = latency
            Logger.debug("网络延迟: \(Int(latency * 1000))ms")
        } catch {
            Logger.warn("延迟测试失败: \(error)")
        }
    }

    // MARK: - Network Quality Assessment

    /// 评估网络质量
    func getNetworkQuality() -> BandwidthQuality {
        switch status {
        case .disconnected:
            return .poor
        case let .connected(type):
            if latency > 1.0 {
                return .poor
            } else if latency > 0.5 {
                return .fair
            } else if latency > 0.2 {
                return .good
            } else {
                return .excellent
            }
        case .unknown:
            return .unknown
        }
    }

    /// 获取建议的视频质量
    func getRecommendedVideoQuality() -> String {
        let quality = getNetworkQuality()
        switch quality {
        case .excellent:
            return "4K"
        case .good:
            return "1080P"
        case .fair:
            return "720P"
        case .poor:
            return "480P"
        case .unknown:
            return "AUTO"
        }
    }
}

/// 网络质量枚举
enum BandwidthQuality {
    case excellent
    case good
    case fair
    case poor
    case unknown

    var description: String {
        switch self {
        case .excellent: return "优秀"
        case .good: return "良好"
        case .fair: return "一般"
        case .poor: return "较差"
        case .unknown: return "未知"
        }
    }

    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        case .unknown: return "gray"
        }
    }
}

// MARK: - WebRequest Network Monitor Integration

extension WebRequest {
    /// 获取网络状态信息
    static func getNetworkInfo() -> (status: NetworkStatus, quality: BandwidthQuality, recommendedQuality: String) {
        if #available(iOS 12.0, tvOS 12.0, *) {
            let monitor = NetworkMonitor.shared
            return (monitor.status, monitor.getNetworkQuality(), monitor.getRecommendedVideoQuality())
        } else {
            return (.unknown, .unknown, "AUTO")
        }
    }

    /// 检查网络连接
    static func checkNetworkConnection() -> Bool {
        let (status, _, _) = getNetworkInfo()
        return status.isConnected
    }
}
