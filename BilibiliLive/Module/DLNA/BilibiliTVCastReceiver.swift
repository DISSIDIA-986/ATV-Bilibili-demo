//
//  BilibiliTVCastReceiver.swift
//  BilibiliLive
//
//  Apple TV投屏接收端实现 - Cast Receiver Implementation
//

import AVFoundation
import CocoaAsyncSocket
import CocoaLumberjackSwift
import Foundation
import Swifter

/// 投屏来源
enum CastSource: String {
    case airPlay = "AirPlay"
    case bilibiliApp = "Bilibili App"
    case cloudTV = "云视听小电视"
    case other = "Other"
}

/// 投屏命令
enum CastCommand {
    case play
    case pause
    case stop
    case seek(to: TimeInterval)
    case volume(to: Float)
    case setVideoURL(String, metadata: [String: Any]?)
    case playBilibiliVideo(aid: Int, cid: Int, metadata: [String: Any]?)
}

/// Bilibili TV投屏接收器 - 使Apple TV能够接收来自手机的投屏
class BilibiliTVCastReceiver: NSObject {
    // MARK: - Properties

    static let shared = BilibiliTVCastReceiver()

    private var httpServer: HttpServer?
    private var discoveryService: NetService?
    private var udpSocket: GCDAsyncUdpSocket?

    var isReceiving = false
    var currentCastSource: CastSource = .other

    // Callbacks
    var onVideoReceived: ((String, String, [String: Any]?) -> Void)?
    var onBilibiliVideoReceived: ((Int, Int, [String: Any]?) -> Void)?
    var onCommandReceived: ((CastCommand) -> Void)?
    var onCastingStateChanged: ((Bool, CastSource) -> Void)?

    private let serviceName = "ATV-Bilibili-Cast-Receiver"
    private let serviceType = "_bilibili-cast._tcp."
    private let httpPort: UInt16 = 9959 // 不同于DLNA的9958端口

    override private init() {
        super.init()
    }

    // MARK: - Service Management

    /// 启动投屏接收服务
    func startCastReceiverService() {
        guard !isReceiving else {
            Logger.info("Cast receiver service already running")
            return
        }

        // 启动HTTP服务器
        startHTTPServer()

        // 启动mDNS服务发现
        startMDNSService()

        // 启动UDP广播响应
        startUDPBroadcastResponder()

        isReceiving = true
        Logger.info("Cast receiver service started on port \(httpPort)")
    }

    /// 停止投屏接收服务
    func stopCastReceiverService() {
        httpServer?.stop()
        discoveryService?.stop()
        udpSocket?.close()

        isReceiving = false
        onCastingStateChanged?(false, currentCastSource)
        Logger.info("Cast receiver service stopped")
    }

    // MARK: - HTTP Server Setup

    private func startHTTPServer() {
        httpServer = HttpServer()

        // 设备信息端点
        httpServer?["/cast/info"] = { [weak self] _ in
            guard let self = self else { return .internalServerError(nil) }
            let info: [String: Any] = [
                "deviceName": UIDevice.current.name,
                "deviceModel": "Apple TV",
                "version": "1.0",
                "capabilities": ["video", "audio", "bilibili"],
                "status": self.isReceiving ? "receiving" : "ready",
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: info, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8)
            {
                return .ok(.json(jsonString))
            }
            return .internalServerError(nil)
        }

        // 播放视频端点 - 通用URL
        httpServer?["/cast/play"] = { [weak self] request in
            guard let self = self,
                  let body = String(data: Data(request.body), encoding: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any]
            else {
                return .badRequest(nil)
            }

            if let url = json["url"] as? String,
               let title = json["title"] as? String
            {
                self.handleVideoURL(url: url, title: title, metadata: json)
                return .ok(.text("OK"))
            }

            return .badRequest(nil)
        }

        // Bilibili视频投屏端点 - AID/CID
        httpServer?["/cast/bilibili"] = { [weak self] request in
            guard let self = self,
                  let body = String(data: Data(request.body), encoding: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any]
            else {
                return .badRequest(nil)
            }

            if let aid = json["aid"] as? Int,
               let cid = json["cid"] as? Int
            {
                self.handleBilibiliVideo(aid: aid, cid: cid, metadata: json)
                return .ok(.text("OK"))
            }

            return .badRequest(nil)
        }

        // 播放控制端点
        httpServer?["/cast/control"] = { [weak self] request in
            guard let self = self,
                  let body = String(data: Data(request.body), encoding: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any],
                  let action = json["action"] as? String
            else {
                return .badRequest(nil)
            }

            self.handleControlCommand(action: action, params: json)
            return .ok(.text("OK"))
        }

        // 状态查询端点
        httpServer?["/cast/status"] = { [weak self] _ in
            guard let self = self else { return .internalServerError(nil) }
            let status: [String: Any] = [
                "isReceiving": self.isReceiving,
                "source": self.currentCastSource.rawValue,
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: status, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8)
            {
                return .ok(.json(jsonString))
            }
            return .internalServerError(nil)
        }

        do {
            try httpServer?.start(httpPort)
            Logger.info("HTTP cast receiver server started on port \(httpPort)")
        } catch {
            Logger.error("Failed to start HTTP server: \(error)")
        }
    }

    // MARK: - mDNS Service Discovery

    private func startMDNSService() {
        discoveryService = NetService(domain: "local.", type: serviceType, name: serviceName, port: Int32(httpPort))
        discoveryService?.delegate = self

        // 设置TXT记录提供设备信息
        let txtData: [String: Data] = [
            "model": "Apple TV".data(using: .utf8)!,
            "version": "1.0".data(using: .utf8)!,
            "capabilities": "video,audio,bilibili".data(using: .utf8)!,
        ]
        discoveryService?.setTXTRecord(NetService.data(fromTXTRecord: txtData))

        discoveryService?.publish()
        Logger.info("mDNS service published: \(serviceName)")
    }

    // MARK: - UDP Broadcast Responder

    private func startUDPBroadcastResponder() {
        udpSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)

        do {
            try udpSocket?.bind(toPort: 1900)
            try udpSocket?.joinMulticastGroup("239.255.255.250")
            try udpSocket?.beginReceiving()
            Logger.info("UDP broadcast responder started on port 1900")
        } catch {
            Logger.error("Failed to start UDP responder: \(error)")
        }
    }

    // MARK: - Video Handling

    private func handleVideoURL(url: String, title: String, metadata: [String: Any]?) {
        Logger.info("Received video URL: \(url), title: \(title)")

        currentCastSource = .bilibiliApp
        onCastingStateChanged?(true, currentCastSource)
        onVideoReceived?(url, title, metadata)
    }

    private func handleBilibiliVideo(aid: Int, cid: Int, metadata: [String: Any]?) {
        Logger.info("Received Bilibili video: aid=\(aid), cid=\(cid)")

        currentCastSource = .bilibiliApp
        onCastingStateChanged?(true, currentCastSource)
        onBilibiliVideoReceived?(aid, cid, metadata)
    }

    // MARK: - Control Commands

    private func handleControlCommand(action: String, params: [String: Any]) {
        Logger.debug("Received control command: \(action)")

        let command: CastCommand?

        switch action {
        case "play":
            command = .play
        case "pause":
            command = .pause
        case "stop":
            command = .stop
            onCastingStateChanged?(false, currentCastSource)
        case "seek":
            if let time = params["time"] as? TimeInterval {
                command = .seek(to: time)
            } else {
                command = nil
            }
        case "volume":
            if let level = params["level"] as? Float {
                command = .volume(to: level)
            } else {
                command = nil
            }
        default:
            command = nil
        }

        if let command = command {
            onCommandReceived?(command)
        }
    }
}

// MARK: - NetServiceDelegate

extension BilibiliTVCastReceiver: NetServiceDelegate {
    func netServiceDidPublish(_ sender: NetService) {
        Logger.info("mDNS service published successfully: \(sender.name)")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        Logger.error("mDNS service failed to publish: \(errorDict)")
    }
}

// MARK: - GCDAsyncUdpSocketDelegate

extension BilibiliTVCastReceiver: GCDAsyncUdpSocketDelegate {
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        guard let message = String(data: data, encoding: .utf8),
              message.contains("M-SEARCH") && message.contains("bilibili-cast")
        else {
            return
        }

        // 响应设备发现请求
        let response = """
        HTTP/1.1 200 OK\r
        CACHE-CONTROL: max-age=1800\r
        LOCATION: http://\(getIPAddress() ?? "localhost"):\(httpPort)/cast/info\r
        SERVER: Apple TV/1.0 UPnP/1.0 Bilibili-Cast/1.0\r
        ST: bilibili-cast:receiver\r
        USN: uuid:\(Settings.uuid)::bilibili-cast:receiver\r
        \r

        """

        if let responseData = response.data(using: .utf8) {
            sock.send(responseData, toAddress: address, withTimeout: 1, tag: 0)
            Logger.debug("Sent discovery response to casting device")
        }
    }

    private func getIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr?.pointee else { return nil }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    if name == "en0" || name == "en1" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                        if name == "en0" {
                            break
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
}
