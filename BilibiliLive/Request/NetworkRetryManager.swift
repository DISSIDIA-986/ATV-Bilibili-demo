//
//  NetworkRetryManager.swift
//  BilibiliLive
//
//  Created by Claude on 2025/1/12.
//

import Foundation
import Alamofire

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
    
    init(retryConfig: RetryConfiguration = .default, timeoutConfig: AdaptiveTimeoutConfiguration = .default) {
        self.retryConfig = retryConfig
        self.timeoutConfig = timeoutConfig
    }
    
    // MARK: - RequestAdapter
    
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var adaptedRequest = urlRequest
        
        // 根据设置决定是否使用自适应超时
        if Settings.networkAdaptiveTimeout {
            let adaptiveTimeout = performanceTracker.getAdaptiveTimeout(config: timeoutConfig)
            adaptedRequest.timeoutInterval = adaptiveTimeout
            Logger.debug("设置自适应超时: \(adaptiveTimeout)秒")
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
        let maxRetryCount = Settings.networkMaxRetryCount
        guard retryCount < maxRetryCount else {
            Logger.warn("达到最大重试次数 (\(maxRetryCount))")
            completion(.doNotRetry)
            return
        }
        
        // 计算退避延迟
        let delay = calculateBackoffDelay(retryCount: retryCount)
        
        Logger.info("网络请求重试 \(retryCount + 1)/\(maxRetryCount)，延迟 \(delay) 秒")
        completion(.retryWithDelay(delay))
    }
    
    private func shouldRetry(request: Request, response: HTTPURLResponse, error: Error) -> Bool {
        // 检查状态码是否可重试
        if retryConfig.retryableStatusCodes.contains(response.statusCode) {
            return true
        }
        
        // 检查错误类型
        if let afError = error as? AFError {
            switch afError {
            case .sessionTaskFailed(let sessionError):
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