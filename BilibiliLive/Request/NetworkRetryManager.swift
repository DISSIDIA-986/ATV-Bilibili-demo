//
//  NetworkRetryManager.swift
//  BilibiliLive
//
//  Created by Claude on 2025/1/12.
//

import Alamofire
import Foundation

/// 网络重试配置
struct RetryConfiguration {
    let maxRetryCount: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let backoffMultiplier: Double
    let retryableStatusCodes: Set<Int>

    static let `default` = RetryConfiguration(
        maxRetryCount: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        backoffMultiplier: 2.0,
        retryableStatusCodes: [408, 429, 500, 502, 503, 504]
    )
}

/// 自适应超时配置
struct AdaptiveTimeoutConfiguration {
    let minimumTimeout: TimeInterval
    let maximumTimeout: TimeInterval
    let defaultTimeout: TimeInterval
    let adaptationFactor: Double

    static let `default` = AdaptiveTimeoutConfiguration(
        minimumTimeout: 5.0,
        maximumTimeout: 60.0,
        defaultTimeout: 15.0,
        adaptationFactor: 0.1
    )
}

/// 网络性能统计
class NetworkPerformanceTracker {
    private var requestHistory: [TimeInterval] = []
    private let maxHistorySize = 10
    private let queue = DispatchQueue(label: "network.performance.tracker", qos: .utility)

    func recordRequestDuration(_ duration: TimeInterval) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.requestHistory.append(duration)
            if self.requestHistory.count > self.maxHistorySize {
                self.requestHistory.removeFirst()
            }
        }
    }

    func getAverageRequestTime() -> TimeInterval {
        return queue.sync {
            guard !requestHistory.isEmpty else { return 15.0 }
            return requestHistory.reduce(0, +) / Double(requestHistory.count)
        }
    }

    func getAdaptiveTimeout(config: AdaptiveTimeoutConfiguration) -> TimeInterval {
        let averageTime = getAverageRequestTime()
        let adaptedTimeout = averageTime * (1 + config.adaptationFactor)
        return min(max(adaptedTimeout, config.minimumTimeout), config.maximumTimeout)
    }
}

/// 增强的网络重试管理器
class NetworkRetryManager: RequestInterceptor {
    private let retryConfig: RetryConfiguration
    private let timeoutConfig: AdaptiveTimeoutConfiguration
    private let performanceTracker = NetworkPerformanceTracker()
    private let qualityDetector = NetworkQualityDetector.shared

    init(retryConfig: RetryConfiguration = .default, timeoutConfig: AdaptiveTimeoutConfiguration = .default) {
        self.retryConfig = retryConfig
        self.timeoutConfig = timeoutConfig
    }

    // MARK: - RequestAdapter

    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var adaptedRequest = urlRequest

        // 根据设置决定是否使用自适应超时
        if Settings.networkAdaptiveTimeout {
            // 优先使用网络质量检测的推荐超时时间
            let recommendedTimeout = qualityDetector.getRecommendedNetworkConfig().timeout
            let adaptiveTimeout = performanceTracker.getAdaptiveTimeout(config: timeoutConfig)

            // 取推荐超时和自适应超时的加权平均
            let finalTimeout = (recommendedTimeout * 0.7) + (adaptiveTimeout * 0.3)
            adaptedRequest.timeoutInterval = min(max(finalTimeout, timeoutConfig.minimumTimeout), timeoutConfig.maximumTimeout)

            Logger.debug("设置智能超时: \(finalTimeout)秒 (网络质量: \(qualityDetector.currentQuality.description))")
        } else {
            adaptedRequest.timeoutInterval = timeoutConfig.defaultTimeout
            Logger.debug("使用默认超时: \(timeoutConfig.defaultTimeout)秒")
        }

        completion(.success(adaptedRequest))
    }

    // MARK: - RequestRetrier

    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        // 检查是否启用了自动重试
        guard Settings.networkAutoRetry else {
            Logger.info("自动重试已禁用")
            completion(.doNotRetry)
            return
        }

        guard let response = request.task?.response as? HTTPURLResponse else {
            completion(.doNotRetry)
            return
        }

        // 检查是否应该重试
        guard shouldRetry(request: request, response: response, error: error) else {
            completion(.doNotRetry)
            return
        }

        let retryCount = request.retryCount
        // 使用网络质量检测的推荐重试次数
        let maxRetryCount = qualityDetector.getRecommendedNetworkConfig().retryCount
        guard retryCount < maxRetryCount else {
            Logger.warn("达到智能重试次数限制 (\(maxRetryCount), 网络质量: \(qualityDetector.currentQuality.description))")
            completion(.doNotRetry)
            return
        }

        // 计算退避延迟，根据网络质量调整
        let baseDelay = calculateBackoffDelay(retryCount: retryCount)
        let qualityMultiplier = getQualityDelayMultiplier()
        let adjustedDelay = baseDelay * qualityMultiplier

        Logger.info("智能网络重试 \(retryCount + 1)/\(maxRetryCount)，延迟 \(adjustedDelay) 秒 (网络质量: \(qualityDetector.currentQuality.description))")
        completion(.retryWithDelay(adjustedDelay))
    }

    private func shouldRetry(request: Request, response: HTTPURLResponse, error: Error) -> Bool {
        // 检查状态码是否可重试
        if retryConfig.retryableStatusCodes.contains(response.statusCode) {
            return true
        }

        // 检查错误类型
        if let afError = error as? AFError {
            switch afError {
            case let .sessionTaskFailed(sessionError):
                // 检查底层网络错误
                if let urlError = sessionError as? URLError {
                    switch urlError.code {
                    case .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost:
                        return true
                    default:
                        break
                    }
                }
            default:
                break
            }
        }

        return false
    }

    private func calculateBackoffDelay(retryCount: Int) -> TimeInterval {
        let exponentialDelay = retryConfig.baseDelay * pow(retryConfig.backoffMultiplier, Double(retryCount))

        // 添加随机抖动避免雷群效应
        let jitter = Double.random(in: 0.0...1.0)
        let jitteredDelay = exponentialDelay * (0.5 + jitter * 0.5)

        return min(jitteredDelay, retryConfig.maxDelay)
    }

    /// 根据网络质量获取延迟调整乘数
    private func getQualityDelayMultiplier() -> Double {
        switch qualityDetector.currentQuality {
        case .excellent:
            return 0.8 // 网络优秀，减少延迟
        case .good:
            return 1.0 // 网络良好，正常延迟
        case .fair:
            return 1.3 // 网络一般，增加延迟
        case .poor:
            return 1.8 // 网络较差，显著增加延迟
        case .unknown:
            return 1.2 // 未知质量，略微增加延迟
        }
    }

    // MARK: - Performance Tracking

    func recordRequestPerformance(startTime: Date, endTime: Date) {
        let duration = endTime.timeIntervalSince(startTime)
        performanceTracker.recordRequestDuration(duration)
    }
}

/// 网络监控扩展
extension NetworkRetryManager {
    /// 获取当前网络性能统计
    func getNetworkStats() -> (averageTime: TimeInterval, adaptiveTimeout: TimeInterval) {
        let averageTime = performanceTracker.getAverageRequestTime()
        let adaptiveTimeout = performanceTracker.getAdaptiveTimeout(config: timeoutConfig)
        return (averageTime, adaptiveTimeout)
    }

    /// 重置性能统计
    func resetPerformanceStats() {
        performanceTracker.recordRequestDuration(timeoutConfig.defaultTimeout)
    }
}
