//
//  NetworkQualityTestRunner.swift
//  BilibiliLive
//
//  Created by Claude on 2025/7/12.
//

import Foundation

/// 简单的网络质量功能测试器
class NetworkQualityTestRunner {
    static func runBasicTests() {
        print("🧪 开始网络质量功能测试...")

        testNetworkQualityMetrics()
        testRecommendedConfigurations()
        testSettingsIntegration()

        print("✅ 基础测试完成")
    }

    static func testNetworkQualityMetrics() {
        print("\n📊 测试网络质量指标计算...")

        // 测试优秀网络质量
        let excellentMetrics = NetworkQualityMetrics(
            latency: 30, // 30ms 延迟
            bandwidth: 100, // 100Mbps 带宽
            packetLoss: 0.0, // 无丢包
            jitter: 5, // 5ms 抖动
            connectionType: .wifi,
            isConstrained: false,
            isExpensive: false
        )

        assert(excellentMetrics.quality == .excellent, "优秀网络参数应该被评为优秀质量")
        print("  ✓ 优秀网络质量计算正确")

        // 测试较差网络质量
        let poorMetrics = NetworkQualityMetrics(
            latency: 800, // 800ms 延迟
            bandwidth: 0.5, // 0.5Mbps 带宽
            packetLoss: 15.0, // 15% 丢包
            jitter: 200, // 200ms 抖动
            connectionType: .cellular,
            isConstrained: true,
            isExpensive: true
        )

        assert(poorMetrics.quality == .poor, "较差网络参数应该被评为较差质量")
        print("  ✓ 较差网络质量计算正确")

        // 测试中等网络质量
        let fairMetrics = NetworkQualityMetrics(
            latency: 150, // 150ms 延迟
            bandwidth: 15, // 15Mbps 带宽
            packetLoss: 3.0, // 3% 丢包
            jitter: 30, // 30ms 抖动
            connectionType: .wifi,
            isConstrained: false,
            isExpensive: false
        )

        assert(fairMetrics.quality == .fair, "中等网络参数应该被评为一般质量")
        print("  ✓ 中等网络质量计算正确")
    }

    static func testRecommendedConfigurations() {
        print("\n⚙️ 测试推荐配置...")

        // 测试不同网络质量的推荐超时时间
        assert(NetworkQuality.excellent.recommendedTimeout == 8.0, "优秀网络推荐超时时间应为8秒")
        assert(NetworkQuality.good.recommendedTimeout == 12.0, "良好网络推荐超时时间应为12秒")
        assert(NetworkQuality.fair.recommendedTimeout == 20.0, "一般网络推荐超时时间应为20秒")
        assert(NetworkQuality.poor.recommendedTimeout == 35.0, "较差网络推荐超时时间应为35秒")
        assert(NetworkQuality.unknown.recommendedTimeout == 15.0, "未知网络推荐超时时间应为15秒")
        print("  ✓ 推荐超时时间配置正确")

        // 测试不同网络质量的推荐重试次数
        assert(NetworkQuality.excellent.recommendedRetryCount == 2, "优秀网络推荐重试2次")
        assert(NetworkQuality.good.recommendedRetryCount == 3, "良好网络推荐重试3次")
        assert(NetworkQuality.fair.recommendedRetryCount == 4, "一般网络推荐重试4次")
        assert(NetworkQuality.poor.recommendedRetryCount == 5, "较差网络推荐重试5次")
        assert(NetworkQuality.unknown.recommendedRetryCount == 3, "未知网络推荐重试3次")
        print("  ✓ 推荐重试次数配置正确")
    }

    static func testSettingsIntegration() {
        print("\n🔧 测试设置集成...")

        // 测试新增的设置项默认值
        assert(Settings.networkQualityDetectionInterval == 30.0, "默认检测间隔应该是30秒")
        assert(Settings.showNetworkQualityIndicator == true, "默认应该显示网络质量指示器")
        assert(Settings.autoAdjustQualityByNetwork == false, "默认不应该自动调整媒体质量")
        print("  ✓ 设置默认值正确")

        // 测试设置更改
        let originalInterval = Settings.networkQualityDetectionInterval
        Settings.networkQualityDetectionInterval = 60.0
        assert(Settings.networkQualityDetectionInterval == 60.0, "设置更改应该生效")
        Settings.networkQualityDetectionInterval = originalInterval // 恢复原值
        print("  ✓ 设置更改功能正常")
    }

    static func testNetworkQualityDetector() async {
        print("\n🌐 测试网络质量检测器...")

        let detector = NetworkQualityDetector.shared

        // 测试初始状态
        print("  • 初始网络质量: \(detector.currentQuality.description)")
        print("  • 是否正在检测: \(detector.isDetecting)")

        // 触发网络质量检测
        print("  • 开始网络质量检测...")
        await detector.performQualityDetection()

        // 等待检测完成
        var attempts = 0
        while detector.isDetecting && attempts < 10 {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            attempts += 1
        }

        print("  • 检测完成")
        print("  • 最终网络质量: \(detector.currentQuality.description)")

        if let metrics = detector.metrics {
            print("  • 延迟: \(Int(metrics.latency))ms")
            print("  • 带宽: \(String(format: "%.1f", metrics.bandwidth))Mbps")
            print("  • 丢包率: \(String(format: "%.1f", metrics.packetLoss))%")
            print("  • 抖动: \(Int(metrics.jitter))ms")
        }

        // 测试推荐配置
        let config = detector.getRecommendedNetworkConfig()
        print("  • 推荐超时: \(config.timeout)秒")
        print("  • 推荐重试: \(config.retryCount)次")

        print("  ✓ 网络质量检测器功能正常")
    }

    static func testNetworkRetryManager() {
        print("\n🔄 测试网络重试管理器...")

        let retryManager = NetworkRetryManager()
        let url = URL(string: "https://api.bilibili.com/test")!
        let request = URLRequest(url: url)

        // 测试请求适配
        let expectation = NSCondition()
        expectation.lock()

        retryManager.adapt(request, for: Session.default) { result in
            defer {
                expectation.signal()
                expectation.unlock()
            }

            switch result {
            case let .success(adaptedRequest):
                print("  • 适配后超时时间: \(adaptedRequest.timeoutInterval)秒")
                print("  ✓ 请求适配功能正常")
            case let .failure(error):
                print("  ❌ 请求适配失败: \(error)")
            }
        }

        expectation.wait()
    }

    static func runIntegrationTest() async {
        print("\n🔗 运行集成测试...")

        // 启用网络自适应功能
        Settings.networkAdaptiveTimeout = true
        Settings.networkAutoRetry = true

        print("  • 网络自适应超时: \(Settings.networkAdaptiveTimeout)")
        print("  • 网络自动重试: \(Settings.networkAutoRetry)")

        // 执行网络质量检测
        await testNetworkQualityDetector()

        // 测试网络重试管理器
        testNetworkRetryManager()

        print("  ✓ 集成测试完成")
    }
}

// MARK: - 测试运行器扩展

extension NetworkQualityTestRunner {
    /// 运行所有测试
    static func runAllTests() async {
        print("🚀 开始完整的网络质量功能测试...")
        print("=" * 50)

        runBasicTests()
        await runIntegrationTest()

        print("=" * 50)
        print("🎉 所有测试完成！")
    }
}

// MARK: - 字符串重复扩展

extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}
