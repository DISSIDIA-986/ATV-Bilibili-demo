//
//  NetworkQualityDetector.swift
//  BilibiliLive
//
//  Created by Claude on 2025/7/12.
//

import Foundation
import Network
import Combine

/// 网络质量等级
enum NetworkQuality: Int, CaseIterable {
    case excellent = 4
    case good = 3
    case fair = 2
    case poor = 1
    case unknown = 0
    
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
    
    /// 根据网络质量推荐的超时时间
    var recommendedTimeout: TimeInterval {
        switch self {
        case .excellent: return 8.0
        case .good: return 12.0
        case .fair: return 20.0
        case .poor: return 35.0
        case .unknown: return 15.0
        }
    }
    
    /// 根据网络质量推荐的重试次数
    var recommendedRetryCount: Int {
        switch self {
        case .excellent: return 2
        case .good: return 3
        case .fair: return 4
        case .poor: return 5
        case .unknown: return 3
        }
    }
}

/// 网络质量指标
struct NetworkQualityMetrics {
    let latency: TimeInterval        // 延迟 (ms)
    let bandwidth: Double           // 带宽估算 (Mbps)
    let packetLoss: Double         // 丢包率 (%)
    let jitter: TimeInterval       // 抖动 (ms)
    let connectionType: NWInterface.InterfaceType?
    let isConstrained: Bool        // 是否受限网络
    let isExpensive: Bool          // 是否付费网络
    
    var quality: NetworkQuality {
        var score = 0
        
        // 延迟评分 (40% 权重)
        if latency < 50 {
            score += 40
        } else if latency < 100 {
            score += 30
        } else if latency < 200 {
            score += 20
        } else if latency < 500 {
            score += 10
        }
        
        // 带宽评分 (35% 权重)
        if bandwidth > 50 {
            score += 35
        } else if bandwidth > 25 {
            score += 28
        } else if bandwidth > 10 {
            score += 21
        } else if bandwidth > 5 {
            score += 14
        } else if bandwidth > 1 {
            score += 7
        }
        
        // 稳定性评分 (25% 权重)
        let stabilityScore = max(0, 25 - Int(packetLoss * 5) - Int(jitter / 10))
        score += stabilityScore
        
        // 网络条件惩罚
        if isConstrained { score -= 10 }
        if isExpensive { score -= 5 }
        
        switch score {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        case 20..<40: return .poor
        default: return .unknown
        }
    }
}

/// 网络质量检测器
class NetworkQualityDetector: ObservableObject {
    static let shared = NetworkQualityDetector()
    
    @Published var currentQuality: NetworkQuality = .unknown
    @Published var metrics: NetworkQualityMetrics?
    @Published var isDetecting = false
    
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "network.quality.monitor", qos: .utility)
    private var detectionTimer: Timer?
    private var currentPath: NWPath?
    
    // 检测配置
    private let detectionInterval: TimeInterval = 30.0 // 30秒检测一次
    private let testEndpoints = [
        "https://api.bilibili.com/x/web-interface/nav",
        "https://www.bilibili.com/favicon.ico"
    ]
    
    // 历史数据用于计算趋势
    private var latencyHistory: [TimeInterval] = []
    private var bandwidthHistory: [Double] = []
    private let maxHistorySize = 10
    
    private init() {
        setupNetworkMonitoring()
        startPeriodicDetection()
    }
    
    deinit {
        networkMonitor.cancel()
        detectionTimer?.invalidate()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.currentPath = path
                self?.updateNetworkInfo()
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    private func updateNetworkInfo() {
        guard let path = currentPath else { return }
        
        if path.status == .satisfied {
            // 网络连接正常，触发质量检测
            Task {
                await performQualityDetection()
            }
        } else {
            // 网络未连接
            currentQuality = .unknown
            metrics = nil
        }
    }
    
    // MARK: - Quality Detection
    
    private func startPeriodicDetection() {
        detectionTimer = Timer.scheduledTimer(withTimeInterval: detectionInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performQualityDetection()
            }
        }
    }
    
    @MainActor
    func performQualityDetection() async {
        guard Settings.networkAdaptiveTimeout else { return }
        guard !isDetecting else { return }
        
        isDetecting = true
        defer { isDetecting = false }
        
        do {
            let newMetrics = try await detectNetworkQuality()
            
            self.metrics = newMetrics
            self.currentQuality = newMetrics.quality
            
            Logger.info("网络质量检测完成: \(newMetrics.quality.description), 延迟: \(Int(newMetrics.latency))ms, 带宽: \(String(format: "%.1f", newMetrics.bandwidth))Mbps")
            
        } catch {
            Logger.warn("网络质量检测失败: \(error)")
            self.currentQuality = .unknown
        }
    }
    
    private func detectNetworkQuality() async throws -> NetworkQualityMetrics {
        // 并发执行延迟和带宽测试
        async let latencyResult = measureLatency()
        async let bandwidthResult = measureBandwidth()
        
        let (avgLatency, jitter, packetLoss) = try await latencyResult
        let bandwidth = try await bandwidthResult
        
        // 更新历史数据
        updateHistory(latency: avgLatency, bandwidth: bandwidth)
        
        // 获取网络路径信息
        let path = currentPath
        let connectionType = path?.availableInterfaces.first?.type
        let isConstrained = path?.isConstrained ?? false
        let isExpensive = path?.isExpensive ?? false
        
        return NetworkQualityMetrics(
            latency: avgLatency * 1000, // 转换为毫秒
            bandwidth: bandwidth,
            packetLoss: packetLoss,
            jitter: jitter * 1000, // 转换为毫秒
            connectionType: connectionType,
            isConstrained: isConstrained,
            isExpensive: isExpensive
        )
    }
    
    // MARK: - Latency Measurement
    
    private func measureLatency() async throws -> (avgLatency: TimeInterval, jitter: TimeInterval, packetLoss: Double) {
        let testCount = 5
        var latencies: [TimeInterval] = []
        var failures = 0
        
        for _ in 0..<testCount {
            do {
                let latency = try await pingEndpoint(testEndpoints[0])
                latencies.append(latency)
            } catch {
                failures += 1
            }
            
            // 测试间隔
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        guard !latencies.isEmpty else {
            throw NetworkError.measurementFailed
        }
        
        let avgLatency = latencies.reduce(0, +) / Double(latencies.count)
        let jitter = calculateJitter(latencies)
        let packetLoss = Double(failures) / Double(testCount) * 100
        
        return (avgLatency, jitter, packetLoss)
    }
    
    private func pingEndpoint(_ urlString: String) async throws -> TimeInterval {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0
        
        let _ = try await URLSession.shared.data(for: request)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        return endTime - startTime
    }
    
    private func calculateJitter(_ latencies: [TimeInterval]) -> TimeInterval {
        guard latencies.count > 1 else { return 0 }
        
        let mean = latencies.reduce(0, +) / Double(latencies.count)
        let variance = latencies.reduce(0) { sum, latency in
            sum + pow(latency - mean, 2)
        } / Double(latencies.count - 1)
        
        return sqrt(variance)
    }
    
    // MARK: - Bandwidth Measurement
    
    private func measureBandwidth() async throws -> Double {
        // 使用小文件进行带宽测试，避免消耗过多流量
        guard let url = URL(string: testEndpoints[1]) else {
            throw NetworkError.invalidURL
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // 计算带宽 (Mbps)
        let bytesReceived = Double(data.count)
        let bitsReceived = bytesReceived * 8
        let mbitsReceived = bitsReceived / 1_000_000
        let bandwidth = mbitsReceived / duration
        
        return max(bandwidth, 0.1) // 最小0.1Mbps
    }
    
    // MARK: - History Management
    
    private func updateHistory(latency: TimeInterval, bandwidth: Double) {
        latencyHistory.append(latency)
        bandwidthHistory.append(bandwidth)
        
        if latencyHistory.count > maxHistorySize {
            latencyHistory.removeFirst()
        }
        
        if bandwidthHistory.count > maxHistorySize {
            bandwidthHistory.removeFirst()
        }
    }
    
    // MARK: - Public API
    
    /// 获取推荐的网络配置
    func getRecommendedNetworkConfig() -> (timeout: TimeInterval, retryCount: Int) {
        return (currentQuality.recommendedTimeout, currentQuality.recommendedRetryCount)
    }
    
    /// 手动触发网络质量检测
    func triggerDetection() {
        Task {
            await performQualityDetection()
        }
    }
    
    /// 获取网络质量趋势
    func getQualityTrend() -> (latencyTrend: Double, bandwidthTrend: Double) {
        guard latencyHistory.count >= 3, bandwidthHistory.count >= 3 else {
            return (0, 0)
        }
        
        let recentLatency = Array(latencyHistory.suffix(3))
        let recentBandwidth = Array(bandwidthHistory.suffix(3))
        
        let latencyTrend = (recentLatency.last! - recentLatency.first!) / TimeInterval(recentLatency.count - 1)
        let bandwidthTrend = (recentBandwidth.last! - recentBandwidth.first!) / Double(recentBandwidth.count - 1)
        
        return (latencyTrend, bandwidthTrend)
    }
}

// MARK: - Error Types

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case measurementFailed
    case timeoutExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .measurementFailed:
            return "网络测量失败"
        case .timeoutExceeded:
            return "测量超时"
        }
    }
}

// MARK: - Settings Integration

extension Settings {
    /// 网络质量检测间隔 (秒)
    @UserDefault("Settings.networkQualityDetectionInterval", defaultValue: 30.0)
    static var networkQualityDetectionInterval: TimeInterval
    
    /// 是否启用网络质量指示器
    @UserDefault("Settings.showNetworkQualityIndicator", defaultValue: true)
    static var showNetworkQualityIndicator: Bool
    
    /// 是否根据网络质量自动调整媒体质量
    @UserDefault("Settings.autoAdjustQualityByNetwork", defaultValue: false)
    static var autoAdjustQualityByNetwork: Bool
}