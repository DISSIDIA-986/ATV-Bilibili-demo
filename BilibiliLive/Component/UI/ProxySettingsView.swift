//
//  ProxySettingsView.swift
//  BilibiliLive
//
//  Created by Claude on 2025/1/12.
//

import SwiftUI

/// 代理服务器设置视图（tvOS优化）
@available(iOS 13.0, tvOS 13.0, *)
struct ProxySettingsView: View {
    @StateObject private var proxyManager = ProxyServerManager.shared
    @State private var showAddServerSheet = false
    @State private var selectedServer: ProxyServerConfig?
    @State private var showServerDetails = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // 头部状态
                proxyStatusHeader
                
                // 自动选择开关
                autoSelectionToggle
                
                // 服务器列表
                serverListSection
                
                // 底部操作按钮
                actionButtonsSection
            }
            .padding(40)
            .navigationTitle("代理服务器设置")
        }
        .sheet(isPresented: $showAddServerSheet) {
            AddProxyServerView()
        }
        .sheet(isPresented: $showServerDetails) {
            if let server = selectedServer {
                ProxyServerDetailView(server: server)
            }
        }
    }
    
    // MARK: - Status Header
    
    private var proxyStatusHeader: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: proxyStatusIcon)
                    .font(.title)
                    .foregroundColor(proxyStatusColor)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(proxyStatusTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(proxyStatusDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // 统计信息
            let stats = proxyManager.getStatistics()
            HStack(spacing: 40) {
                StatCard(title: "总计", value: "\(stats.totalServers)")
                StatCard(title: "可用", value: "\(stats.workingServers)")
                StatCard(title: "平均延迟", value: "\(Int(stats.averageResponseTime * 1000))ms")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    // MARK: - Auto Selection Toggle
    
    private var autoSelectionToggle: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("智能代理选择")
                    .font(.headline)
                
                Text("根据网络质量自动选择最佳代理服务器")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $proxyManager.isAutoSelection)
                .labelsHidden()
                .scaleEffect(1.2)
                .onChange(of: proxyManager.isAutoSelection) { enabled in
                    if enabled {
                        proxyManager.enableAutoSelection()
                    }
                }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.2))
        )
        .focusable(true)
    }
    
    // MARK: - Server List
    
    private var serverListSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("代理服务器列表")
                .font(.headline)
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 20) {
                    ForEach(proxyManager.servers) { server in
                        ProxyServerCard(
                            server: server,
                            isSelected: proxyManager.currentServer?.id == server.id,
                            onSelect: {
                                if !proxyManager.isAutoSelection {
                                    proxyManager.setCurrentServer(server)
                                }
                            },
                            onToggle: {
                                proxyManager.toggleServer(server)
                            },
                            onDetails: {
                                selectedServer = server
                                showServerDetails = true
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsSection: some View {
        HStack(spacing: 30) {
            // 添加服务器
            Button("添加代理服务器") {
                showAddServerSheet = true
            }
            .buttonStyle(ProxyActionButtonStyle(color: .blue))
            .focusable(true)
            
            // 测试所有服务器
            Button("测试连接") {
                Task {
                    await proxyManager.performHealthCheck()
                }
            }
            .buttonStyle(ProxyActionButtonStyle(color: .green))
            .focusable(true)
            
            // 重置为默认
            Button("重置默认") {
                proxyManager.servers = proxyManager.createDefaultServers()
                proxyManager.selectBestServer()
            }
            .buttonStyle(ProxyActionButtonStyle(color: .orange))
            .focusable(true)
        }
    }
    
    // MARK: - Computed Properties
    
    private var proxyStatusIcon: String {
        if let current = proxyManager.currentServer {
            return current.qualityScore > 70 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        }
        return "xmark.circle.fill"
    }
    
    private var proxyStatusColor: Color {
        if let current = proxyManager.currentServer {
            return current.qualityScore > 70 ? .green : .orange
        }
        return .red
    }
    
    private var proxyStatusTitle: String {
        if let current = proxyManager.currentServer {
            return "当前: \(current.name)"
        }
        return "未选择代理服务器"
    }
    
    private var proxyStatusDescription: String {
        if let current = proxyManager.currentServer {
            return "状态: \(current.statusDescription) | 地区: \(current.regions.joined(separator: ", "))"
        }
        return "请选择或配置代理服务器"
    }
}

/// 代理服务器卡片组件
@available(iOS 13.0, tvOS 13.0, *)
struct ProxyServerCard: View {
    let server: ProxyServerConfig
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void
    let onDetails: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // 服务器名称和状态
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(server.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(server.host)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // 状态指示器
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
            }
            
            // 质量分数和地区
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("质量: \(Int(server.qualityScore))")
                        .font(.caption)
                    
                    Text("地区: \(server.regions.prefix(2).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let responseTime = server.responseTime {
                    Text("\(Int(responseTime * 1000))ms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 操作按钮
            HStack(spacing: 10) {
                if !ProxyServerManager.shared.isAutoSelection {
                    Button(isSelected ? "已选择" : "选择") {
                        onSelect()
                    }
                    .buttonStyle(CompactButtonStyle(isSelected: isSelected))
                    .disabled(isSelected)
                }
                
                Button(server.isEnabled ? "禁用" : "启用") {
                    onToggle()
                }
                .buttonStyle(CompactButtonStyle(color: server.isEnabled ? .red : .green))
                
                Button("详情") {
                    onDetails()
                }
                .buttonStyle(CompactButtonStyle(color: .blue))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: isSelected ? 3 : 1)
                )
        )
        .focusable(true)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
    
    private var statusColor: Color {
        if !server.isEnabled {
            return .gray
        }
        
        switch server.qualityScore {
        case 80...100:
            return .green
        case 60..<80:
            return .blue
        case 40..<60:
            return .orange
        default:
            return .red
        }
    }
    
    private var cardBackgroundColor: Color {
        if isSelected {
            return Color.blue.opacity(0.2)
        }
        return Color.black.opacity(0.3)
    }
    
    private var borderColor: Color {
        if isSelected {
            return .blue
        }
        return isFocused ? .white : .clear
    }
}

/// 统计卡片组件
@available(iOS 13.0, tvOS 13.0, *)
struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 80)
    }
}

/// 代理操作按钮样式
@available(iOS 13.0, tvOS 13.0, *)
struct ProxyActionButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// 紧凑按钮样式
@available(iOS 13.0, tvOS 13.0, *)
struct CompactButtonStyle: ButtonStyle {
    let color: Color
    let isSelected: Bool
    
    init(color: Color = .blue, isSelected: Bool = false) {
        self.color = color
        self.isSelected = isSelected
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? color : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(color, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Preview

@available(iOS 13.0, tvOS 13.0, *)
struct ProxySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ProxySettingsView()
            .preferredColorScheme(.dark)
            .previewLayout(.sizeThatFits)
    }
}