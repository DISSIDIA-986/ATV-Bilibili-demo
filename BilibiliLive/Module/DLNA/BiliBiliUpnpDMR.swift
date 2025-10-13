//
//  BiliBiliUpnpDMR.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/11/25.
//

import CocoaAsyncSocket
import CoreMedia
import Foundation
import Swifter
import SwiftyJSON
import UIKit

class BiliBiliUpnpDMR: NSObject {
    static let shared = BiliBiliUpnpDMR()

    weak var currentPlugin: BUpnpPlugin?

    private var udp: GCDAsyncUdpSocket!
    private var httpServer = HttpServer()
    private var connectedSockets = [GCDAsyncSocket]()
    @MainActor private var sessions = Set<NVASession>()
    private var started = false
    private var ip: String?
    private var boardcastTimer: Timer?

    // CloudTV Integration (deprecated - wrong sender implementation)
    private var cloudTVHandler: CloudTVProtocolHandler?
    private var discoveredCloudTVDevices: [BilibiliTVDevice] = []
    private var currentCloudTVDevice: BilibiliTVDevice?

    // Cast Receiver Integration (correct implementation)
    private var castReceiver: BilibiliTVCastReceiver?

    private lazy var serverInfo: String = {
        let file = Bundle.main.url(forResource: "DLNAInfo", withExtension: "xml")!
        return try! String(contentsOf: file).replacingOccurrences(of: "{{UUID}}", with: bUuid)
    }()

    private lazy var nirvanaControl: String = {
        let file = Bundle.main.url(forResource: "NirvanaControl", withExtension: "xml")!
        return try! String(contentsOf: file)
    }()

    private lazy var avTransportScpd: String = {
        let file = Bundle.main.url(forResource: "AvTransportScpd", withExtension: "xml")!
        return try! String(contentsOf: file)
    }()

    private lazy var bUuid: String = {
        if Settings.uuid.count > 0 {
            return Settings.uuid
        }
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString = ""
        for _ in 0..<35 {
            let rand = arc4random_uniform(36)
            let nextChar = letters[letters.index(letters.startIndex, offsetBy: Int(rand))]
            randomString.append(nextChar)
        }
        Settings.uuid = randomString
        return randomString
    }()

    override private init() { super.init() }
    func start() {
        startIfNeed()
        initializeCastReceiver()
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)

        httpServer["/description.xml"] = { [weak self] req in
            Logger.debug("handel serverInfo")
            return HttpResponse.ok(.text(self?.serverInfo ?? ""))
        }

        httpServer["projection"] = nvasocket(uuid: bUuid, didConnect: { [weak self] session in
            Logger.info("session connected \(session)")
            DispatchQueue.main.async {
                self?.sessions.insert(session)
            }
        }, didDisconnect: { [weak self] session in
            Logger.info("session disconnect \(session)")
            DispatchQueue.main.async {
                self?.sessions.remove(session)
            }
        }, processor: { [weak self] session, frame in
            DispatchQueue.main.async {
                self?.handleEvent(frame: frame, session: session)
            }
        })

        httpServer["/dlna/NirvanaControl.xml"] = {
            [weak self] req in
            Logger.debug("handle NirvanaControl")
            let txt = self?.nirvanaControl ?? ""
            return HttpResponse.ok(.text(txt))
        }

        httpServer.get["/dlna/AVTransport.xml"] = {
            [weak self] req in
            Logger.debug("handle AVTransport.xml")
            let txt = self?.avTransportScpd ?? ""
            return HttpResponse.ok(.text(txt))
        }

        httpServer.post["/AVTransport/action"] = {
            req in
            let str = String(data: Data(req.body), encoding: .utf8) ?? ""
            Logger.debug("handle AVTransport.xml \(str)")
            return HttpResponse.ok(.text(str))
        }

        httpServer["AVTransport/event"] = {
            req in
            return HttpResponse.internalServerError(nil)
        }

        httpServer["/debug/log"] = {
            req in
            if let path = Logger.latestLogPath(),
               let str = try? String(contentsOf: URL(fileURLWithPath: path))
            {
                return HttpResponse.ok(.text(str))
            }
            return HttpResponse.internalServerError(nil)
        }

        httpServer["/debug/old"] = {
            req in
            if let path = Logger.oldestLogPath(),
               let str = try? String(contentsOf: URL(fileURLWithPath: path))
            {
                return HttpResponse.ok(.text(str))
            }
            return HttpResponse.internalServerError(nil)
        }
    }

    func stop() {
        boardcastTimer?.invalidate()
        boardcastTimer = nil
        udp?.close()
        httpServer.stop()
        castReceiver?.stopCastReceiverService()
        started = false
        Logger.info("dmr stopped")
    }

    @objc func didEnterBackground() {
        stop()
    }

    @objc func willEnterForeground() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startIfNeed()
        }
    }

    private func startIfNeed() {
        stop()
        guard Settings.enableDLNA else { return }
        ip = getIPAddress()
        if !started {
            do {
                udp = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
                try udp.enableBroadcast(true)
                try udp.bind(toPort: 1900)
                try udp.joinMulticastGroup("239.255.255.250")
                try udp.beginReceiving()
                try httpServer.start(9958)
                started = true
                Logger.info("dmr started")
            } catch let err {
                started = false
                Logger.warn("dmr start fail: \(err.localizedDescription)")
            }
        }
        boardcastTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] _ in
            guard let self else { return }
            if let data = getSSDPNotify().data(using: .utf8) {
                udp.send(data, toHost: "239.255.255.250", port: 1900, withTimeout: 1, tag: 0)
            }
        }
    }

    private func getIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr?.pointee else { return "" }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    if name == "en0" || name == "en1" || name == "en2" || name == "en3" || name == "en4" {
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

    private func getSSDPResp() -> String {
        guard let ip = ip ?? getIPAddress() else {
            Logger.debug("no ip")
            return ""
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "E, d MMM yyyy HH:mm:ss"
        return """
        HTTP/1.1 200 OK
        LOCATION: http://\(ip):9958/description.xml
        CACHE-CONTROL: max-age=30
        SERVER: Linux/3.0.0, UPnP/1.0, Platinum/1.0.5.13
        EXT:
        BOOTID.UPNP.ORG: 1669443520
        CONFIGID.UPNP.ORG: 10177363
        USN: uuid:atvbilibili&\(bUuid)::upnp:rootdevice
        ST: upnp:rootdevice
        DATE: \(formatter.string(from: Date())) GMT

        """
    }

    private func getSSDPNotify() -> String {
        guard let ip = ip ?? getIPAddress() else {
            Logger.debug("no ip")
            return ""
        }
        // 修改Server标识以匹配Bilibili App期望 (Modify Server identifier to match Bilibili App expectations)
        let text = """
        NOTIFY * HTTP/1.1
        Host: 239.255.255.250:1900
        Location: http://\(ip):9958/description.xml
        Cache-Control: max-age=30
        Server: BilibiliDLNA/2.0 UPnP/1.0 BilibiliTV/1.0
        NTS: ssdp:alive
        USN: uuid:\(bUuid)::urn:schemas-upnp-org:device:MediaRenderer:1
        NT: urn:schemas-upnp-org:device:MediaRenderer:1

        """
        return text
    }

    func handleEvent(frame: NVASession.NVAFrame, session: NVASession) {
        let topMost = UIViewController.topMostViewController()
        switch frame.action {
        case "GetVolume":
            session.sendReply(content: ["volume": 30])
        case "Play":
            handlePlay(json: JSON(parseJSON: frame.body))
            session.sendEmpty()
        case "Pause":
            currentPlugin?.pause()
            session.sendEmpty()
        case "Resume":
            currentPlugin?.resume()
            session.sendEmpty()
        case "SwitchDanmaku":
            let json = JSON(parseJSON: frame.body)
            Defaults.shared.showDanmu = json["open"].boolValue
            session.sendEmpty()
        case "Seek":
            let json = JSON(parseJSON: frame.body)
            currentPlugin?.seek(to: json["seekTs"].doubleValue)
            session.sendEmpty()
        case "Stop":
            (topMost as? CommonPlayerViewController)?.dismiss(animated: true)
            session.sendEmpty()
        case "PlayUrl":
            let json = JSON(parseJSON: frame.body)
            session.sendEmpty()
            guard let url = json["url"].url,
                  let extStr = URLComponents(string: url.absoluteString)?.queryItems?
                  .first(where: { $0.name == "nva_ext" })?.value
            else {
                Logger.warn("get play url: \(frame.body)")
                return
            }
            let ext = JSON(parseJSON: extStr)
            handlePlay(json: ext["content"])
        default:
            Logger.debug("action: \(frame.action)")
            session.sendEmpty()
        }
    }

    func handlePlay(json: JSON) {
        let roomId = json["roomId"].stringValue
        if roomId.count > 0, let room = Int(roomId), room > 0 {
            playLive(roomID: room)
        } else {
            playVideo(json: json)
        }
    }

    enum PlayStatus: Int {
        case loading = 3
        case playing = 4
        case paused = 5
        case end = 6
        case stop = 7
    }

    @MainActor func sendStatus(status: PlayStatus) {
        Logger.debug("send status: \(status)")
        Array(sessions).forEach { $0.sendCommand(action: "OnPlayState", content: ["playState": status.rawValue]) }
    }

    @MainActor func sendProgress(duration: Int, current: Int) {
        Array(sessions).forEach { $0.sendCommand(action: "OnProgress", content: ["duration": duration, "position": current]) }
    }

    func sendVideoSwitch(aid: Int, cid: Int) {
        /* this might cause client disconnect for unkown reason
         let playItem = ["aid": aid, "cid": cid, "contentType": 0, "epId": 0, "seasonId": 0, "roomId": 0] as [String: Any]
         let mockQnDesc = ["curQn": 0,
                           "supportQnList": [
                               [
                                   "description": "",
                                   "displayDesc": "",
                                   "needLogin": false,
                                   "needVip": false,
                                   "quality": 0,
                                   "superscript": "",
                               ],
                           ],
                           "userDesireQn": 0] as [String: Any]
         let data = ["playItem": playItem, "qnDesc": mockQnDesc, "title": "null"] as [String: Any]
         Array(sessions).forEach { $0.sendCommand(action: "OnEpisodeSwitch", content: data) }
          */
    }
}

extension BiliBiliUpnpDMR {
    func playLive(roomID: Int) {
        let player = LivePlayerViewController()
        player.room = LiveRoom(title: "", room_id: roomID, uname: "", keyframe: nil, face: nil, cover_from_user: nil)
        UIViewController.topMostViewController().present(player, animated: true)
    }

    func playVideo(json: JSON) {
        let aid = json["aid"].intValue
        let cid = json["cid"].intValue
        let epid = json["epid"].intValue

        let player: VideoDetailViewController
        if epid > 0 {
            player = VideoDetailViewController.create(epid: epid)
        } else {
            player = VideoDetailViewController.create(aid: aid, cid: cid)
        }
        let topMost = UIViewController.topMostViewController()
        if let _ = AppDelegate.shared.window!.rootViewController?.presentedViewController {
            AppDelegate.shared.window!.rootViewController?.dismiss(animated: false) {
                player.present(from: UIViewController.topMostViewController(), direatlyEnterVideo: true)
            }
        } else {
            player.present(from: topMost, direatlyEnterVideo: true)
        }
    }
}

// MARK: - Cast Receiver Integration (Correct Implementation)

extension BiliBiliUpnpDMR {
    /// Initialize Cast Receiver to allow Apple TV to receive casts from mobile devices
    func initializeCastReceiver() {
        guard castReceiver == nil else { return }

        castReceiver = BilibiliTVCastReceiver.shared

        // Setup callback for receiving Bilibili video casts
        castReceiver?.onBilibiliVideoReceived = { [weak self] aid, cid, metadata in
            Logger.info("Received Bilibili video cast: aid=\(aid), cid=\(cid)")
            DispatchQueue.main.async {
                self?.playVideoFromCast(aid: aid, cid: cid, metadata: metadata)
            }
        }

        // Setup callback for receiving generic video URL casts
        castReceiver?.onVideoReceived = { [weak self] url, title, metadata in
            Logger.info("Received video URL cast: \(url)")
            DispatchQueue.main.async {
                self?.playVideoURLFromCast(url: url, title: title, metadata: metadata)
            }
        }

        // Setup callback for playback control commands
        castReceiver?.onCommandReceived = { [weak self] command in
            Logger.debug("Received cast command: \(command)")
            DispatchQueue.main.async {
                self?.handleCastCommand(command)
            }
        }

        // Setup callback for casting state changes
        castReceiver?.onCastingStateChanged = { [weak self] isReceiving, source in
            Logger.info("Casting state changed: isReceiving=\(isReceiving), source=\(source)")
            DispatchQueue.main.async {
                self?.handleCastingStateChange(isReceiving: isReceiving, source: source)
            }
        }

        // Start the cast receiver service
        castReceiver?.startCastReceiverService()
    }

    /// Play Bilibili video from cast
    private func playVideoFromCast(aid: Int, cid: Int, metadata: [String: Any]?) {
        let json: JSON = [
            "aid": aid,
            "cid": cid,
            "epid": metadata?["epid"] as? Int ?? 0,
        ]
        playVideo(json: json)
    }

    /// Play generic video URL from cast
    private func playVideoURLFromCast(url: String, title: String, metadata: [String: Any]?) {
        // For generic URLs, we would need a different player
        // For now, log it
        Logger.info("Playing video URL from cast: \(url), title: \(title)")
        // TODO: Implement generic video player for non-Bilibili URLs
    }

    /// Handle cast playback commands
    private func handleCastCommand(_ command: CastCommand) {
        switch command {
        case .play:
            currentPlugin?.resume()
            Task { @MainActor in sendStatus(status: .playing) }

        case .pause:
            currentPlugin?.pause()
            Task { @MainActor in sendStatus(status: .paused) }

        case .stop:
            let topMost = UIViewController.topMostViewController()
            (topMost as? CommonPlayerViewController)?.dismiss(animated: true)
            Task { @MainActor in sendStatus(status: .stop) }

        case let .seek(time):
            currentPlugin?.seek(to: time)

        case let .volume(level):
            // TODO: Implement volume control
            Logger.debug("Volume command received: \(level)")

        case let .setVideoURL(url, metadata):
            playVideoURLFromCast(url: url, title: metadata?["title"] as? String ?? "Unknown", metadata: metadata)

        case let .playBilibiliVideo(aid, cid, metadata):
            playVideoFromCast(aid: aid, cid: cid, metadata: metadata)
        }
    }

    /// Handle casting state changes
    private func handleCastingStateChange(isReceiving: Bool, source: CastSource) {
        if isReceiving {
            Logger.info("Now receiving cast from: \(source.rawValue)")
            // Optionally show UI indicator
            NotificationCenter.default.post(
                name: .init("CastingStateChanged"),
                object: nil,
                userInfo: ["isReceiving": isReceiving, "source": source.rawValue]
            )
        } else {
            Logger.info("Stopped receiving cast")
            NotificationCenter.default.post(
                name: .init("CastingStateChanged"),
                object: nil,
                userInfo: ["isReceiving": false]
            )
        }
    }
}

// MARK: - CloudTV Integration (Deprecated - Wrong Sender Implementation)

extension BiliBiliUpnpDMR {
    /// 初始化CloudTV协议处理器
    func initializeCloudTV() {
        if cloudTVHandler == nil {
            cloudTVHandler = CloudTVProtocolHandlerImpl()
            setupCloudTVCallbacks()
        }
    }

    /// 设置CloudTV回调
    private func setupCloudTVCallbacks() {
        cloudTVHandler?.onDeviceStatusChanged = { [weak self] device, status in
            Logger.info("CloudTV device \(device.deviceName) status changed to \(status)")
            self?.handleCloudTVDeviceStatusChange(device: device, status: status)
        }

        cloudTVHandler?.onPlaybackStateUpdated = { [weak self] device, state in
            Logger.debug("CloudTV playback state updated: position=\(state.currentPosition), status=\(state.status)")
            self?.handleCloudTVPlaybackStateUpdate(device: device, state: state)
        }
    }

    /// 发现CloudTV设备
    func discoverCloudTVDevices(timeout: TimeInterval = 5.0, completion: @escaping ([BilibiliTVDevice]) -> Void) {
        initializeCloudTV()

        cloudTVHandler?.discoverDevices(timeout: timeout) { [weak self] devices in
            self?.discoveredCloudTVDevices = devices
            Logger.info("Discovered \(devices.count) CloudTV devices")
            completion(devices)
        }
    }

    /// 连接到CloudTV设备
    func connectToCloudTVDevice(_ device: BilibiliTVDevice, completion: @escaping (Result<Void, Error>) -> Void) {
        initializeCloudTV()

        cloudTVHandler?.connect(to: device) { [weak self] result in
            switch result {
            case .success:
                self?.currentCloudTVDevice = device
                Logger.info("Successfully connected to CloudTV device: \(device.deviceName)")
                completion(.success(()))

            case let .failure(error):
                Logger.error("Failed to connect to CloudTV device: \(error)")
                completion(.failure(error))
            }
        }
    }

    /// 断开CloudTV设备
    func disconnectCloudTVDevice() {
        guard let device = currentCloudTVDevice else { return }

        cloudTVHandler?.disconnect(from: device)
        currentCloudTVDevice = nil
        Logger.info("Disconnected from CloudTV device")
    }

    /// 通过CloudTV播放视频
    func playVideoOnCloudTV(url: String, title: String, metadata: VideoMetadata?, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let device = currentCloudTVDevice else {
            completion(.failure(CloudTVError.deviceNotFound))
            return
        }

        let command = PlayCommand.play(url: url, title: title, metadata: metadata)

        cloudTVHandler?.sendCommand(command, to: device) { result in
            switch result {
            case .success:
                Logger.info("Successfully sent play command to CloudTV device")
                completion(.success(()))

            case let .failure(error):
                Logger.error("Failed to send play command: \(error)")
                completion(.failure(error))
            }
        }
    }

    /// 控制CloudTV播放
    func controlCloudTVPlayback(_ command: PlayCommand, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let device = currentCloudTVDevice else {
            completion(.failure(CloudTVError.deviceNotFound))
            return
        }

        cloudTVHandler?.sendCommand(command, to: device, completion: completion)
    }

    /// 获取CloudTV播放状态
    func getCloudTVPlaybackState(completion: @escaping (Result<PlaybackState, Error>) -> Void) {
        guard let device = currentCloudTVDevice else {
            completion(.failure(CloudTVError.deviceNotFound))
            return
        }

        cloudTVHandler?.getPlaybackState(from: device, completion: completion)
    }

    /// 处理CloudTV设备状态变化
    private func handleCloudTVDeviceStatusChange(device: BilibiliTVDevice, status: DeviceStatus) {
        // 根据状态更新UI或发送通知
        NotificationCenter.default.post(
            name: .init("CloudTVDeviceStatusChanged"),
            object: nil,
            userInfo: ["device": device, "status": status]
        )

        // 将状态映射到DLNA播放状态并发送
        Task { @MainActor in
            switch status {
            case .playing:
                sendStatus(status: .playing)
            case .paused:
                sendStatus(status: .paused)
            case .disconnected, .error:
                sendStatus(status: .stop)
            default:
                break
            }
        }
    }

    /// 处理CloudTV播放状态更新
    private func handleCloudTVPlaybackStateUpdate(device: BilibiliTVDevice, state: PlaybackState) {
        // 同步播放进度到DLNA sessions
        Task { @MainActor in
            sendProgress(duration: Int(state.duration), current: Int(state.currentPosition))
        }

        // 发送通知
        NotificationCenter.default.post(
            name: .init("CloudTVPlaybackStateUpdated"),
            object: nil,
            userInfo: ["device": device, "state": state]
        )
    }

    /// 获取已发现的CloudTV设备列表
    func getDiscoveredCloudTVDevices() -> [BilibiliTVDevice] {
        discoveredCloudTVDevices
    }

    /// 获取当前连接的CloudTV设备
    func getCurrentCloudTVDevice() -> BilibiliTVDevice? {
        currentCloudTVDevice
    }

    /// 检查是否已连接CloudTV设备
    func isCloudTVConnected() -> Bool {
        currentCloudTVDevice?.status == .connected || currentCloudTVDevice?.status == .playing
    }
}

extension BiliBiliUpnpDMR: GCDAsyncUdpSocketDelegate {
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        address.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            let sockaddrPtr = pointer.bindMemory(to: sockaddr.self)
            guard let unsafePtr = sockaddrPtr.baseAddress else { return }
            guard getnameinfo(unsafePtr, socklen_t(data.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 else {
                return
            }
        }
        var ipAddress = String(cString: hostname)
        ipAddress = ipAddress.replacingOccurrences(of: "::ffff:", with: "")
        let str = String(data: data, encoding: .utf8)
        if str?.contains("ssdp:discover") == true {
            Logger.debug("handle ssdp discover from: \(ipAddress)")
            let data = getSSDPResp().data(using: .utf8)!
            sock.send(data, toAddress: address, withTimeout: -1, tag: 0)
        }
    }
}
