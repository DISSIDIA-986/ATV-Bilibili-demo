//
//  ProxyServerTests.swift
//  BilibiliLive
//
//  Created by Claude on 2025/1/12.
//

import XCTest
@testable import BilibiliLive

class ProxyServerTests: XCTestCase {
    
    var proxyManager: ProxyServerManager!
    
    override func setUp() {
        super.setUp()
        proxyManager = ProxyServerManager.shared
    }
    
    override func tearDown() {
        proxyManager = nil
        super.tearDown()
    }
    
    // MARK: - Proxy Configuration Tests
    
    func testProxyServerConfigInitialization() {
        let server = ProxyServerConfig(
            name: "测试服务器",
            host: "test.example.com",
            regions: ["hk", "tw"],
            priority: 1
        )
        
        XCTAssertEqual(server.name, "测试服务器")
        XCTAssertEqual(server.host, "test.example.com")
        XCTAssertEqual(server.regions, ["hk", "tw"])
        XCTAssertEqual(server.priority, 1)
        XCTAssertTrue(server.isEnabled)
        XCTAssertEqual(server.reliability, 1.0)
        XCTAssertNil(server.responseTime)
    }
    
    func testProxyServerQualityScore() {
        var server = ProxyServerConfig(
            name: "测试服务器",
            host: "test.example.com",
            regions: ["hk"]
        )
        
        // 测试初始质量分数
        XCTAssertEqual(server.qualityScore, 50.0, accuracy: 0.1)
        
        // 设置响应时间
        server.responseTime = 0.1 // 100ms
        XCTAssertGreaterThan(server.qualityScore, 50.0)
        
        // 设置较差的响应时间
        server.responseTime = 2.0 // 2000ms
        XCTAssertLessThan(server.qualityScore, 50.0)
        
        // 测试可靠性影响
        server.reliability = 0.5
        server.responseTime = 0.1
        let lowReliabilityScore = server.qualityScore
        
        server.reliability = 1.0
        let highReliabilityScore = server.qualityScore
        
        XCTAssertLessThan(lowReliabilityScore, highReliabilityScore)
    }
    
    func testProxyServerStatusDescription() {
        var server = ProxyServerConfig(
            name: "测试服务器",
            host: "test.example.com",
            regions: ["hk"]
        )
        
        // 优秀状态
        server.reliability = 1.0
        server.responseTime = 0.1
        XCTAssertEqual(server.statusDescription, "优秀")
        
        // 较差状态
        server.reliability = 0.2
        server.responseTime = 3.0
        XCTAssertEqual(server.statusDescription, "不可用")
    }
    
    // MARK: - Proxy Manager Tests
    
    func testAddCustomServer() {
        let initialCount = proxyManager.servers.count
        
        proxyManager.addCustomServer(
            name: "自定义服务器",
            host: "custom.example.com",
            regions: ["jp", "kr"]
        )
        
        XCTAssertEqual(proxyManager.servers.count, initialCount + 1)
        
        let addedServer = proxyManager.servers.last!
        XCTAssertEqual(addedServer.name, "自定义服务器")
        XCTAssertEqual(addedServer.host, "custom.example.com")
        XCTAssertEqual(addedServer.regions, ["jp", "kr"])
    }
    
    func testRemoveServer() {
        // 添加测试服务器
        proxyManager.addCustomServer(
            name: "待删除服务器",
            host: "delete.example.com",
            regions: ["test"]
        )
        
        let serverToRemove = proxyManager.servers.last!
        let initialCount = proxyManager.servers.count
        
        proxyManager.removeServer(serverToRemove)
        
        XCTAssertEqual(proxyManager.servers.count, initialCount - 1)
        XCTAssertFalse(proxyManager.servers.contains(where: { $0.id == serverToRemove.id }))
    }
    
    func testToggleServer() {
        // 添加测试服务器
        proxyManager.addCustomServer(
            name: "切换测试服务器",
            host: "toggle.example.com",
            regions: ["test"]
        )
        
        let server = proxyManager.servers.last!
        XCTAssertTrue(server.isEnabled)
        
        proxyManager.toggleServer(server)
        
        let updatedServer = proxyManager.servers.first(where: { $0.id == server.id })!
        XCTAssertFalse(updatedServer.isEnabled)
    }
    
    func testSelectBestServer() {
        // 清空现有服务器
        proxyManager.servers.removeAll()
        
        // 添加测试服务器
        let server1 = ProxyServerConfig(
            name: "服务器1",
            host: "server1.example.com",
            regions: ["hk"],
            priority: 2
        )
        
        var server2 = ProxyServerConfig(
            name: "服务器2",
            host: "server2.example.com",
            regions: ["hk"],
            priority: 1
        )
        server2.responseTime = 0.1
        server2.reliability = 1.0
        
        proxyManager.servers = [server1, server2]
        
        let bestServer = proxyManager.selectBestServer(for: "hk")
        
        // 服务器2应该被选择（更高的质量分数）
        XCTAssertEqual(bestServer?.name, "服务器2")
    }
    
    func testSelectBestServerForRegion() {
        // 清空现有服务器
        proxyManager.servers.removeAll()
        
        let hkServer = ProxyServerConfig(
            name: "香港服务器",
            host: "hk.example.com",
            regions: ["hk"]
        )
        
        let jpServer = ProxyServerConfig(
            name: "日本服务器",
            host: "jp.example.com",
            regions: ["jp"]
        )
        
        proxyManager.servers = [hkServer, jpServer]
        
        let hkBestServer = proxyManager.selectBestServer(for: "hk")
        XCTAssertEqual(hkBestServer?.name, "香港服务器")
        
        let jpBestServer = proxyManager.selectBestServer(for: "jp")
        XCTAssertEqual(jpBestServer?.name, "日本服务器")
        
        let unknownRegionServer = proxyManager.selectBestServer(for: "unknown")
        XCTAssertNil(unknownRegionServer)
    }
    
    func testAutoSelection() {
        proxyManager.isAutoSelection = false
        
        proxyManager.enableAutoSelection()
        
        XCTAssertTrue(proxyManager.isAutoSelection)
        XCTAssertNotNil(proxyManager.currentServer)
    }
    
    // MARK: - Statistics Tests
    
    func testGetStatistics() {
        // 确保有一些测试数据
        if proxyManager.servers.isEmpty {
            proxyManager.addCustomServer(
                name: "统计测试服务器",
                host: "stats.example.com",
                regions: ["test"]
            )
        }
        
        let stats = proxyManager.getStatistics()
        
        XCTAssertGreaterThan(stats.totalServers, 0)
        XCTAssertGreaterThanOrEqual(stats.enabledServers, 0)
        XCTAssertGreaterThanOrEqual(stats.workingServers, 0)
        XCTAssertGreaterThanOrEqual(stats.averageResponseTime, 0)
        XCTAssertGreaterThanOrEqual(stats.currentServerQuality, 0)
    }
    
    // MARK: - WebRequest Integration Tests
    
    func testSmartProxyIntegration() {
        // 这个测试验证智能代理选择的集成
        let expectation = XCTestExpectation(description: "智能代理选择")
        
        Task {
            do {
                // 模拟智能代理选择
                let bestServer = proxyManager.selectBestServer(for: "hk")
                XCTAssertNotNil(bestServer)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceOfServerSelection() {
        // 添加大量服务器进行性能测试
        for i in 0..<100 {
            proxyManager.addCustomServer(
                name: "性能测试服务器\(i)",
                host: "perf\(i).example.com",
                regions: ["test"]
            )
        }
        
        measure {
            // 测试服务器选择的性能
            for _ in 0..<10 {
                _ = proxyManager.selectBestServer(for: "test")
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandlingForInvalidServer() {
        // 测试无效服务器配置的错误处理
        let invalidServer = ProxyServerConfig(
            name: "",
            host: "",
            regions: []
        )
        
        // 验证无效配置不会导致崩溃
        XCTAssertEqual(invalidServer.qualityScore, 50.0, accuracy: 0.1)
        XCTAssertEqual(invalidServer.statusDescription, "一般")
    }
    
    func testNoAvailableServers() {
        // 清空所有服务器
        proxyManager.servers.removeAll()
        
        let bestServer = proxyManager.selectBestServer()
        XCTAssertNil(bestServer)
        
        let stats = proxyManager.getStatistics()
        XCTAssertEqual(stats.totalServers, 0)
        XCTAssertEqual(stats.enabledServers, 0)
        XCTAssertEqual(stats.workingServers, 0)
    }
    
    // MARK: - Settings Integration Tests
    
    func testSettingsIntegration() {
        // 测试设置集成
        let originalSmartSelection = Settings.proxySmartSelection
        let originalAutoFailover = Settings.proxyAutoFailover
        
        Settings.proxySmartSelection = true
        Settings.proxyAutoFailover = true
        
        XCTAssertTrue(Settings.proxySmartSelection)
        XCTAssertTrue(Settings.proxyAutoFailover)
        
        // 恢复原始设置
        Settings.proxySmartSelection = originalSmartSelection
        Settings.proxyAutoFailover = originalAutoFailover
    }
}