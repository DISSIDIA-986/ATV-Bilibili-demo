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
            // 港澳台地区 - 高优先级
            ProxyServerConfig(
                name: "香港节点",
                host: "api-hk.biliapi.net",
                regions: ["hk", "tw", "mo"],
                priority: 1
            ),
            ProxyServerConfig(
                name: "台湾节点", 
                host: "api-tw.biliapi.net",
                regions: ["tw", "hk", "mo"],
                priority: 2
            ),
            ProxyServerConfig(
                name: "澳门节点",
                host: "api-mo.biliapi.net", 
                regions: ["mo", "hk", "tw"],
                priority: 3
            ),
            
            // 东南亚地区
            ProxyServerConfig(
                name: "新加坡节点",
                host: "api-sg.biliapi.net",
                regions: ["sg", "my", "th", "ph"],
                priority: 4
            ),
            ProxyServerConfig(
                name: "泰国节点",
                host: "api-th.biliapi.net",
                regions: ["th", "sg", "my"],
                priority: 5
            ),
            ProxyServerConfig(
                name: "马来西亚节点",
                host: "api-my.biliapi.net",
                regions: ["my", "sg", "th"],
                priority: 6
            ),
            ProxyServerConfig(
                name: "菲律宾节点",
                host: "api-ph.biliapi.net",
                regions: ["ph", "sg", "th"],
                priority: 7
            ),
            
            // 东北亚地区
            ProxyServerConfig(
                name: "日本节点",
                host: "api-jp.biliapi.net",
                regions: ["jp"],
                priority: 8
            ),
            ProxyServerConfig(
                name: "韩国节点",
                host: "api-kr.biliapi.net",
                regions: ["kr", "jp"],
                priority: 9
            ),
            
            // 北美地区
            ProxyServerConfig(
                name: "美国西部节点",
                host: "api-us-west.biliapi.net",
                regions: ["us", "ca"],
                priority: 10
            ),
            ProxyServerConfig(
                name: "美国东部节点",
                host: "api-us-east.biliapi.net",
                regions: ["us", "ca"],
                priority: 11
            ),
            ProxyServerConfig(
                name: "加拿大节点",
                host: "api-ca.biliapi.net",
                regions: ["ca", "us"],
                priority: 12
            ),
            
            // 欧洲地区
            ProxyServerConfig(
                name: "英国节点",
                host: "api-uk.biliapi.net",
                regions: ["uk", "de", "fr"],
                priority: 13
            ),
            ProxyServerConfig(
                name: "德国节点",
                host: "api-de.biliapi.net",
                regions: ["de", "uk", "fr"],
                priority: 14
            ),
            ProxyServerConfig(
                name: "法国节点",
                host: "api-fr.biliapi.net",
                regions: ["fr", "uk", "de"],
                priority: 15
            ),
            
            // 大洋洲地区
            ProxyServerConfig(
                name: "澳大利亚节点",
                host: "api-au.biliapi.net",
                regions: ["au", "nz"],
                priority: 16
            ),
            ProxyServerConfig(
                name: "新西兰节点",
                host: "api-nz.biliapi.net",
                regions: ["nz", "au"],
                priority: 17
            ),
            
            // 备用全球节点
            ProxyServerConfig(
                name: "全球备用节点1",
                host: "api-global1.biliapi.net",
                regions: ["hk", "tw", "mo", "sg", "jp", "kr", "us", "uk"],
                priority: 20,
                isEnabled: false
            ),
            ProxyServerConfig(
                name: "全球备用节点2",
                host: "api-global2.biliapi.net",
                regions: ["hk", "tw", "mo", "sg", "jp", "kr", "us", "uk"],
                priority: 21,
                isEnabled: false
            ),
            
            // CDN 节点
            ProxyServerConfig(
                name: "CloudFlare CDN",
                host: "api-cf.biliapi.net",
                regions: ["global"],
                priority: 25,
                isEnabled: false
            ),
            ProxyServerConfig(
                name: "AWS CloudFront",
                host: "api-aws.biliapi.net", 
                regions: ["global"],
                priority: 26,
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
                server.isEnabled && (server.regions.contains(region) || server.regions.contains("global"))
            }
        } else {
            availableServers = servers.filter { $0.isEnabled }
        }
        
        guard !availableServers.isEmpty else {
            Logger.warn("没有可用的代理服务器")
            return nil
        }
        
        // 获取当前网络质量
        let networkQuality = NetworkQualityDetector.shared.currentQuality
        let networkMetrics = NetworkQualityDetector.shared.metrics
        
        // 根据网络质量和服务器状态计算综合评分
        let sortedServers = availableServers.sorted { server1, server2 in
            let score1 = calculateServerScore(server1, networkQuality: networkQuality, networkMetrics: networkMetrics, targetRegion: region)
            let score2 = calculateServerScore(server2, networkQuality: networkQuality, networkMetrics: networkMetrics, targetRegion: region)
            return score1 > score2
        }
        
        let bestServer = sortedServers.first!
        
        if isAutoSelection {
            // 检查是否需要切换服务器
            if let current = currentServer {
                let currentScore = calculateServerScore(current, networkQuality: networkQuality, networkMetrics: networkMetrics, targetRegion: region)
                let bestScore = calculateServerScore(bestServer, networkQuality: networkQuality, networkMetrics: networkMetrics, targetRegion: region)
                
                // 只有在新服务器显著更好时才切换（避免频繁切换）
                if bestScore > currentScore + 10.0 {
                    currentServer = bestServer
                    saveSettings()
                    Logger.info("智能切换代理服务器: \(current.name) → \(bestServer.name)")
                }
            } else {
                currentServer = bestServer
                saveSettings()
            }
        }
        
        Logger.info("选择代理服务器: \(bestServer.name) (评分: \(String(format: "%.1f", calculateServerScore(bestServer, networkQuality: networkQuality, networkMetrics: networkMetrics, targetRegion: region))))")
        return bestServer
    }
    
    /// 计算服务器综合评分
    private func calculateServerScore(_ server: ProxyServerConfig, networkQuality: NetworkQuality, networkMetrics: NetworkQualityMetrics?, targetRegion: String?) -> Double {
        var score: Double = 0
        
        // 基础可靠性评分 (30% 权重)
        score += server.reliability * 30.0
        
        // 响应时间评分 (25% 权重)
        if let responseTime = server.responseTime {
            let timeScore = max(0, 25 - (responseTime * 5))
            score += timeScore
        } else {
            // 没有响应时间数据，给予中等评分
            score += 12.5
        }
        
        // 质量评分 (20% 权重) 
        score += server.qualityScore * 0.2
        
        // 地区匹配加分 (15% 权重)
        if let region = targetRegion {
            if server.regions.first == region {
                score += 15.0  // 首选地区
            } else if server.regions.contains(region) {
                score += 10.0  // 支持地区
            } else if server.regions.contains("global") {
                score += 5.0   // 全球节点
            }
        } else {
            score += 10.0  // 无特定地区要求
        }
        
        // 优先级加分 (10% 权重) - 优先级越低数字越小，评分越高
        let priorityScore = max(0, 10 - Double(server.priority) * 0.5)
        score += priorityScore
        
        // 网络质量适应性调整
        if let metrics = networkMetrics {
            // 根据当前网络状况调整评分
            switch networkQuality {
            case .excellent:
                // 网络优秀时，偏好响应时间更快的服务器
                if let responseTime = server.responseTime, responseTime < 0.1 {
                    score += 5.0
                }
            case .good:
                // 网络良好时，平衡响应时间和可靠性
                score += server.reliability * 2.0
            case .fair:
                // 网络一般时，偏好可靠性更高的服务器
                score += server.reliability * 5.0
            case .poor:
                // 网络较差时，强烈偏好最可靠的服务器
                score += server.reliability * 8.0
                // 对高延迟服务器减分更少
                if let responseTime = server.responseTime, responseTime > 1.0 {
                    score -= 2.0  // 较小的惩罚
                }
            case .unknown:
                // 网络状况未知，使用默认评分
                break
            }
        }
        
        // 最近检查时间加分
        if let lastChecked = server.lastChecked {
            let timeSinceCheck = Date().timeIntervalSince(lastChecked)
            if timeSinceCheck < 300 { // 5分钟内
                score += 3.0
            } else if timeSinceCheck < 900 { // 15分钟内
                score += 1.0
            }
        }
        
        return max(0, score)
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
        var isHealthy = false
        var responseTime: TimeInterval = 0
        
        // 多种健康检查方式
        let checkMethods = [
            ("health", "https://\(server.host)/health"),
            ("ping", "https://\(server.host)/ping"), 
            ("api", "https://\(server.host)/x/web-interface/nav"),
            ("fallback", "https://\(server.host)")
        ]
        
        for (method, urlString) in checkMethods {
            do {
                guard let url = URL(string: urlString) else { continue }
                
                var request = URLRequest(url: url)
                request.timeoutInterval = 8.0
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("BilibiliLive/1.0", forHTTPHeaderField: "User-Agent")
                
                let checkStart = Date()
                let (_, response) = try await URLSession.shared.data(for: request)
                responseTime = Date().timeIntervalSince(checkStart)
                
                if let httpResponse = response as? HTTPURLResponse {
                    // 更宽松的成功条件
                    if httpResponse.statusCode < 500 {
                        isHealthy = true
                        Logger.debug("代理服务器健康检查成功: \(server.name) (\(method)) - \(httpResponse.statusCode) - \(Int(responseTime * 1000))ms")
                        break
                    }
                }
                
            } catch {
                Logger.debug("代理服务器检查方法失败: \(server.name) (\(method)) - \(error)")
                continue
            }
        }
        
        // 如果所有方法都失败，尝试网络质量检测集成
        if !isHealthy {
            let networkQuality = NetworkQualityDetector.shared.currentQuality
            // 根据网络质量调整判断标准
            let toleranceMultiplier = networkQuality == .poor ? 0.3 : 0.6
            
            // 尝试最后一次简化检查
            do {
                let url = URL(string: "https://\(server.host)")!
                var request = URLRequest(url: url)
                request.timeoutInterval = 15.0
                
                let checkStart = Date()
                let (_, response) = try await URLSession.shared.data(for: request)
                responseTime = Date().timeIntervalSince(checkStart)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 600 {
                    isHealthy = true
                    Logger.debug("代理服务器容错检查通过: \(server.name) - \(Int(responseTime * 1000))ms")
                }
            } catch {
                responseTime = Date().timeIntervalSince(startTime)
                Logger.warn("代理服务器完全不可达: \(server.name) - \(error)")
            }
        }
        
        // 更新服务器状态
        await MainActor.run {
            if let index = servers.firstIndex(where: { $0.id == server.id }) {
                servers[index].lastChecked = Date()
                
                if isHealthy {
                    servers[index].responseTime = responseTime
                    // 渐进式改善可靠性
                    servers[index].reliability = min(1.0, servers[index].reliability + 0.15)
                } else {
                    servers[index].responseTime = nil
                    // 渐进式降低可靠性
                    servers[index].reliability = max(0.0, servers[index].reliability - 0.25)
                }
                
                // 如果服务器持续不可用，自动禁用
                if servers[index].reliability < 0.1 && servers[index].isEnabled {
                    Logger.warn("代理服务器可靠性过低，自动禁用: \(server.name)")
                    servers[index].isEnabled = false
                    
                    // 如果是当前使用的服务器，触发切换
                    if currentServer?.id == server.id {
                        Task { @MainActor in
                            selectBestServer()
                        }
                    }
                }
            }
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