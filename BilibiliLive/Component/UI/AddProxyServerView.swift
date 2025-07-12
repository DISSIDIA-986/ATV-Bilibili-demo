//
//  AddProxyServerView.swift
//  BilibiliLive
//
//  Created by Claude on 2025/1/12.
//

import SwiftUI

/// 添加代理服务器视图
@available(iOS 13.0, tvOS 13.0, *)
struct AddProxyServerView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var proxyManager = ProxyServerManager.shared

    @State private var serverName = ""
    @State private var serverHost = ""
    @State private var selectedRegions: Set<String> = []
    @State private var showValidationError = false
    @State private var validationMessage = ""

    private let availableRegions = [
        ("hk", "香港"), ("tw", "台湾"), ("mo", "澳门"),
        ("sg", "新加坡"), ("my", "马来西亚"), ("th", "泰国"),
        ("jp", "日本"), ("kr", "韩国"), ("us", "美国"),
        ("uk", "英国"), ("ca", "加拿大"), ("au", "澳大利亚"),
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // 表单输入
                formSection

                // 地区选择
                regionSelectionSection

                // 底部按钮
                actionButtonsSection

                Spacer()
            }
            .padding(40)
            .navigationTitle("添加代理服务器")
            .alert("输入错误", isPresented: $showValidationError) {
                Button("确定") {}
            } message: {
                Text(validationMessage)
            }
        }
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: 20) {
            // 服务器名称
            VStack(alignment: .leading, spacing: 8) {
                Text("服务器名称")
                    .font(.headline)

                TextField("例如: 香港代理服务器", text: $serverName)
                    .textFieldStyle(ProxyTextFieldStyle())
                    .focusable(true)
            }

            // 服务器地址
            VStack(alignment: .leading, spacing: 8) {
                Text("服务器地址")
                    .font(.headline)

                TextField("例如: proxy.example.com", text: $serverHost)
                    .textFieldStyle(ProxyTextFieldStyle())
                    .focusable(true)
            }
        }
    }

    // MARK: - Region Selection

    private var regionSelectionSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("支持地区")
                .font(.headline)

            Text("选择此代理服务器支持的地区（可多选）")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 15) {
                ForEach(availableRegions, id: \.0) { region in
                    RegionSelectionCard(
                        regionCode: region.0,
                        regionName: region.1,
                        isSelected: selectedRegions.contains(region.0),
                        onToggle: {
                            if selectedRegions.contains(region.0) {
                                selectedRegions.remove(region.0)
                            } else {
                                selectedRegions.insert(region.0)
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        HStack(spacing: 20) {
            Button("取消") {
                presentationMode.wrappedValue.dismiss()
            }
            .buttonStyle(ProxyActionButtonStyle(color: .gray))
            .focusable(true)

            Button("添加服务器") {
                addServer()
            }
            .buttonStyle(ProxyActionButtonStyle(color: .blue))
            .focusable(true)
        }
    }

    // MARK: - Actions

    private func addServer() {
        // 验证输入
        guard !serverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showValidationError(message: "请输入服务器名称")
            return
        }

        guard !serverHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showValidationError(message: "请输入服务器地址")
            return
        }

        guard !selectedRegions.isEmpty else {
            showValidationError(message: "请至少选择一个支持的地区")
            return
        }

        // 验证服务器地址格式
        let cleanHost = serverHost.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")

        guard isValidHostname(cleanHost) else {
            showValidationError(message: "服务器地址格式不正确")
            return
        }

        // 添加服务器
        proxyManager.addCustomServer(
            name: serverName.trimmingCharacters(in: .whitespacesAndNewlines),
            host: cleanHost,
            regions: Array(selectedRegions)
        )

        presentationMode.wrappedValue.dismiss()
    }

    private func showValidationError(message: String) {
        validationMessage = message
        showValidationError = true
    }

    private func isValidHostname(_ hostname: String) -> Bool {
        let hostnameRegex = "^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?([.][a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", hostnameRegex)
        return predicate.evaluate(with: hostname)
    }
}

/// 地区选择卡片
@available(iOS 13.0, tvOS 13.0, *)
struct RegionSelectionCard: View {
    let regionCode: String
    let regionName: String
    let isSelected: Bool
    let onToggle: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 8) {
                Text(regionCode.uppercased())
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : .primary)

                Text(regionName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .secondary)
                    .lineLimit(1)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor, lineWidth: 2)
                    )
            )
        }
        .focusable(true)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }

    private var backgroundColor: Color {
        if isSelected {
            return .blue
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

/// 代理文本框样式
@available(iOS 13.0, tvOS 13.0, *)
struct ProxyTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray, lineWidth: 1)
                    )
            )
            .foregroundColor(.primary)
    }
}

/// 代理服务器详情视图
@available(iOS 13.0, tvOS 13.0, *)
struct ProxyServerDetailView: View {
    let server: ProxyServerConfig
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var proxyManager = ProxyServerManager.shared

    @State private var isTestingConnection = false
    @State private var testResult: String = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // 服务器信息
                serverInfoSection

                // 性能统计
                performanceSection

                // 支持地区
                regionsSection

                // 连接测试
                testSection

                // 操作按钮
                actionButtonsSection

                Spacer()
            }
            .padding(40)
            .navigationTitle("服务器详情")
        }
    }

    // MARK: - Server Info

    private var serverInfoSection: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "server.rack")
                    .font(.title)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 5) {
                    Text(server.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(server.host)
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 状态指示器
                VStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 20, height: 20)

                    Text(server.statusDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.3))
        )
    }

    // MARK: - Performance

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("性能统计")
                .font(.headline)

            HStack(spacing: 30) {
                StatCard(title: "质量分数", value: "\(Int(server.qualityScore))")

                if let responseTime = server.responseTime {
                    StatCard(title: "响应时间", value: "\(Int(responseTime * 1000))ms")
                } else {
                    StatCard(title: "响应时间", value: "未知")
                }

                StatCard(title: "可靠性", value: "\(Int(server.reliability * 100))%")

                if let lastChecked = server.lastChecked {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .short
                    formatter.timeStyle = .short
                    StatCard(title: "上次检查", value: formatter.string(from: lastChecked))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.2))
        )
    }

    // MARK: - Regions

    private var regionsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("支持地区")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                ForEach(server.regions, id: \.self) { region in
                    Text(region.uppercased())
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.3))
                        )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.2))
        )
    }

    // MARK: - Test Section

    private var testSection: some View {
        VStack(spacing: 15) {
            Button(isTestingConnection ? "测试中..." : "测试连接") {
                testConnection()
            }
            .buttonStyle(ProxyActionButtonStyle(color: .green))
            .disabled(isTestingConnection)
            .focusable(true)

            if !testResult.isEmpty {
                Text(testResult)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.2))
        )
    }

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        HStack(spacing: 20) {
            Button("关闭") {
                presentationMode.wrappedValue.dismiss()
            }
            .buttonStyle(ProxyActionButtonStyle(color: .gray))
            .focusable(true)

            Button(server.isEnabled ? "禁用" : "启用") {
                proxyManager.toggleServer(server)
            }
            .buttonStyle(ProxyActionButtonStyle(color: server.isEnabled ? .red : .green))
            .focusable(true)

            if !proxyManager.isAutoSelection {
                Button("设为当前") {
                    proxyManager.setCurrentServer(server)
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(ProxyActionButtonStyle(color: .blue))
                .focusable(true)
            }
        }
    }

    // MARK: - Test Connection

    private func testConnection() {
        isTestingConnection = true
        testResult = ""

        Task {
            let startTime = Date()

            do {
                let testUrl = "https://\(server.host)/health"
                var request = URLRequest(url: URL(string: testUrl)!)
                request.timeoutInterval = 10.0

                let (_, response) = try await URLSession.shared.data(for: request)
                let responseTime = Date().timeIntervalSince(startTime)

                await MainActor.run {
                    if let httpResponse = response as? HTTPURLResponse {
                        testResult = "连接成功! 状态码: \(httpResponse.statusCode), 响应时间: \(Int(responseTime * 1000))ms"
                    } else {
                        testResult = "连接成功! 响应时间: \(Int(responseTime * 1000))ms"
                    }
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    testResult = "连接失败: \(error.localizedDescription)"
                    isTestingConnection = false
                }
            }
        }
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
}

// MARK: - Preview

@available(iOS 13.0, tvOS 13.0, *)
struct AddProxyServerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AddProxyServerView()

            ProxyServerDetailView(server: ProxyServerConfig(
                name: "香港代理服务器",
                host: "hk-proxy.example.com",
                regions: ["hk", "tw", "mo"]
            ))
        }
        .preferredColorScheme(.dark)
        .previewLayout(.sizeThatFits)
    }
}
