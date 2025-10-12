//
//  BilibiliTVDevice.swift
//  BilibiliLive
//
//  Created by AI Assistant
//

import Foundation

/// 云视听小电视设备模型
struct BilibiliTVDevice: Codable, Hashable {
    /// 设备唯一标识符
    let deviceId: String

    /// 设备名称
    let deviceName: String

    /// 设备型号
    let deviceModel: String

    /// 设备IP地址
    let ipAddress: String

    /// 设备端口
    let port: Int

    /// 设备能力集
    let capabilities: DeviceCapabilities

    /// 设备状态
    var status: DeviceStatus

    /// 上次发现时间
    var lastSeenTime: Date

    /// Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(deviceId)
    }

    static func == (lhs: BilibiliTVDevice, rhs: BilibiliTVDevice) -> Bool {
        lhs.deviceId == rhs.deviceId
    }
}

/// 设备能力集
struct DeviceCapabilities: Codable {
    /// 支持的视频编码格式
    let supportedVideoCodecs: [String]

    /// 支持的音频编码格式
    let supportedAudioCodecs: [String]

    /// 最大分辨率
    let maxResolution: Resolution

    /// 是否支持HDR
    let supportsHDR: Bool

    /// 是否支持杜比音效
    let supportsDolbyAudio: Bool

    /// 是否支持4K播放
    let supports4K: Bool

    /// 协议版本
    let protocolVersion: String
}

/// 分辨率
struct Resolution: Codable {
    let width: Int
    let height: Int

    var description: String {
        "\(width)x\(height)"
    }
}

/// 设备状态
enum DeviceStatus: String, Codable {
    case available
    case connecting
    case connected
    case playing
    case paused
    case disconnected
    case error
}

/// 播放命令
enum PlayCommand {
    case play(url: String, title: String, metadata: VideoMetadata?)
    case pause
    case resume
    case stop
    case seek(position: TimeInterval)
    case setVolume(level: Float)
    case setPlaybackRate(rate: Float)
}

/// 视频元数据
struct VideoMetadata: Codable {
    /// 视频AID
    let aid: Int

    /// 视频CID
    let cid: Int

    /// 视频标题
    let title: String

    /// UP主名称
    let upName: String?

    /// 封面URL
    let coverUrl: String?

    /// 视频时长(秒)
    let duration: Int?

    /// 当前播放位置(秒)
    let currentPosition: Int?

    /// 弹幕开关
    let danmakuEnabled: Bool
}

/// 播放状态
struct PlaybackState: Codable {
    /// 当前播放位置(秒)
    let currentPosition: TimeInterval

    /// 总时长(秒)
    let duration: TimeInterval

    /// 播放状态
    let status: DeviceStatus

    /// 音量(0.0-1.0)
    let volume: Float

    /// 播放速率
    let playbackRate: Float

    /// 缓冲进度(0.0-1.0)
    let bufferProgress: Float
}

/// 云视听小电视协议处理器
protocol CloudTVProtocolHandler: AnyObject {
    /// 发现设备
    func discoverDevices(timeout: TimeInterval, completion: @escaping ([BilibiliTVDevice]) -> Void)

    /// 连接设备
    func connect(to device: BilibiliTVDevice, completion: @escaping (Result<Void, Error>) -> Void)

    /// 断开设备
    func disconnect(from device: BilibiliTVDevice)

    /// 发送播放命令
    func sendCommand(_ command: PlayCommand, to device: BilibiliTVDevice, completion: @escaping (Result<Void, Error>) -> Void)

    /// 获取播放状态
    func getPlaybackState(from device: BilibiliTVDevice, completion: @escaping (Result<PlaybackState, Error>) -> Void)

    /// 设备状态变化回调
    var onDeviceStatusChanged: ((BilibiliTVDevice, DeviceStatus) -> Void)? { get set }

    /// 播放状态更新回调
    var onPlaybackStateUpdated: ((BilibiliTVDevice, PlaybackState) -> Void)? { get set }
}

/// 云视听小电视协议错误
enum CloudTVError: Error, LocalizedError {
    case deviceNotFound
    case connectionFailed(String)
    case commandFailed(String)
    case timeout
    case invalidResponse
    case unsupportedFormat
    case authenticationRequired
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "未找到云视听小电视设备"
        case let .connectionFailed(reason):
            return "连接失败: \(reason)"
        case let .commandFailed(reason):
            return "命令执行失败: \(reason)"
        case .timeout:
            return "操作超时"
        case .invalidResponse:
            return "无效的响应"
        case .unsupportedFormat:
            return "不支持的格式"
        case .authenticationRequired:
            return "需要认证"
        case let .networkError(error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}
