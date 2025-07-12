//
//  NetworkQualityDetector.swift
//  BilibiliLive
//
//  Created by Claude on 2025/7/12.
//

import Combine
import Foundation
import Network

/// 网络质量等级
enum NetworkQualityLevel: Int, CaseIterable {
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
        case .excellent: return "#00C851"
        case .good: return "#2BBBAD"
        case .fair: return "#FF8800"
        case .poor: return "#FF4444"
        case .unknown: return "#757575"
        }
    }

    var score: Double {
        return Double(rawValue)
    }

    static func from(score: Double) -> NetworkQualityLevel {
        switch score {
        case 3.5...4.0:
            return .excellent
        case 2.5..<3.5:
            return .good
        case 1.5..<2.5:
            return .fair
        case 0.5..<1.5:
            return .poor
        default:
            return .unknown
        }
    }
}

/// 网络质量指标
struct NetworkQualityMetrics {
    let latency: TimeInterval
    let downloadSpeed: Double
    let uploadSpeed: Double
    let packetLoss: Double
    let jitter: TimeInterval
    let timestamp: Date
    let connectionType: String

    var qualityScore: Double {
        var score: Double = 0

        if latency < 50 {
            score += 1.0
        } else if latency < 100 {
            score += 0.8
        } else if latency < 200 {
            score += 0.5
        } else {
            score += 0.2
        }

        if downloadSpeed > 50 {
            score += 1.0
        } else if downloadSpeed > 20 {
            score += 0.8
        } else if downloadSpeed > 5 {
            score += 0.5
        } else {
            score += 0.2
        }

        if packetLoss < 0.01 {
            score += 1.0
        } else if packetLoss < 0.05 {
            score += 0.8
        } else if packetLoss < 0.1 {
            score += 0.5
        } else {
            score += 0.2
        }

        if jitter < 10 {
            score += 1.0
        } else if jitter < 30 {
            score += 0.8
        } else if jitter < 50 {
            score += 0.5
        } else {
            score += 0.2
        }

        return score
    }

    var quality: NetworkQualityLevel {
        return NetworkQualityLevel.from(score: qualityScore)
    }

    var bandwidth: Double {
        return downloadSpeed
    }
}

/// 网络端点测试配置
struct NetworkEndpoint {
    let host: String
    let port: Int
    let timeout: TimeInterval

    init(host: String, port: Int = 80, timeout: TimeInterval = 5.0) {
        self.host = host
        self.port = port
        self.timeout = timeout
    }
}

/// 网络测试结果
struct NetworkTestResult {
    let endpoint: NetworkEndpoint
    let latency: TimeInterval?
    let isReachable: Bool
    let error: Error?
}

/// 网络质量检测器
class NetworkQualityDetector: ObservableObject {
    static let shared = NetworkQualityDetector()

    @Published var currentQuality: NetworkQualityLevel = .unknown
    @Published var metrics: NetworkQualityMetrics?
    @Published var isDetecting = false

    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkQualityDetector")
    private var detectionTimer: Timer?

    private let testEndpoints = [
        NetworkEndpoint(host: "8.8.8.8"),
        NetworkEndpoint(host: "1.1.1.1"),
        NetworkEndpoint(host: "114.114.114.114"),
        NetworkEndpoint(host: "223.5.5.5"),
        NetworkEndpoint(host: "api.bilibili.com", port: 443),
    ]

    private init() {
        setupNetworkMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self?.startContinuousDetection()
                } else {
                    self?.currentQuality = .unknown
                    self?.metrics = nil
                }
            }
        }
    }

    func startMonitoring() {
        networkMonitor.start(queue: monitorQueue)
    }

    func stopMonitoring() {
        networkMonitor.cancel()
        detectionTimer?.invalidate()
        detectionTimer = nil
    }

    private func startContinuousDetection() {
        detectionTimer?.invalidate()
        detectionTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.performQualityDetection()
            }
        }

        Task {
            await performQualityDetection()
        }
    }

    @MainActor
    func performQualityDetection() async {
        guard !isDetecting else { return }
        isDetecting = true

        do {
            let newMetrics = try await detectNetworkMetrics()
            metrics = newMetrics
            currentQuality = newMetrics.quality
        } catch {
            print("网络质量检测失败: \(error)")
            currentQuality = .unknown
        }

        isDetecting = false
    }

    private func detectNetworkMetrics() async throws -> NetworkQualityMetrics {
        async let latencyTask = measureAverageLatency()
        async let speedTask = measureNetworkSpeed()
        async let packetLossTask = measurePacketLoss()
        async let jitterTask = measureJitter()

        let latency = await latencyTask
        let (downloadSpeed, uploadSpeed) = await speedTask
        let packetLoss = await packetLossTask
        let jitter = await jitterTask

        return NetworkQualityMetrics(
            latency: latency,
            downloadSpeed: downloadSpeed,
            uploadSpeed: uploadSpeed,
            packetLoss: packetLoss,
            jitter: jitter,
            timestamp: Date(),
            connectionType: "Unknown" // Simple implementation
        )
    }

    private func measureAverageLatency() async -> TimeInterval {
        let latencies = await withTaskGroup(of: TimeInterval?.self) { group in
            for endpoint in testEndpoints.prefix(3) {
                group.addTask {
                    await self.measureLatency(to: endpoint)
                }
            }

            var results: [TimeInterval] = []
            for await latency in group {
                if let latency = latency {
                    results.append(latency)
                }
            }
            return results
        }

        guard !latencies.isEmpty else { return 1000 }
        return latencies.reduce(0, +) / Double(latencies.count)
    }

    private func measureLatency(to endpoint: NetworkEndpoint) async -> TimeInterval? {
        let startTime = CFAbsoluteTimeGetCurrent()

        let connection = NWConnection(
            host: NWEndpoint.Host(endpoint.host),
            port: NWEndpoint.Port(integerLiteral: UInt16(endpoint.port)),
            using: .tcp
        )

        connection.start(queue: monitorQueue)

        return await withCheckedContinuation { continuation in
            let timeoutTimer = Timer.scheduledTimer(withTimeInterval: endpoint.timeout, repeats: false) { _ in
                connection.cancel()
                continuation.resume(returning: nil)
            }

            connection.stateUpdateHandler = { [timeoutTimer] state in
                timeoutTimer.invalidate()
                switch state {
                case .ready:
                    let latency = CFAbsoluteTimeGetCurrent() - startTime
                    connection.cancel()
                    continuation.resume(returning: latency)
                case .failed, .cancelled:
                    connection.cancel()
                    continuation.resume(returning: nil)
                default:
                    break
                }
            }
        }
    }

    private func measureNetworkSpeed() async -> (download: Double, upload: Double) {
        let testURL = URL(string: "https://httpbin.org/bytes/1024")!

        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            let (data, _) = try await URLSession.shared.data(from: testURL)
            let endTime = CFAbsoluteTimeGetCurrent()

            let duration = endTime - startTime
            let bytesPerSecond = Double(data.count) / duration
            let mbps = (bytesPerSecond * 8) / (1024 * 1024)

            return (download: mbps, upload: mbps * 0.3)
        } catch {
            return (download: 0, upload: 0)
        }
    }

    private func measurePacketLoss() async -> Double {
        let testCount = 10
        var successCount = 0

        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<testCount {
                group.addTask {
                    let latency = await self.measureLatency(to: self.testEndpoints[0])
                    return latency != nil
                }
            }

            for await success in group {
                if success {
                    successCount += 1
                }
            }
        }

        return 1.0 - (Double(successCount) / Double(testCount))
    }

    private func measureJitter() async -> TimeInterval {
        var latencies: [TimeInterval] = []

        for _ in 0..<5 {
            if let latency = await measureLatency(to: testEndpoints[0]) {
                latencies.append(latency)
            }
        }

        guard latencies.count > 1 else { return 0 }

        let average = latencies.reduce(0, +) / Double(latencies.count)
        let variance = latencies.map { pow($0 - average, 2) }.reduce(0, +) / Double(latencies.count)
        return sqrt(variance) * 1000
    }

    func getAdaptiveTimeout(baseTimeout: TimeInterval) -> TimeInterval {
        switch currentQuality {
        case .excellent:
            return baseTimeout * 0.8
        case .good:
            return baseTimeout
        case .fair:
            return baseTimeout * 1.5
        case .poor:
            return baseTimeout * 2.5
        case .unknown:
            return baseTimeout * 2.0
        }
    }

    func getRecommendedRetryDelay() -> TimeInterval {
        switch currentQuality {
        case .excellent:
            return 0.5
        case .good:
            return 1.0
        case .fair:
            return 2.0
        case .poor:
            return 5.0
        case .unknown:
            return 3.0
        }
    }

    func shouldUseAlternativeServer() -> Bool {
        return currentQuality == .poor || currentQuality == .unknown
    }

    func getRecommendedNetworkConfig() -> NetworkConfig {
        let timeout: TimeInterval
        let retryCount: Int

        switch currentQuality {
        case .excellent:
            timeout = 10.0
            retryCount = 2
        case .good:
            timeout = 15.0
            retryCount = 3
        case .fair:
            timeout = 20.0
            retryCount = 4
        case .poor:
            timeout = 30.0
            retryCount = 5
        case .unknown:
            timeout = 25.0
            retryCount = 4
        }

        return NetworkConfig(timeout: timeout, retryCount: retryCount)
    }

    func triggerDetection() {
        Task {
            await performQualityDetection()
        }
    }

    func getQualityTrend() -> (latencyTrend: String, bandwidthTrend: String) {
        // Simple implementation - in a real app, this would analyze historical data
        let latencyTrend = currentQuality.rawValue > 2 ? "↑" : currentQuality.rawValue == 2 ? "→" : "↓"
        let bandwidthTrend = currentQuality.rawValue > 2 ? "↑" : currentQuality.rawValue == 2 ? "→" : "↓"
        return (latencyTrend, bandwidthTrend)
    }
}

struct NetworkConfig {
    let timeout: TimeInterval
    let retryCount: Int
}
