//
//  CloudTVProtocolHandlerImpl.swift
//  BilibiliLive
//
//  Created by AI Assistant
//

import CocoaAsyncSocket
import CocoaLumberjackSwift
import Foundation

/// 云视听小电视协议处理器实现
class CloudTVProtocolHandlerImpl: NSObject, CloudTVProtocolHandler {
    // MARK: - Properties

    private var udpSocket: GCDAsyncUdpSocket?
    private var discoveredDevices: Set<BilibiliTVDevice> = []
    private var connectedDevices: [String: BilibiliTVDevice] = [:]
    private var deviceSockets: [String: GCDAsyncSocket] = [:]
    private let socketQueue = DispatchQueue(label: "com.bilibili.cloudtv.socket")

    // Discovery configuration
    private let multicastAddress = "239.255.255.250"
    private let discoveryPort: UInt16 = 1900
    private let cloudTVServiceType = "bilibili:cloudtv:1"

    // MARK: - CloudTVProtocolHandler Protocol

    var onDeviceStatusChanged: ((BilibiliTVDevice, DeviceStatus) -> Void)?
    var onPlaybackStateUpdated: ((BilibiliTVDevice, PlaybackState) -> Void)?

    // MARK: - Initialization

    override init() {
        super.init()
        setupUDPSocket()
    }

    deinit {
        cleanup()
    }

    // MARK: - Setup

    private func setupUDPSocket() {
        udpSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: socketQueue)

        do {
            try udpSocket?.bind(toPort: 0)
            try udpSocket?.enableBroadcast(true)
            try udpSocket?.beginReceiving()
            Logger.info("CloudTV UDP socket setup successful")
        } catch {
            Logger.error("Failed to setup UDP socket: \(error)")
        }
    }

    private func cleanup() {
        udpSocket?.close()
        deviceSockets.values.forEach { $0.disconnect() }
        deviceSockets.removeAll()
        connectedDevices.removeAll()
    }

    // MARK: - Device Discovery

    func discoverDevices(timeout: TimeInterval, completion: @escaping ([BilibiliTVDevice]) -> Void) {
        discoveredDevices.removeAll()

        // Send SSDP M-SEARCH request
        let searchMessage = buildSSDPSearchMessage()
        guard let data = searchMessage.data(using: .utf8) else {
            completion([])
            return
        }

        do {
            try udpSocket?.send(data, toHost: multicastAddress, port: discoveryPort, withTimeout: -1, tag: 0)
            Logger.info("Sent CloudTV device discovery request")

            // Wait for responses
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
                guard let self = self else { return }
                let devices = Array(self.discoveredDevices)
                Logger.info("CloudTV device discovery completed: \(devices.count) devices found")
                DispatchQueue.main.async {
                    completion(devices)
                }
            }
        } catch {
            Logger.error("Failed to send discovery request: \(error)")
            completion([])
        }
    }

    private func buildSSDPSearchMessage() -> String {
        """
        M-SEARCH * HTTP/1.1\r
        HOST: \(multicastAddress):\(discoveryPort)\r
        MAN: "ssdp:discover"\r
        MX: 3\r
        ST: \(cloudTVServiceType)\r
        USER-AGENT: BilibiliTV/iOS\r
        \r

        """
    }

    // MARK: - Device Connection

    func connect(to device: BilibiliTVDevice, completion: @escaping (Result<Void, Error>) -> Void) {
        guard connectedDevices[device.deviceId] == nil else {
            completion(.success(()))
            return
        }

        let socket = GCDAsyncSocket(delegate: self, delegateQueue: socketQueue)

        do {
            try socket.connect(toHost: device.ipAddress, onPort: UInt16(device.port), withTimeout: 10.0)
            deviceSockets[device.deviceId] = socket

            var updatedDevice = device
            updatedDevice.status = .connecting
            connectedDevices[device.deviceId] = updatedDevice

            // Notify status change
            DispatchQueue.main.async { [weak self] in
                self?.onDeviceStatusChanged?(updatedDevice, .connecting)
            }

            // Send authentication handshake
            sendAuthenticationHandshake(to: socket, deviceId: device.deviceId) { [weak self] result in
                switch result {
                case .success:
                    var connectedDevice = device
                    connectedDevice.status = .connected
                    self?.connectedDevices[device.deviceId] = connectedDevice

                    DispatchQueue.main.async {
                        self?.onDeviceStatusChanged?(connectedDevice, .connected)
                        completion(.success(()))
                    }

                case let .failure(error):
                    self?.disconnect(from: device)
                    completion(.failure(error))
                }
            }

        } catch {
            Logger.error("Failed to connect to device \(device.deviceName): \(error)")
            completion(.failure(CloudTVError.connectionFailed(error.localizedDescription)))
        }
    }

    func disconnect(from device: BilibiliTVDevice) {
        guard let socket = deviceSockets[device.deviceId] else { return }

        socket.disconnect()
        deviceSockets.removeValue(forKey: device.deviceId)
        connectedDevices.removeValue(forKey: device.deviceId)

        DispatchQueue.main.async { [weak self] in
            var disconnectedDevice = device
            disconnectedDevice.status = .disconnected
            self?.onDeviceStatusChanged?(disconnectedDevice, .disconnected)
        }

        Logger.info("Disconnected from device: \(device.deviceName)")
    }

    // MARK: - Command Execution

    func sendCommand(_ command: PlayCommand, to device: BilibiliTVDevice, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let socket = deviceSockets[device.deviceId], socket.isConnected else {
            completion(.failure(CloudTVError.deviceNotFound))
            return
        }

        let commandData = buildCommandData(command, device: device)

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: commandData, options: [])
            socket.write(jsonData, withTimeout: 10.0, tag: 0)

            // Update device status based on command
            updateDeviceStatus(for: device, command: command)

            completion(.success(()))
        } catch {
            Logger.error("Failed to send command: \(error)")
            completion(.failure(CloudTVError.commandFailed(error.localizedDescription)))
        }
    }

    func getPlaybackState(from device: BilibiliTVDevice, completion: @escaping (Result<PlaybackState, Error>) -> Void) {
        guard let socket = deviceSockets[device.deviceId], socket.isConnected else {
            completion(.failure(CloudTVError.deviceNotFound))
            return
        }

        let request: [String: Any] = [
            "type": "getPlaybackState",
            "deviceId": device.deviceId,
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: request, options: [])
            socket.write(jsonData, withTimeout: 10.0, tag: 0)

            // TODO: Implement response handling with proper async/await or callback pattern
            // For now, return a mock state
            let mockState = PlaybackState(
                currentPosition: 0,
                duration: 0,
                status: device.status,
                volume: 1.0,
                playbackRate: 1.0,
                bufferProgress: 0
            )
            completion(.success(mockState))
        } catch {
            completion(.failure(CloudTVError.commandFailed(error.localizedDescription)))
        }
    }

    // MARK: - Helper Methods

    private func buildCommandData(_ command: PlayCommand, device: BilibiliTVDevice) -> [String: Any] {
        var data: [String: Any] = [
            "deviceId": device.deviceId,
            "timestamp": Date().timeIntervalSince1970,
        ]

        switch command {
        case let .play(url, title, metadata):
            data["type"] = "play"
            data["url"] = url
            data["title"] = title
            if let metadata = metadata {
                data["metadata"] = try? JSONEncoder().encode(metadata)
            }

        case .pause:
            data["type"] = "pause"

        case .resume:
            data["type"] = "resume"

        case .stop:
            data["type"] = "stop"

        case let .seek(position):
            data["type"] = "seek"
            data["position"] = position

        case let .setVolume(level):
            data["type"] = "setVolume"
            data["volume"] = level

        case let .setPlaybackRate(rate):
            data["type"] = "setPlaybackRate"
            data["rate"] = rate
        }

        return data
    }

    private func updateDeviceStatus(for device: BilibiliTVDevice, command: PlayCommand) {
        guard var updatedDevice = connectedDevices[device.deviceId] else { return }

        switch command {
        case .play:
            updatedDevice.status = .playing
        case .pause:
            updatedDevice.status = .paused
        case .resume:
            updatedDevice.status = .playing
        case .stop:
            updatedDevice.status = .connected
        default:
            break
        }

        connectedDevices[device.deviceId] = updatedDevice

        DispatchQueue.main.async { [weak self] in
            self?.onDeviceStatusChanged?(updatedDevice, updatedDevice.status)
        }
    }

    private func sendAuthenticationHandshake(to socket: GCDAsyncSocket, deviceId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let handshake: [String: Any] = [
            "type": "auth",
            "version": "1.0",
            "client": "BilibiliTV-iOS",
            "timestamp": Date().timeIntervalSince1970,
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: handshake, options: [])
            socket.write(jsonData, withTimeout: 10.0, tag: 0)

            // TODO: Wait for auth response
            // For now, assume success
            completion(.success(()))
        } catch {
            completion(.failure(CloudTVError.authenticationRequired))
        }
    }

    private func parseDeviceFromSSDPResponse(_ response: String, address: String) -> BilibiliTVDevice? {
        // Parse SSDP response headers
        let lines = response.components(separatedBy: "\r\n")
        var headers: [String: String] = [:]

        for line in lines {
            let parts = line.components(separatedBy: ": ")
            if parts.count == 2 {
                headers[parts[0].uppercased()] = parts[1]
            }
        }

        // Extract device information
        guard let location = headers["LOCATION"],
              let usn = headers["USN"]
        else {
            return nil
        }

        // Extract port from location URL
        let port = extractPort(from: location) ?? 9958

        // Generate device ID from USN
        let deviceId = usn.components(separatedBy: "::").first ?? UUID().uuidString

        // Create device with default capabilities
        let device = BilibiliTVDevice(
            deviceId: deviceId,
            deviceName: headers["SERVER"] ?? "云视听小电视",
            deviceModel: headers["MODEL"] ?? "Unknown",
            ipAddress: address,
            port: port,
            capabilities: DeviceCapabilities(
                supportedVideoCodecs: ["H.264", "H.265"],
                supportedAudioCodecs: ["AAC", "MP3"],
                maxResolution: Resolution(width: 1920, height: 1080),
                supportsHDR: false,
                supportsDolbyAudio: false,
                supports4K: false,
                protocolVersion: "1.0"
            ),
            status: .available,
            lastSeenTime: Date()
        )

        return device
    }

    private func extractPort(from url: String) -> Int? {
        guard let urlComponents = URLComponents(string: url) else { return nil }
        return urlComponents.port
    }
}

// MARK: - GCDAsyncUdpSocketDelegate

extension CloudTVProtocolHandlerImpl: GCDAsyncUdpSocketDelegate {
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        guard let response = String(data: data, encoding: .utf8),
              response.contains(cloudTVServiceType)
        else {
            return
        }

        // Extract IP address
        var hostname: NSString?
        var port: UInt16 = 0
        GCDAsyncUdpSocket.getHost(&hostname, port: &port, fromAddress: address)

        if let hostnameString = hostname as String?,
           let device = parseDeviceFromSSDPResponse(response, address: hostnameString)
        {
            discoveredDevices.insert(device)
            Logger.info("Discovered CloudTV device: \(device.deviceName) at \(device.ipAddress):\(device.port)")
        }
    }

    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotSendDataWithTag tag: Int, dueToError error: Error?) {
        if let error = error {
            Logger.error("UDP socket send error: \(error)")
        }
    }
}

// MARK: - GCDAsyncSocketDelegate

extension CloudTVProtocolHandlerImpl: GCDAsyncSocketDelegate {
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        Logger.info("Connected to CloudTV device at \(host):\(port)")
        sock.readData(withTimeout: -1, tag: 0)
    }

    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        // Find device by socket
        if let deviceId = deviceSockets.first(where: { $0.value == sock })?.key,
           let device = connectedDevices[deviceId]
        {
            Logger.info("Disconnected from device: \(device.deviceName)")
            deviceSockets.removeValue(forKey: deviceId)
            connectedDevices.removeValue(forKey: deviceId)

            DispatchQueue.main.async { [weak self] in
                var disconnectedDevice = device
                disconnectedDevice.status = .disconnected
                self?.onDeviceStatusChanged?(disconnectedDevice, .disconnected)
            }
        }

        if let err = err {
            Logger.error("Socket disconnection error: \(err)")
        }
    }

    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        // Parse response from device
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let type = json["type"] as? String
        {
            handleDeviceResponse(type: type, data: json, socket: sock)
        }

        // Continue reading
        sock.readData(withTimeout: -1, tag: 0)
    }

    private func handleDeviceResponse(type: String, data: [String: Any], socket: GCDAsyncSocket) {
        guard let deviceId = data["deviceId"] as? String,
              let device = connectedDevices[deviceId]
        else {
            return
        }

        switch type {
        case "playbackState":
            if let state = parsePlaybackState(from: data) {
                DispatchQueue.main.async { [weak self] in
                    self?.onPlaybackStateUpdated?(device, state)
                }
            }

        case "statusChange":
            if let statusString = data["status"] as? String,
               let status = DeviceStatus(rawValue: statusString)
            {
                var updatedDevice = device
                updatedDevice.status = status
                connectedDevices[deviceId] = updatedDevice

                DispatchQueue.main.async { [weak self] in
                    self?.onDeviceStatusChanged?(updatedDevice, status)
                }
            }

        default:
            Logger.debug("Unknown response type: \(type)")
        }
    }

    private func parsePlaybackState(from data: [String: Any]) -> PlaybackState? {
        guard let currentPosition = data["currentPosition"] as? TimeInterval,
              let duration = data["duration"] as? TimeInterval,
              let statusString = data["status"] as? String,
              let status = DeviceStatus(rawValue: statusString),
              let volume = data["volume"] as? Float,
              let playbackRate = data["playbackRate"] as? Float,
              let bufferProgress = data["bufferProgress"] as? Float
        else {
            return nil
        }

        return PlaybackState(
            currentPosition: currentPosition,
            duration: duration,
            status: status,
            volume: volume,
            playbackRate: playbackRate,
            bufferProgress: bufferProgress
        )
    }
}
