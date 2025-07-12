//
//  NetworkStatusView.swift
//  BilibiliLive
//
//  Created by Claude on 2025/1/12.
//

import SwiftUI

/// 网络状态显示视图（针对tvOS优化）
@available(iOS 13.0, tvOS 13.0, *)
struct NetworkStatusView: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var showDetails = false
    
    var body: some View {
        HStack(spacing: 20) {
            // 网络状态指示器
            networkStatusIndicator
            
            // 网络质量信息
            if showDetails {
                networkDetailsView
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
        .onPlayPauseCommand {
            withAnimation(.easeInOut(duration: 0.3)) {
                showDetails.toggle()
            }
        }
    }
    
    // MARK: - Status Indicator
    
    private var networkStatusIndicator: some View {
        HStack(spacing: 12) {
            // 连接状态图标
            Image(systemName: connectionIcon)
                .font(.title2)
                .foregroundColor(connectionColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(connectionText)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(qualityText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .focusable(true)
    }
    
    // MARK: - Details View
    
    private var networkDetailsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 延迟信息
            HStack {
                Text("延迟:")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(networkMonitor.latency * 1000))ms")
                    .foregroundColor(latencyColor)
            }
            
            // 推荐画质
            HStack {
                Text("推荐画质:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(networkMonitor.getRecommendedVideoQuality())
                    .foregroundColor(.primary)
            }
            
            // 连接类型详情
            if case .connected(let type) = networkMonitor.status {
                HStack {
                    Text("连接类型:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(type.displayName)
                        .foregroundColor(.primary)
                }
            }
        }
        .font(.caption)
        .frame(minWidth: 200)
    }
    
    // MARK: - Computed Properties
    
    private var connectionIcon: String {
        switch networkMonitor.status {
        case .connected(let type):
            switch type {
            case .wifi:
                return "wifi"
            case .ethernet:
                return "cable.connector"
            case .cellular:
                return "antenna.radiowaves.left.and.right"
            case .unknown:
                return "network"
            }
        case .disconnected:
            return "wifi.slash"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    private var connectionColor: Color {
        switch networkMonitor.getNetworkQuality() {
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
    
    private var connectionText: String {
        switch networkMonitor.status {
        case .connected(let type):
            return type.displayName
        case .disconnected:
            return "未连接"
        case .unknown:
            return "检测中..."
        }
    }
    
    private var qualityText: String {
        return "网络质量: \(networkMonitor.getNetworkQuality().description)"
    }
    
    private var latencyColor: Color {
        if networkMonitor.latency < 0.2 {
            return .green
        } else if networkMonitor.latency < 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}

/// 网络状态悬浮提示视图
@available(iOS 13.0, tvOS 13.0, *)
struct NetworkStatusOverlay: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var showAlert = false
    @State private var lastKnownStatus: NetworkStatus = .unknown
    
    var body: some View {
        Group {
            if showAlert {
                VStack {
                    Spacer()
                    
                    HStack {
                        Image(systemName: alertIcon)
                            .font(.title)
                            .foregroundColor(alertColor)
                        
                        VStack(alignment: .leading) {
                            Text(alertTitle)
                                .font(.headline)
                            Text(alertMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.8))
                    )
                    .padding(.horizontal, 100)
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: networkMonitor.status) { newStatus in
            handleNetworkStatusChange(newStatus)
        }
    }
    
    private func handleNetworkStatusChange(_ newStatus: NetworkStatus) {
        let shouldShowAlert = shouldShowAlertForStatusChange(from: lastKnownStatus, to: newStatus)
        
        if shouldShowAlert {
            withAnimation(.easeInOut(duration: 0.5)) {
                showAlert = true
            }
            
            // 3秒后自动隐藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showAlert = false
                }
            }
        }
        
        lastKnownStatus = newStatus
    }
    
    private func shouldShowAlertForStatusChange(from oldStatus: NetworkStatus, to newStatus: NetworkStatus) -> Bool {
        switch (oldStatus, newStatus) {
        case (.connected, .disconnected):
            return true
        case (.disconnected, .connected):
            return true
        case (.unknown, .disconnected):
            return true
        default:
            return false
        }
    }
    
    private var alertIcon: String {
        switch networkMonitor.status {
        case .connected:
            return "wifi"
        case .disconnected:
            return "wifi.slash"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    private var alertColor: Color {
        switch networkMonitor.status {
        case .connected:
            return .green
        case .disconnected:
            return .red
        case .unknown:
            return .orange
        }
    }
    
    private var alertTitle: String {
        switch networkMonitor.status {
        case .connected(let type):
            return "网络已连接"
        case .disconnected:
            return "网络连接断开"
        case .unknown:
            return "网络状态未知"
        }
    }
    
    private var alertMessage: String {
        switch networkMonitor.status {
        case .connected(let type):
            return "已通过\(type.displayName)连接到网络"
        case .disconnected:
            return "请检查网络设置"
        case .unknown:
            return "正在检测网络状态..."
        }
    }
}

// MARK: - Preview

@available(iOS 13.0, tvOS 13.0, *)
struct NetworkStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            NetworkStatusView()
            
            NetworkStatusOverlay()
        }
        .preferredColorScheme(.dark)
        .previewLayout(.sizeThatFits)
    }
}