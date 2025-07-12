//
//  ProxyServerManager.swift
//  BilibiliLive
//
//  Created by Claude on 2025/1/12.
//

import Foundation
import Combine

/// 地区限制代理服务器配置
struct ProxyServerConfig: Codable, Identifiable, Hashable {
    let id = UUID()
    let name: String
    let host: String
    let regions: [String]
    let priority: Int
    var isEnabled: Bool
    var responseTime: TimeInterval?
    var reliability: Double
    var lastChecked: Date?
    
    init(name: String, host: String, regions: [String], priority: Int = 0, isEnabled: Bool = true) {
        self.name = name
        self.host = host
        self.regions = regions
        self.priority = priority
        self.isEnabled = isEnabled
        self.reliability = 1.0
        self.lastChecked = nil
        self.responseTime = nil
    }
    
    /// 服务器状态评分 (0-100)
    var qualityScore: Double {
        var score = reliability * 50.0
        
        if let responseTime = responseTime {
            // 响应时间越快分数越高 (最大50分)
            let timeScore = max(0, 50 - (responseTime * 10))
            score += timeScore
        }
        
        return min(100, max(0, score))
    }
    
    /// 服务器状态描述
    var statusDescription: String {
        let score = qualityScore
        switch score {
        case 80...100:
            return "优秀"
        case 60..<80:
            return "良好"
        case 40..<60:
            return "一般"
        case 20..<40:
            return "较差"
        default:
            return "不可用"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case name, host, regions, priority, isEnabled, responseTime, reliability, lastChecked
    }
}

/// 代理服务器管理器
class ProxyServerManager: ObservableObject {
    static let shared = ProxyServerManager()
    
    @Published var servers: [ProxyServerConfig] = []
    @Published var currentServer: ProxyServerConfig?
    @Published var isAutoSelection = true
    
    private let userDefaults = UserDefaults.standard
    private let serversKey = "ProxyServerManager.servers"
    private let currentServerKey = "ProxyServerManager.currentServer"
    private let autoSelectionKey = "ProxyServerManager.autoSelection"
    
    private var healthCheckTimer: Timer?
    private let healthCheckInterval: TimeInterval = 300 // 5分钟
    
    private init() {
        loadSettings()
        initializeDefaultServers()
        startHealthCheck()
    }
    
    deinit {
        healthCheckTimer?.invalidate()
    }
    
    // MARK: - Default Servers Configuration
    
    private func initializeDefaultServers() {
        if servers.isEmpty {
            servers = createDefaultServers()
            saveSettings()
        }
    }
    
    private func createDefaultServers() -> [ProxyServerConfig] {
        return [
            // 港澳台服务器
            ProxyServerConfig(
                name: "香港代理服务器",
                host: "hk-proxy.example.com",
                regions: ["hk", "tw", "mo"],
                priority: 1
            ),
            ProxyServerConfig(
                name: "台湾代理服务器",
                host: "tw-proxy.example.com", 
                regions: ["tw", "hk"],
                priority: 2
            ),
            
            // 东南亚服务器
            ProxyServerConfig(
                name: "新加坡代理服务器",
                host: "sg-proxy.example.com",
                regions: ["sg", "my", "th"],
                priority: 3
            ),
            ProxyServerConfig(
                name: "泰国代理服务器",
                host: "th-proxy.example.com",
                regions: ["th", "sg"],
                priority: 4
            ),
            
            // 其他地区服务器
            ProxyServerConfig(
                name: "日本代理服务器",
                host: "jp-proxy.example.com",
                regions: ["jp"],
                priority: 5
            ),
            ProxyServerConfig(
                name: "韩国代理服务器",
                host: "kr-proxy.example.com",
                regions: ["kr"],
                priority: 6
            ),
            
            // 通用备用服务器
            ProxyServerConfig(
                name: "通用备用服务器",
                host: "backup-proxy.example.com",
                regions: ["hk", "tw", "mo", "sg", "my", "th", "jp", "kr"],
                priority: 10,
                isEnabled: false
            )
        ]
    }
    
    // MARK: - Server Management
    
    /// 添加自定义代理服务器
    func addCustomServer(name: String, host: String, regions: [String]) {
        let server = ProxyServerConfig(
            name: name,
            host: host,
            regions: regions,
            priority: servers.count
        )
        servers.append(server)
        saveSettings()
        
        // 立即检查新服务器健康状态
        Task {
            await checkServerHealth(server)
        }
    }
    
    /// 移除代理服务器
    func removeServer(_ server: ProxyServerConfig) {
        servers.removeAll { $0.id == server.id }
        
        if currentServer?.id == server.id {
            currentServer = nil
            selectBestServer()
        }
        
        saveSettings()
    }
    
    /// 更新服务器配置
    func updateServer(_ server: ProxyServerConfig) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
            saveSettings()
        }
    }
    
    /// 启用/禁用服务器
    func toggleServer(_ server: ProxyServerConfig) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index].isEnabled.toggle()
            saveSettings()
            
            // 如果禁用的是当前服务器，重新选择
            if !servers[index].isEnabled && currentServer?.id == server.id {
                selectBestServer()
            }
        }
    }
    
    // MARK: - Server Selection
    
    /// 为指定地区选择最佳代理服务器
    func selectBestServer(for region: String? = nil) -> ProxyServerConfig? {
        let availableServers: [ProxyServerConfig]
        
        if let region = region {
            availableServers = servers.filter { server in
                server.isEnabled && server.regions.contains(region)
            }
        } else {
            availableServers = servers.filter { $0.isEnabled }
        }
        
        guard !availableServers.isEmpty else {
            Logger.warn("没有可用的代理服务器")
            return nil
        }
        
        // 按质量分数和优先级排序
        let sortedServers = availableServers.sorted { server1, server2 in
            if server1.qualityScore != server2.qualityScore {
                return server1.qualityScore > server2.qualityScore
            }
            return server1.priority < server2.priority
        }
        
        let bestServer = sortedServers.first!
        
        if isAutoSelection {
            currentServer = bestServer
            saveSettings()
        }
        
        Logger.info("选择代理服务器: \(bestServer.name) (质量分数: \(Int(bestServer.qualityScore)))")
        return bestServer
    }
    
    /// 手动设置当前服务器
    func setCurrentServer(_ server: ProxyServerConfig?) {
        currentServer = server
        isAutoSelection = false
        saveSettings()
    }
    
    /// 启用自动选择
    func enableAutoSelection() {
        isAutoSelection = true
        selectBestServer()
    }
    
    // MARK: - Health Check
    
    private func startHealthCheck() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performHealthCheck()
            }
        }
    }
    
    @MainActor
    private func performHealthCheck() async {
        Logger.info("开始代理服务器健康检查")
        
        await withTaskGroup(of: Void.self) { group in
            for server in servers where server.isEnabled {
                group.addTask {
                    await self.checkServerHealth(server)
                }
            }
        }
        
        // 如果当前服务器不可用，自动切换到最佳服务器
        if let current = currentServer, current.qualityScore < 20 {
            Logger.warn("当前代理服务器质量过低，自动切换")
            selectBestServer()
        }
        
        saveSettings()
    }
    
    private func checkServerHealth(_ server: ProxyServerConfig) async {
        let startTime = Date()
        
        do {
            // 使用简单的HTTP请求测试代理服务器
            let testUrl = "https://\(server.host)/health"
            var request = URLRequest(url: URL(string: testUrl)!)
            request.timeoutInterval = 10.0
            
            let (_, response) = try await URLSession.shared.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                if let index = servers.firstIndex(where: { $0.id == server.id }) {
                    servers[index].responseTime = responseTime
                    servers[index].lastChecked = Date()
                    
                    // 更新可靠性评分
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                        servers[index].reliability = min(1.0, servers[index].reliability + 0.1)
                    } else {
                        servers[index].reliability = max(0.0, servers[index].reliability - 0.2)
                    }
                }
            }
            
            Logger.debug("代理服务器健康检查: \(server.name) - 响应时间: \(Int(responseTime * 1000))ms")
            
        } catch {
            await MainActor.run {
                if let index = servers.firstIndex(where: { $0.id == server.id }) {
                    servers[index].responseTime = nil
                    servers[index].lastChecked = Date()
                    servers[index].reliability = max(0.0, servers[index].reliability - 0.3)
                }
            }
            
            Logger.warn("代理服务器健康检查失败: \(server.name) - \(error)")
        }
    }
    
    // MARK: - Settings Persistence
    
    private func saveSettings() {
        do {
            let serversData = try JSONEncoder().encode(servers)
            userDefaults.set(serversData, forKey: serversKey)
            
            if let currentServer = currentServer {
                let currentServerData = try JSONEncoder().encode(currentServer)
                userDefaults.set(currentServerData, forKey: currentServerKey)
            } else {
                userDefaults.removeObject(forKey: currentServerKey)
            }
            
            userDefaults.set(isAutoSelection, forKey: autoSelectionKey)
        } catch {
            Logger.error("保存代理服务器设置失败: \(error)")
        }
    }
    
    private func loadSettings() {
        // 加载服务器列表
        if let serversData = userDefaults.data(forKey: serversKey) {
            do {
                servers = try JSONDecoder().decode([ProxyServerConfig].self, from: serversData)
            } catch {
                Logger.error("加载代理服务器设置失败: \(error)")
                servers = []
            }
        }
        
        // 加载当前服务器
        if let currentServerData = userDefaults.data(forKey: currentServerKey) {
            do {
                currentServer = try JSONDecoder().decode(ProxyServerConfig.self, from: currentServerData)
            } catch {
                Logger.error("加载当前代理服务器设置失败: \(error)")
                currentServer = nil
            }
        }
        
        // 加载自动选择设置
        isAutoSelection = userDefaults.bool(forKey: autoSelectionKey)
    }
    
    // MARK: - Statistics
    
    /// 获取代理服务器统计信息
    func getStatistics() -> ProxyStatistics {
        let enabledServers = servers.filter { $0.isEnabled }
        let workingServers = enabledServers.filter { $0.qualityScore > 50 }
        let averageResponseTime = enabledServers.compactMap { $0.responseTime }.reduce(0, +) / Double(max(1, enabledServers.count))
        
        return ProxyStatistics(
            totalServers: servers.count,
            enabledServers: enabledServers.count,
            workingServers: workingServers.count,
            averageResponseTime: averageResponseTime,
            currentServerQuality: currentServer?.qualityScore ?? 0
        )
    }
}

/// 代理服务器统计信息
struct ProxyStatistics {
    let totalServers: Int
    let enabledServers: Int
    let workingServers: Int
    let averageResponseTime: TimeInterval
    let currentServerQuality: Double
}

// MARK: - WebRequest Integration

extension WebRequest {
    
    /// 使用智能代理选择的地区限制播放请求
    static func requestAreaLimitPcgPlayUrlSmart(epid: Int, cid: Int, area: String) async throws -> VideoPlayURLInfo {
        let proxyManager = ProxyServerManager.shared
        
        guard let proxyServer = proxyManager.selectBestServer(for: area) else {
            throw ValidationError.argumentInvalid(message: "没有可用的代理服务器")
        }
        
        return try await requestAreaLimitPcgPlayUrlWithProxy(epid: epid, cid: cid, area: area, proxyServer: proxyServer)
    }
    
    /// 使用指定代理服务器的地区限制播放请求
    static func requestAreaLimitPcgPlayUrlWithProxy(epid: Int, cid: Int, area: String, proxyServer: ProxyServerConfig) async throws -> VideoPlayURLInfo {
        let quality = Settings.mediaQuality
        
        // 使用选定的代理服务器
        let url = EndPoint.pcgPlayUrl.replacingOccurrences(of: "api.bilibili.com", with: proxyServer.host)
        var parameters: [String: Any] = ["ep_id": epid, "cid": cid, "qn": quality.qn, "support_multi_audio": 1, "fnver": 0, "fnval": quality.fnval, "fourk": 1, "area": area]
        
        if let access_key = ApiRequest.getToken()?.accessToken {
            parameters["access_key"] = access_key
        }
        parameters["appkey"] = ApiRequest.appkey
        parameters["local_id"] = 0
        parameters["mobi_app"] = "android"
        
        Logger.info("使用代理服务器: \(proxyServer.name) 请求地区限制内容")
        
        return try await request(url: url, parameters: parameters, dataObj: "result")
    }
}