//
//  NetworkQualityIndicatorView.swift
//  BilibiliLive
//
//  Created by Claude on 2025/7/12.
//

import Network
import SwiftUI

/// 网络质量指示器视图
struct NetworkQualityIndicatorView: View {
    @StateObject private var detector = NetworkQualityDetector.shared
    @State private var showDetails = false

    var body: some View {
        HStack(spacing: 8) {
            // 网络质量图标和颜色
            Image(systemName: networkIcon)
                .foregroundColor(qualityColor)
                .font(.system(size: 16, weight: .medium))

            if Settings.showNetworkQualityIndicator {
                Text(detector.currentQuality.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if detector.isDetecting {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(qualityColor.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(qualityColor.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            showDetails.toggle()
        }
        .sheet(isPresented: $showDetails) {
            NetworkQualityDetailView()
        }
    }

    private var networkIcon: String {
        switch detector.currentQuality {
        case .excellent:
            return "wifi.circle.fill"
        case .good:
            return "wifi.circle"
        case .fair:
            return "wifi.exclamationmark"
        case .poor:
            return "wifi.slash"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var qualityColor: Color {
        switch detector.currentQuality {
        case .excellent:
            return .green
        case .good:
            return .blue
        case .fair:
            return .orange
        case .poor:
            return .red
        case .unknown:
            return .gray
        }
    }
}

/// 网络质量详情视图
struct NetworkQualityDetailView: View {
    @StateObject private var detector = NetworkQualityDetector.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 网络质量总览
                networkQualityOverview

                Divider()

                // 详细指标
                if let metrics = detector.metrics {
                    networkMetricsDetail(metrics)
                } else {
                    Text("正在检测网络质量...")
                        .foregroundColor(.secondary)
                }

                Divider()

                // 推荐配置
                recommendedSettings

                Spacer()
            }
            .padding()
            .navigationTitle("网络质量")
            // .navigationBarTitleDisplayMode(.inline) // Not available on tvOS
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("重新检测") {
                        detector.triggerDetection()
                    }
                    .disabled(detector.isDetecting)
                }
            }
        }
    }

    private var networkQualityOverview: some View {
        VStack(spacing: 12) {
            // 质量等级显示
            HStack {
                Image(systemName: qualityIcon)
                    .font(.system(size: 32))
                    .foregroundColor(qualityColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("网络质量")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(detector.currentQuality.description)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(qualityColor)
                }

                Spacer()
            }

            // 质量评分条
            if let metrics = detector.metrics {
                QualityProgressBar(
                    value: Double(metrics.quality.rawValue),
                    maxValue: 4.0,
                    color: qualityColor
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(qualityColor.opacity(0.1))
        )
    }

    private func networkMetricsDetail(_ metrics: NetworkQualityMetrics) -> some View {
        VStack(spacing: 16) {
            Text("网络指标")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 16) {
                MetricCard(
                    title: "延迟",
                    value: String(format: "%.0f ms", metrics.latency),
                    icon: "timer",
                    color: latencyColor(metrics.latency)
                )

                MetricCard(
                    title: "带宽",
                    value: String(format: "%.1f Mbps", metrics.bandwidth),
                    icon: "speedometer",
                    color: bandwidthColor(metrics.bandwidth)
                )

                MetricCard(
                    title: "抖动",
                    value: String(format: "%.0f ms", metrics.jitter),
                    icon: "waveform.path.ecg",
                    color: jitterColor(metrics.jitter)
                )

                MetricCard(
                    title: "丢包率",
                    value: String(format: "%.1f%%", metrics.packetLoss),
                    icon: "exclamationmark.triangle",
                    color: packetLossColor(metrics.packetLoss)
                )
            }

            // 连接信息
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("连接类型")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(metrics.connectionType)
                        .font(.body)
                        .fontWeight(.medium)
                }

                Spacer()

                VStack(spacing: 4) {
                    if metrics.packetLoss > 0.05 {
                        Label("网络不稳定", systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    if metrics.downloadSpeed < 5.0 {
                        Label("低速网络", systemImage: "dollarsign.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }

    private var recommendedSettings: some View {
        VStack(spacing: 12) {
            Text("推荐配置")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            let config = detector.getRecommendedNetworkConfig()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("推荐超时时间")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(Int(config.timeout)) 秒")
                        .font(.body)
                        .fontWeight(.medium)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("推荐重试次数")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(config.retryCount) 次")
                        .font(.body)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
            )

            // 趋势信息
            let (latencyTrend, bandwidthTrend) = detector.getQualityTrend()

            if latencyTrend != "→" || bandwidthTrend != "→" {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("延迟趋势")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Image(systemName: latencyTrend == "↑" ? "arrow.up" : "arrow.down")
                                .foregroundColor(latencyTrend == "↑" ? .red : .green)

                            Text(latencyTrend == "↑" ? "增加" : "改善")
                                .font(.body)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("带宽趋势")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Text(bandwidthTrend == "↑" ? "提升" : "下降")
                                .font(.body)

                            Image(systemName: bandwidthTrend == "↑" ? "arrow.up" : "arrow.down")
                                .foregroundColor(bandwidthTrend == "↑" ? .green : .red)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                )
            }
        }
    }

    // MARK: - Helper Views

    private var qualityIcon: String {
        switch detector.currentQuality {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .fair: return "exclamationmark.circle"
        case .poor: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    private var qualityColor: Color {
        switch detector.currentQuality {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        case .unknown: return .gray
        }
    }

    // MARK: - Color Helpers

    private func latencyColor(_ latency: TimeInterval) -> Color {
        switch latency {
        case 0..<50: return .green
        case 50..<100: return .blue
        case 100..<200: return .orange
        default: return .red
        }
    }

    private func bandwidthColor(_ bandwidth: Double) -> Color {
        switch bandwidth {
        case 50...: return .green
        case 25..<50: return .blue
        case 10..<25: return .orange
        default: return .red
        }
    }

    private func jitterColor(_ jitter: TimeInterval) -> Color {
        switch jitter {
        case 0..<10: return .green
        case 10..<50: return .blue
        case 50..<100: return .orange
        default: return .red
        }
    }

    private func packetLossColor(_ loss: Double) -> Color {
        switch loss {
        case 0..<1: return .green
        case 1..<5: return .blue
        case 5..<10: return .orange
        default: return .red
        }
    }

    private func connectionTypeString(_ type: NWInterface.InterfaceType?) -> String {
        guard let type = type else { return "未知" }

        switch type {
        case .wifi: return "Wi-Fi"
        case .cellular: return "蜂窝网络"
        case .wiredEthernet: return "有线网络"
        case .loopback: return "本地回环"
        case .other: return "其他"
        @unknown default: return "未知"
        }
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct QualityProgressBar: View {
    let value: Double
    let maxValue: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray))
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(
                        width: geometry.size.width * CGFloat(value / maxValue),
                        height: 8
                    )
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Preview

struct NetworkQualityIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            NetworkQualityIndicatorView()

            NetworkQualityDetailView()
        }
        .padding()
    }
}
